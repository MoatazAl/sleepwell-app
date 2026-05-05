import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../samsung_health_service.dart';
import 'health_connect_service.dart';

class HealthConnectImporter {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<String> importLatestSleep() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not signed in.');
    }

    final hasSamsungPermission =
        await SamsungHealthService.hasSleepPermission() ||
        await SamsungHealthService.requestSleepPermission();

    if (hasSamsungPermission) {
      final samsungSession = await SamsungHealthService.readLatestSleep();

      if (samsungSession != null) {
        return _saveSamsungSleep(user.uid, samsungSession);
      }
    }

    final session = _latestCombinedHealthConnectSession(
      await HealthConnectService.readSleepSessions(daysBack: 3),
    );

    if (session == null) {
      throw Exception(
        'No recent sleep data found from Samsung Health or Health Connect.',
      );
    }

    return _saveHealthConnectSleep(user.uid, session);
  }

  static Future<int> importLast30Days() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not signed in.');
    }

    final sessions = _combinedHealthConnectSessions(
      await HealthConnectService.readSleepSessions(daysBack: 30),
    );

    int imported = 0;

    for (final session in sessions) {
      final saved = await _saveHealthConnectSleep(
        user.uid,
        session,
        replaceManualSameDay: true,
        skipIfWatchAlreadyExists: true,
      );

      if (saved.isNotEmpty) imported++;
    }

    return imported;
  }

  static Future<String> _saveHealthConnectSleep(
    String userId,
    ImportedSleepSession session, {
    bool replaceManualSameDay = true,
    bool skipIfWatchAlreadyExists = false,
  }) async {
    final start = DateTime.parse(session.start).toUtc();
    final end = DateTime.parse(session.end).toUtc();

    if (!end.isAfter(start)) return '';

    final recordsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_records');

    final sleepDateKey = _sleepDateKey(start, end);

    if (replaceManualSameDay || skipIfWatchAlreadyExists) {
      final existing = await recordsRef
          .where('sleepDateKey', isEqualTo: sleepDateKey)
          .get();

      final batch = _firestore.batch();
      var hasBatchWrites = false;
      bool alreadyHasOtherWatch = false;

      for (final doc in existing.docs) {
        final data = doc.data();
        final source = data['source'];

        if (source == 'samsung_health') {
          alreadyHasOtherWatch = true;
        }

        if (source == 'health_connect') {
          batch.delete(doc.reference);
          hasBatchWrites = true;
        }

        if (replaceManualSameDay && source == 'manual') {
          batch.delete(doc.reference);
          hasBatchWrites = true;
        }
      }

      if (skipIfWatchAlreadyExists && alreadyHasOtherWatch) {
        if (hasBatchWrites) await batch.commit();
        return '';
      }

      if (hasBatchWrites) await batch.commit();
    }

    final dedupeId =
        'hc_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

    await recordsRef.doc(dedupeId).set({
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'sleepDateKey': sleepDateKey,
      'durationHours': session.durationHours,
      'durationMinutes': session.durationMinutes,
      'source': 'health_connect',
      'sourceDevice': 'smartwatch',
      'importedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'title': session.title,
      'note': session.notes,
      'healthConnectSourcePackage': session.sourcePackage,
      'stages': session.stages.map((s) => s.toJson()).toList(),
    }, SetOptions(merge: true));

    return dedupeId;
  }

  static Future<String> _saveSamsungSleep(
    String userId,
    Map<String, dynamic> session,
  ) async {
    final startRaw = session['start'];
    final endRaw = session['end'];

    if (startRaw == null || endRaw == null) {
      throw Exception('Samsung Health sleep data is missing start/end.');
    }

    final start = DateTime.parse(startRaw.toString()).toUtc();
    final end = DateTime.parse(endRaw.toString()).toUtc();

    if (!end.isAfter(start)) return '';

    final durationHours =
        (session['durationHours'] as num?)?.toDouble() ??
        end.difference(start).inMinutes / 60.0;

    final stagesRaw = (session['stages'] as List?) ?? const [];

    final recordsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_records');

    final sleepDateKey = _sleepDateKey(start, end);

    final existing = await recordsRef
        .where('sleepDateKey', isEqualTo: sleepDateKey)
        .get();

    for (final doc in existing.docs) {
      final source = doc.data()['source'];

      if (source == 'manual') {
        await doc.reference.delete();
      }
    }

    final dedupeId =
        'sh_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

    await recordsRef.doc(dedupeId).set({
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'sleepDateKey': sleepDateKey,
      'durationHours': durationHours,
      'source': 'samsung_health',
      'sourceDevice': 'smartwatch',
      'importedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'sleepScore': session['sleepScore'],
      'stages': stagesRaw.map((stage) {
        final map = Map<String, dynamic>.from(stage as Map);

        return {
          'stage': map['stage'],
          'start': map['start'],
          'end': map['end'],
        };
      }).toList(),
    }, SetOptions(merge: true));

    return dedupeId;
  }

  static String _sleepDateKey(DateTime start, DateTime end) {
    final midpoint = start.add(
      Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2),
    );

    return DateFormat('yyyy-MM-dd').format(midpoint);
  }

  static ImportedSleepSession? _latestCombinedHealthConnectSession(
    List<ImportedSleepSession> sessions,
  ) {
    final combined = _combinedHealthConnectSessions(sessions);

    combined.sort((a, b) {
      final aEnd = DateTime.parse(a.end);
      final bEnd = DateTime.parse(b.end);
      return bEnd.compareTo(aEnd);
    });

    return combined.isEmpty ? null : combined.first;
  }

  static List<ImportedSleepSession> _combinedHealthConnectSessions(
    List<ImportedSleepSession> sessions,
  ) {
    final bySleepDate = <String, List<ImportedSleepSession>>{};

    for (final session in sessions) {
      final start = DateTime.tryParse(session.start)?.toUtc();
      final end = DateTime.tryParse(session.end)?.toUtc();

      if (start == null || end == null || !end.isAfter(start)) continue;

      final sleepDateKey = _sleepDateKey(start, end);
      bySleepDate.putIfAbsent(sleepDateKey, () => []).add(session);
    }

    final combined = <ImportedSleepSession>[];

    for (final group in bySleepDate.values) {
      final session = mergeSleepSessions(group);
      if (session != null) combined.add(session);
    }

    return combined;
  }
}
