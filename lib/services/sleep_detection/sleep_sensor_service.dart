import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import 'sleep_detector.dart';

/// Collects raw signals (accelerometer, charging, screen state)
/// and feeds them into SleepDetector as SleepSamples.
class SleepSensorService {
  final SleepDetector detector;

  final Battery _battery = Battery();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _sampleTimer;
  Timer? _chargingTimer;

  // Latest accel values
  double _ax = 0;
  double _ay = 0;
  double _az = 9.81;

  // IMPORTANT: default should be true while app is visible initially
  bool _screenOn = false;

  bool _isCharging = false;

  // Smoothing: baseline magnitude and movement deviation
  double _emaMag = 9.81;
  double _emaDev = 0.0;

  SleepSensorService({required this.detector});

  /// Start listening to sensors + timers
  Future<void> start() async {
    // 1) accelerometer stream (continuous)
    _accelSub = accelerometerEvents.listen((event) {
      _ax = event.x.toDouble();
      _ay = event.y.toDouble();
      _az = event.z.toDouble();
    });

    // 2) charging state polling (every 20s)
    await _updateChargingState();
    _chargingTimer?.cancel();
    _chargingTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _updateChargingState(),
    );

    // 3) sampling window (every 10s - gives your 5 min window enough samples)
    _sampleTimer?.cancel();
    _sampleTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pushSample(),
    );

    if (kDebugMode) {
      debugPrint("[SleepSensorService] started");
    }
  }

  /// Stop listening
  Future<void> stop() async {
    await _accelSub?.cancel();
    _accelSub = null;

    _sampleTimer?.cancel();
    _sampleTimer = null;

    _chargingTimer?.cancel();
    _chargingTimer = null;

    if (kDebugMode) {
      debugPrint("[SleepSensorService] stopped");
    }
  }

  /// Update screen state externally (controller decides this)
  void setScreenOn(bool value) {
    _screenOn = value;
  }

  /// Poll charging state
  Future<void> _updateChargingState() async {
    final status = await _battery.batteryState;
    _isCharging = status == BatteryState.charging || status == BatteryState.full;
  }

  /// Convert raw sensor values → SleepSample → detector.addSample()
  void _pushSample() {
    final now = DateTime.now();

    // Magnitude
    final mag = sqrt(_ax * _ax + _ay * _ay + _az * _az);

    // Smooth baseline magnitude (EMA)
    const alphaMag = 0.10;
    _emaMag = alphaMag * mag + (1 - alphaMag) * _emaMag;

    // Deviation from baseline => movement
    final dev = (mag - _emaMag).abs();

    // Smooth deviation too (EMA) for stability
    const alphaDev = 0.15;
    _emaDev = alphaDev * dev + (1 - alphaDev) * _emaDev;

    // Scale into the detector expected range.
    // Your stillnessThreshold is 0.12, so keep typical still values below that.
    final movement = (_emaDev).clamp(0.0, 1.5);

    final sample = SleepSample(
      timestamp: now,
      movement: movement,
      screenOn: _screenOn,
      isCharging: _isCharging,
    );

    detector.addSample(sample);

    // Uncomment for debugging if needed:
    // if (kDebugMode) debugPrint("[Sample] move=${movement.toStringAsFixed(3)} screenOn=$_screenOn charging=$_isCharging");
  }
}
