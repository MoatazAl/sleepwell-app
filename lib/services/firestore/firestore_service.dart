import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/sleep_record.dart';

class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    return user.uid;
  }

  // ---------------- ADD RECORD ----------------
  static Future<void> addSleepRecord(SleepRecord record) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('sleep_records')
        .doc(record.id)
        .set(record.toMap());
  }

  // ---------------- UPDATE RECORD ----------------
  static Future<void> updateSleepRecord(String id, Map<String, dynamic> data) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('sleep_records')
        .doc(id)
        .update(data);
  }

  // ---------------- GET ALL RECORDS ----------------
  static Future<List<SleepRecord>> getAllSleepRecords() async {
    final snap = await _db
        .collection('users')
        .doc(_uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .get();

    return snap.docs
        .map((doc) => SleepRecord.fromMap(doc.data(), doc.id))
        .toList();
  }

  // ---------------- GET SINGLE RECORD ----------------
  static Future<SleepRecord?> getRecord(String id) async {
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('sleep_records')
        .doc(id)
        .get();

    if (!doc.exists) return null;

    return SleepRecord.fromMap(doc.data()!, doc.id);
  }
}
