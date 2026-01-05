import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/sleep_record.dart';
import '../firestore/firestore_service.dart';

class TrackingController extends ChangeNotifier {
  static const _prefActiveId = "active_sleep_id";

  SleepRecord? _active;
  SleepRecord? get activeSession => _active;
  bool get isActive => _active != null;

  // ---------------------------------------------------------
  // START SESSION
  // ---------------------------------------------------------
  Future<void> startSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not logged in");
    if (_active != null) return;

    final now = DateTime.now();
    final id = FirebaseFirestore.instance.collection('tmp').doc().id;

    final record = SleepRecord(
      id: id,
      start: now,
      end: null,
      durationHours: null,
      source: "manual",
      createdAt: now,
    );

    // Save to Firestore
    await FirestoreService.addSleepRecord(record);

    // Save active locally
    _active = record;

    // Save to SharedPreferences (restore after restart)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefActiveId, id);

    notifyListeners();
  }

  // ---------------------------------------------------------
  // END SESSION
  // ---------------------------------------------------------
  Future<void> endSession() async {
    if (_active == null) return;

    final end = DateTime.now();
    final updatedDuration =
        _active!.copyWith(end: end).computedDurationHours;

    // Update Firestore
    await FirestoreService.updateSleepRecord(_active!.id, {
      'end': Timestamp.fromDate(end),
      'durationHours': updatedDuration,
    });

    // Clear local
    _active = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefActiveId);

    notifyListeners();
  }
}
