import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'sleep_detector.dart';
import 'sleep_sensor_service.dart';
import 'auto_to_sleep_record.dart';

class AutoSleepController with WidgetsBindingObserver {
  static final AutoSleepController _instance = AutoSleepController._internal();
  factory AutoSleepController() => _instance;
  AutoSleepController._internal();

  bool _initialized = false;
  String? _uid;

  late final SleepDetector _detector;
  late final SleepSensorService _sensorService;

  bool _saving = false;
  DateTime? _lastSavedEnd;

  /// Call ONCE from main()
  void init() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
    });

    _detector = SleepDetector(
      config: SleepDetectorConfig(
        minSleepLatency: const Duration(minutes: 2), // TEMP for testing
        minSleepDuration: const Duration(minutes: 40),
      ),
      onSleepStarted: (start) {
        debugPrint("[AutoSleep] Sleep started at $start");
      },
      onSleepSessionDetected: (session) async {
        await _saveSession(session);
      },
    );

    _sensorService = SleepSensorService(detector: _detector);
    _sensorService.start();

    debugPrint("[AutoSleep] Initialized (detector + sensors)");
  }

  // ---------------- LIFECYCLE ----------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sensorService.setScreenOn(true);
      debugPrint("[AutoSleep] Screen ON (resumed)");
    } 
  }

  // ---------------- SAVE ----------------
  Future<void> _saveSession(AutoSleepSession session) async {
    if (_uid == null || _saving) return;

    if (_lastSavedEnd != null &&
        session.end.difference(_lastSavedEnd!).inSeconds.abs() < 10) {
      return; // prevent duplicates
    }

    _saving = true;
    try {
      final record = AutoSleepMapper.toSleepRecord(session);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('sleep_records')
          .add(record.toMap());

      _lastSavedEnd = session.end;

      debugPrint(
        "[AutoSleep] Session saved ✅ "
        "(${session.duration.inMinutes} min, "
        "confidence ${(session.confidence * 100).round()}%)",
      );
    } catch (e) {
      debugPrint("[AutoSleep] Save failed: $e");
    } finally {
      _saving = false;
    }
  }

  // ---------------- CLEANUP ----------------
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}