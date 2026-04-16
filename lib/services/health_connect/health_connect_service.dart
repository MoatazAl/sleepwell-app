import 'package:flutter/services.dart';

class HealthConnectService {
  static const MethodChannel _channel =
      MethodChannel('sleepwell/health_connect');

  static Future<HealthConnectAvailability> getAvailability() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('getAvailability');
    return HealthConnectAvailability(
      status: (map?['status'] as num?)?.toInt() ?? -1,
      available: map?['available'] == true,
    );
  }

  static Future<void> openHealthConnectSettings() async {
    await _channel.invokeMethod('openHealthConnectSettings');
  }

  static Future<bool> hasSleepPermission() async {
    final value = await _channel.invokeMethod<bool>('hasSleepPermission');
    return value ?? false;
  }

  static Future<bool> requestSleepPermission() async {
    final map =
        await _channel.invokeMapMethod<String, dynamic>('requestSleepPermission');
    return map?['granted'] == true;
  }

  static Future<ImportedSleepSession?> readLatestSleepSession() async {
    final map =
        await _channel.invokeMapMethod<String, dynamic>('readLatestSleepSession');

    if (map == null) return null;
    return ImportedSleepSession.fromMap(Map<String, dynamic>.from(map));
  }
}

class HealthConnectAvailability {
  final int status;
  final bool available;

  const HealthConnectAvailability({
    required this.status,
    required this.available,
  });
}

class ImportedSleepStage {
  final String stage;
  final int? stageCode;
  final String start;
  final String end;

  ImportedSleepStage({
    required this.stage,
    required this.stageCode,
    required this.start,
    required this.end,
  });

  factory ImportedSleepStage.fromMap(Map<String, dynamic> map) {
    return ImportedSleepStage(
      stage: (map['stage'] ?? 'unknown').toString(),
      stageCode: (map['stageCode'] as num?)?.toInt(),
      start: (map['start'] ?? '').toString(),
      end: (map['end'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'stageCode': stageCode,
      'start': start,
      'end': end,
    };
  }
}

class ImportedSleepSession {
  final String start;
  final String end;
  final double durationHours;
  final int durationMinutes;
  final String? title;
  final String? notes;
  final String? sourcePackage;
  final List<ImportedSleepStage> stages;

  ImportedSleepSession({
    required this.start,
    required this.end,
    required this.durationHours,
    required this.durationMinutes,
    required this.title,
    required this.notes,
    required this.sourcePackage,
    required this.stages,
  });

  factory ImportedSleepSession.fromMap(Map<String, dynamic> map) {
    final rawStages = (map['stages'] as List?) ?? const [];
    return ImportedSleepSession(
      start: (map['start'] ?? '').toString(),
      end: (map['end'] ?? '').toString(),
      durationHours: ((map['durationHours'] as num?) ?? 0).toDouble(),
      durationMinutes: ((map['durationMinutes'] as num?) ?? 0).toInt(),
      title: map['title']?.toString(),
      notes: map['notes']?.toString(),
      sourcePackage: map['sourcePackage']?.toString(),
      stages: rawStages
          .map((e) => ImportedSleepStage.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
  
}
