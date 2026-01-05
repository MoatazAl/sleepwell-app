import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Correct imports for your package name & folder structure
import 'package:sleepwell_app/models/sleep_record.dart';
import 'package:sleepwell_app/models/sleep_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepRecord & Firestore Tests', () {
    late FakeFirebaseFirestore firestore;

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Add and retrieve a sleep session', () async {
      final start = DateTime(2025, 11, 5, 23, 0);
      final end = DateTime(2025, 11, 6, 7, 0);

      final docRef = await firestore
          .collection('users/u1/sleep_records')
          .add({
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
        'note': 'Test night',
        'durationHours': 8.0,
        'source': 'manual',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      final snapshot = await docRef.get();
      expect(snapshot.exists, true);
      expect(snapshot.data()!['durationHours'], 8.0);
      expect(snapshot.data()!['note'], 'Test night');
    });

    test('Convert SleepRecord to and from Map', () {
      final start = DateTime(2025, 11, 5, 23, 0);
      final end = DateTime(2025, 11, 6, 7, 0);

      final event = SleepEvent(
        type: 'REM',
        timestamp: start.add(const Duration(hours: 2)),
      );

      final record = SleepRecord(
        id: 'abc',
        start: start,
        end: end,
        durationHours: 8.0,
        sleepQuality: 4.5,
        efficiency: 0.9,
        note: 'Good sleep',
        events: [event],
        source: 'manual',
        createdAt: DateTime.now(),
      );

      final map = record.toMap();
      expect(map['durationHours'], 8.0);
      expect(map['note'], 'Good sleep');
      expect(map['source'], 'manual');

      final recreated = SleepRecord.fromMap(map, 'abc');
      expect(recreated.note, 'Good sleep');
      expect(recreated.events!.length, 1);
      expect(recreated.computedDurationHours, greaterThan(7.5));
    });

    test('Firestore integration: save SleepRecord', () async {
      final start = DateTime(2025, 11, 5, 22, 0);
      final end = DateTime(2025, 11, 6, 6, 0);

      final record = SleepRecord(
        id: 'id1',
        start: start,
        end: end,
        durationHours: 8.0,
        sleepQuality: 4.2,
        source: 'manual',
        createdAt: DateTime.now(),
      );

      await firestore
          .collection('users/u1/sleep_records')
          .doc(record.id)
          .set(record.toMap());

      final doc = await firestore
          .collection('users/u1/sleep_records')
          .doc('id1')
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['sleepQuality'], 4.2);
      expect(doc.data()!['source'], 'manual');
    });
  });
}
