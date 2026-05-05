import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/questionnaire.dart';

class QuestionnaireService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> saveResult({
    required QuestionnaireResult result,
    required List<int> answers,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not signed in');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('assessments')
        .add({
      'type': result.type,
      'score': result.score,
      'level': result.level,
      'message': result.message,
      'answers': answers,
      'actions': result.actions,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> latestResult(String type) async {
    final user = _auth.currentUser;

    if (user == null) return null;

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('assessments')
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    return snap.docs.first.data();
  }

  static Future<List<Map<String, dynamic>>> allResults() async {
    final user = _auth.currentUser;

    if (user == null) return [];

    final snap = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('assessments')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snap.docs.map((e) => e.data()).toList();
  }

  static Future<Map<String, dynamic>> summary() async {
    final results = await allResults();

    if (results.isEmpty) {
      return {
        'count': 0,
        'latestType': null,
        'latestScore': null,
        'latestLevel': null,
      };
    }

    final latest = results.first;

    return {
      'count': results.length,
      'latestType': latest['type'],
      'latestScore': latest['score'],
      'latestLevel': latest['level'],
    };
  }

  static Future<void> deleteAllResults() async {
    final user = _auth.currentUser;

    if (user == null) return;

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('assessments');

    final snap = await ref.get();

    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}