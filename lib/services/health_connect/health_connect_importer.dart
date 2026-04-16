import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final session = await HealthConnectService.readLatestSleepSession();
    if (session == null) {
      throw Exception(
        'No recent sleep data found from Samsung Health or Health Connect.',
      );
    }

    final start = DateTime.parse(session.start).toUtc();
    final end = DateTime.parse(session.end).toUtc();

    final dedupeId =
        'hc_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sleep_records')
        .doc(dedupeId);

    await docRef.set({
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'durationHours': session.durationHours,
      'source': 'health_connect',
      'sourceDevice': 'smartwatch',
      'importedAt': FieldValue.serverTimestamp(),
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

    final durationHours =
        (session['durationHours'] as num?)?.toDouble() ??
        end.difference(start).inMinutes / 60.0;

    final stagesRaw = (session['stages'] as List?) ?? const [];

    final dedupeId =
        'sh_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_records')
        .doc(dedupeId);

    await docRef.set({
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'durationHours': durationHours,
      'source': 'samsung_health',
      'sourceDevice': 'smartwatch',
      'importedAt': FieldValue.serverTimestamp(),
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
}