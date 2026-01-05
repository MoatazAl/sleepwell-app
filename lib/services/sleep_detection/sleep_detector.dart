import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SleepState { awake, maybeFallingAsleep, asleep, maybeAwake }

class SleepSample {
  final DateTime timestamp;
  final double movement;
  final bool screenOn;
  final bool isCharging;

  SleepSample({
    required this.timestamp,
    required this.movement,
    required this.screenOn,
    required this.isCharging,
  });
}

class AutoSleepSession {
  final DateTime start;
  final DateTime end;
  final double confidence;
  final bool wasChargingMostOfTime;
  final Duration totalStillDuration;
  final Duration totalDuration;

  AutoSleepSession({
    required this.start,
    required this.end,
    required this.confidence,
    required this.wasChargingMostOfTime,
    required this.totalStillDuration,
    required this.totalDuration,
  });

  Duration get duration => end.difference(start);
}

class SleepDetectorConfig {
  final Duration windowSize;
  final Duration minSleepLatency;
  final Duration minSleepDuration;
  final double stillnessThreshold;
  final double stillRatioThreshold;
  final Duration maxSampleGap;
  final int typicalSleepHour;
  final int typicalWakeHour;

  SleepDetectorConfig({
    this.windowSize = const Duration(minutes: 5),
    this.minSleepLatency = const Duration(minutes: 2),
    this.minSleepDuration = const Duration(minutes: 5),
    this.stillnessThreshold = 0.12,
    this.stillRatioThreshold = 0.75,
    this.maxSampleGap = const Duration(minutes: 20),
    this.typicalSleepHour = 23,
    this.typicalWakeHour = 7,
  });
}

class SleepDetector {
  final SleepDetectorConfig config;
  final void Function(AutoSleepSession session)? onSleepSessionDetected;
  final void Function(DateTime start)? onSleepStarted;

  static const _kState = 'sleep_detector_state';
  static const _kCandidateStart = 'sleep_detector_candidate_start';
  static const _kConfirmedStart = 'sleep_detector_confirmed_start';

  SleepState _state = SleepState.awake;
  SleepState get state => _state;

  final List<SleepSample> _buffer = [];
  DateTime? _candidateSleepStart;
  DateTime? _confirmedSleepStart;

  SleepDetector({
    required this.config,
    this.onSleepSessionDetected,
    this.onSleepStarted,
  }) {
    _restoreState();
  }

  void addSample(SleepSample sample) {
    if (_buffer.isNotEmpty) {
      final last = _buffer.last;
      if (sample.timestamp.difference(last.timestamp) > config.maxSampleGap) {
        _resetState("Gap too large");
      }
    }

    _buffer.add(sample);
    _trimOldSamples(sample.timestamp);
    _updateState();
  }

  void _trimOldSamples(DateTime now) {
    final oldest = now.subtract(
      Duration(milliseconds: config.minSleepLatency.inMilliseconds * 4),
    );

    _buffer.removeWhere((s) => s.timestamp.isBefore(oldest));
  }

  void _resetState(String reason) {
    if (kDebugMode) debugPrint("[SleepDetector] Reset: $reason");
    _state = SleepState.awake;
    _candidateSleepStart = null;
    _confirmedSleepStart = null;
    _buffer.clear();
    _saveState();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kState, _state.index);

    if (_candidateSleepStart != null) {
      await prefs.setInt(
        _kCandidateStart,
        _candidateSleepStart!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_kCandidateStart);
    }

    if (_confirmedSleepStart != null) {
      await prefs.setInt(
        _kConfirmedStart,
        _confirmedSleepStart!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_kConfirmedStart);
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();

    final stateIndex = prefs.getInt(_kState);
    if (stateIndex != null) {
      _state = SleepState.values[stateIndex];
    }

    final cand = prefs.getInt(_kCandidateStart);
    final conf = prefs.getInt(_kConfirmedStart);

    _candidateSleepStart = cand != null
        ? DateTime.fromMillisecondsSinceEpoch(cand)
        : null;

    _confirmedSleepStart = conf != null
        ? DateTime.fromMillisecondsSinceEpoch(conf)
        : null;
  }

  void _updateState() {
    if (_buffer.isEmpty) return;

    final latestSample = _buffer.last;

    // HARD RULE: screen ON = cannot be sleeping
    if (latestSample.screenOn) {
      if (_state != SleepState.awake) {
        _resetState("Screen ON");
      }
      return;
    }

    final now = _buffer.last.timestamp;
    final stats = _computeStats(now);

    switch (_state) {
      case SleepState.awake:
        _handleAwake(now, stats);
        break;
      case SleepState.maybeFallingAsleep:
        _handleMaybeFallingAsleep(now, stats);
        break;
      case SleepState.asleep:
        _handleAsleep(now, stats);
        break;
      case SleepState.maybeAwake:
        _handleMaybeAwake(now, stats);
        break;
    }
  }

  _Stats _computeStats(DateTime now) {
    final start = now.subtract(config.windowSize);

    final samples = _buffer.where((s) => !s.timestamp.isBefore(start)).toList();

    if (samples.isEmpty) return _Stats.empty(now);

    int still = 0;
    int screenOn = 0;
    int charging = 0;

    for (final s in samples) {
      if (s.movement <= config.stillnessThreshold) still++;
      if (s.screenOn) screenOn++;
      if (s.isCharging) charging++;
    }

    final total = samples.length;

    if (kDebugMode) {
      debugPrint(
        "[SleepDetector] window=${samples.length} "
        "stillRatio=${(still / total).toStringAsFixed(2)} "
        "screenOnRatio=${(screenOn / total).toStringAsFixed(2)} "
        "chargingRatio=${(charging / total).toStringAsFixed(2)}",
      );
    }

    return _Stats(
      start: start,
      end: now,
      stillRatio: still / total,
      screenOnRatio: screenOn / total,
      chargingRatio: charging / total,
      samples: samples,
    );
  }

  void _handleAwake(DateTime now, _Stats s) {
    final calm =
        s.stillRatio >= config.stillRatioThreshold && s.screenOnRatio < 0.1;

    if (calm) {
      _state = SleepState.maybeFallingAsleep;
      _candidateSleepStart = s.start;
      _saveState();
    }
  }

  void _handleMaybeFallingAsleep(DateTime now, _Stats s) {
    final calm =
        s.stillRatio >= config.stillRatioThreshold && s.screenOnRatio < 0.1;

    if (!calm) {
      _state = SleepState.awake;
      _candidateSleepStart = null;
      return;
    }

    _candidateSleepStart ??= s.start;

    final latency = now.difference(_candidateSleepStart!);

    if (latency >= config.minSleepLatency) {
      _state = SleepState.asleep;
      _confirmedSleepStart = _candidateSleepStart;
      onSleepStarted?.call(_confirmedSleepStart!);
      _saveState();
    }
  }

  void _handleAsleep(DateTime now, _Stats s) {
    final active = s.stillRatio < 0.4 || s.screenOnRatio > 0.2;

    if (active) {
      _state = SleepState.maybeAwake;
    }
  }

  void _handleMaybeAwake(DateTime now, _Stats s) {
    final active = s.stillRatio < 0.4 || s.screenOnRatio > 0.2;

    if (!active) {
      _state = SleepState.asleep;
      return;
    }

    if (_confirmedSleepStart == null) {
      _resetState("Wake but no start");
      return;
    }

    final duration = now.difference(_confirmedSleepStart!);

    if (duration < config.minSleepDuration) {
      _resetState("Too short");
      return;
    }

    final session = _buildSession(_confirmedSleepStart!, now);
    onSleepSessionDetected?.call(session);

    _state = SleepState.awake;
    _candidateSleepStart = null;
    _confirmedSleepStart = null;
    _buffer.clear();
    _saveState();
  }

  AutoSleepSession _buildSession(DateTime start, DateTime end) {
    final samples = _buffer
        .where((s) => !s.timestamp.isBefore(start) && !s.timestamp.isAfter(end))
        .toList();

    int still = 0;
    int charging = 0;

    for (final s in samples) {
      if (s.movement <= config.stillnessThreshold) still++;
      if (s.isCharging) charging++;
    }

    final stillRatio = samples.isNotEmpty ? still / samples.length : 0.0;
    final chargingRatio = samples.isNotEmpty ? charging / samples.length : 0.0;

    final totalDuration = end.difference(start);

    final stillDuration = Duration(
      milliseconds: (stillRatio * totalDuration.inMilliseconds).round(),
    );

    final confidence = _computeConfidence(
      start,
      end,
      stillRatio,
      chargingRatio,
    );

    return AutoSleepSession(
      start: start,
      end: end,
      confidence: confidence,
      wasChargingMostOfTime: chargingRatio >= 0.5,
      totalStillDuration: stillDuration,
      totalDuration: totalDuration,
    );
  }

  double _computeConfidence(
    DateTime start,
    DateTime end,
    double stillRatio,
    double chargingRatio,
  ) {
    double c = 0.4;
    c += (stillRatio - 0.5) * 0.6;
    c += chargingRatio * 0.25;

    final hours = end.difference(start).inMinutes / 60.0;

    if (hours >= 6 && hours <= 10) c += 0.2;
    if (hours < 3) c -= 0.1;
    if (hours > 10) c -= 0.1;

    return c.clamp(0.0, 1.0);
  }
}

class _Stats {
  final DateTime start;
  final DateTime end;
  final double stillRatio;
  final double screenOnRatio;
  final double chargingRatio;
  final List<SleepSample> samples;

  _Stats({
    required this.start,
    required this.end,
    required this.stillRatio,
    required this.screenOnRatio,
    required this.chargingRatio,
    required this.samples,
  });

  factory _Stats.empty(DateTime now) => _Stats(
    start: now,
    end: now,
    stillRatio: 0,
    screenOnRatio: 0,
    chargingRatio: 0,
    samples: [],
  );
}
