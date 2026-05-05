import 'package:flutter/services.dart';

class HealthConnectService {
  static const MethodChannel _channel = MethodChannel(
    'sleepwell/health_connect',
  );

  static Future<HealthConnectAvailability> getAvailability() async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'getAvailability',
    );

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
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'requestSleepPermission',
    );

    return map?['granted'] == true;
  }

  static Future<ImportedSleepSession?> readLatestSleepSession() async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'readLatestSleepSession',
    );

    if (map == null) return null;

    return ImportedSleepSession.fromMap(Map<String, dynamic>.from(map));
  }

  static Future<List<ImportedSleepSession>> readSleepSessions({
    int daysBack = 30,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'readSleepSessions',
      {'daysBack': daysBack},
    );

    if (raw == null) return [];

    return raw.map((e) {
      return ImportedSleepSession.fromMap(Map<String, dynamic>.from(e as Map));
    }).toList();
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
    return {'stage': stage, 'stageCode': stageCode, 'start': start, 'end': end};
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
          .map(
            (e) =>
                ImportedSleepStage.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

ImportedSleepSession? mergeSleepSessions(
  Iterable<ImportedSleepSession> sessions, {
  DateTime? windowStart,
  DateTime? windowEnd,
  bool includeStages = true,
}) {
  final normalizedWindowStart = windowStart?.toUtc();
  final normalizedWindowEnd = windowEnd?.toUtc();

  if (normalizedWindowStart != null &&
      normalizedWindowEnd != null &&
      !normalizedWindowEnd.isAfter(normalizedWindowStart)) {
    return null;
  }

  final intervals = <_DateRange>[];
  final stageIntervals = <_StageRange>[];
  final sourcePackages = <String>{};
  final titles = <String>[];
  final notes = <String>[];

  for (final session in sessions) {
    final rawStart = DateTime.tryParse(session.start)?.toUtc();
    final rawEnd = DateTime.tryParse(session.end)?.toUtc();

    if (rawStart == null || rawEnd == null || !rawEnd.isAfter(rawStart)) {
      continue;
    }

    final start = _latestDate(rawStart, normalizedWindowStart);
    final end = _earliestDate(rawEnd, normalizedWindowEnd);

    if (!end.isAfter(start)) continue;

    intervals.add(_DateRange(start, end));

    final sourcePackage = session.sourcePackage?.trim();
    if (sourcePackage != null && sourcePackage.isNotEmpty) {
      sourcePackages.add(sourcePackage);
    }

    final title = session.title?.trim();
    if (title != null && title.isNotEmpty) titles.add(title);

    final note = session.notes?.trim();
    if (note != null && note.isNotEmpty) notes.add(note);

    if (!includeStages) continue;

    for (final stage in session.stages) {
      final rawStageStart = DateTime.tryParse(stage.start)?.toUtc();
      final rawStageEnd = DateTime.tryParse(stage.end)?.toUtc();

      if (rawStageStart == null ||
          rawStageEnd == null ||
          !rawStageEnd.isAfter(rawStageStart)) {
        continue;
      }

      // Stages are clipped to the imported session/window so bad provider
      // data cannot leak outside the sleep record being merged.
      final stageStart = _latestDate(rawStageStart, start);
      final stageEnd = _earliestDate(rawStageEnd, end);

      if (!stageEnd.isAfter(stageStart)) continue;

      stageIntervals.add(
        _StageRange(
          stage: _normalizeStage(stage.stage),
          stageCode: stage.stageCode,
          start: stageStart,
          end: stageEnd,
        ),
      );
    }
  }

  if (intervals.isEmpty) return null;

  // Duration is based on the union of intervals. Start/end still describe the
  // outer bounds, but gaps between separate sleeps are not counted as sleep.
  final mergedIntervals = _mergeDateRanges(intervals);
  final durationMinutes = mergedIntervals.fold<int>(
    0,
    (total, range) => total + range.duration.inMinutes,
  );

  return ImportedSleepSession(
    start: mergedIntervals.first.start.toIso8601String(),
    end: mergedIntervals.last.end.toIso8601String(),
    durationHours: durationMinutes / 60.0,
    durationMinutes: durationMinutes,
    title: titles.isEmpty ? null : titles.first,
    notes: _combineDistinct(notes),
    sourcePackage: _combineSourcePackages(sourcePackages),
    stages: includeStages ? _mergeStageRanges(stageIntervals) : const [],
  );
}

List<_DateRange> _mergeDateRanges(List<_DateRange> ranges) {
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_DateRange>[];

  var current = sorted.first;

  for (final next in sorted.skip(1)) {
    if (next.start.isAfter(current.end)) {
      merged.add(current);
      current = next;
      continue;
    }

    if (next.end.isAfter(current.end)) {
      current = _DateRange(current.start, next.end);
    }
  }

  merged.add(current);
  return merged;
}

List<ImportedSleepStage> _mergeStageRanges(List<_StageRange> ranges) {
  if (ranges.isEmpty) return const [];

  final boundaries = <int>{};
  for (final range in ranges) {
    boundaries
      ..add(range.start.microsecondsSinceEpoch)
      ..add(range.end.microsecondsSinceEpoch);
  }

  final points = boundaries.toList()..sort();
  final merged = <_StageRange>[];

  for (var i = 0; i < points.length - 1; i++) {
    final start = DateTime.fromMicrosecondsSinceEpoch(points[i], isUtc: true);
    final end = DateTime.fromMicrosecondsSinceEpoch(points[i + 1], isUtc: true);

    if (!end.isAfter(start)) continue;

    final covering = ranges.where((range) {
      return !range.start.isAfter(start) && !range.end.isBefore(end);
    }).toList();

    if (covering.isEmpty) continue;

    covering.sort(_compareStagePriority);
    final chosen = covering.first;

    if (merged.isNotEmpty &&
        merged.last.hasSameStage(chosen) &&
        merged.last.end.isAtSameMomentAs(start)) {
      merged[merged.length - 1] = merged.last.copyWith(end: end);
    } else {
      merged.add(chosen.copyWith(start: start, end: end));
    }
  }

  return merged
      .map(
        (range) => ImportedSleepStage(
          stage: range.stage,
          stageCode: range.stageCode,
          start: range.start.toIso8601String(),
          end: range.end.toIso8601String(),
        ),
      )
      .toList();
}

int _compareStagePriority(_StageRange a, _StageRange b) {
  final priority = _stagePriority(b.stage).compareTo(_stagePriority(a.stage));
  if (priority != 0) return priority;

  // Prefer the more precise interval when a generic "sleeping" stage overlaps
  // a detailed stage from another Health Connect provider.
  final duration = a.duration.compareTo(b.duration);
  if (duration != 0) return duration;

  final stage = a.stage.compareTo(b.stage);
  if (stage != 0) return stage;

  return (a.stageCode ?? -1).compareTo(b.stageCode ?? -1);
}

int _stagePriority(String stage) {
  switch (stage) {
    case 'awake':
    case 'awake_in_bed':
    case 'out_of_bed':
      return 50;
    case 'deep':
    case 'light':
    case 'rem':
      return 40;
    case 'sleeping':
      return 20;
    case 'unknown':
      return 0;
    default:
      return 10;
  }
}

DateTime _latestDate(DateTime date, DateTime? floor) {
  if (floor == null || date.isAfter(floor)) return date;
  return floor;
}

DateTime _earliestDate(DateTime date, DateTime? ceiling) {
  if (ceiling == null || date.isBefore(ceiling)) return date;
  return ceiling;
}

String _normalizeStage(String stage) {
  final normalized = stage.trim().toLowerCase();
  return normalized.isEmpty ? 'unknown' : normalized;
}

String? _combineDistinct(List<String> values) {
  final distinct = <String>[];

  for (final value in values) {
    if (!distinct.contains(value)) distinct.add(value);
  }

  return distinct.isEmpty ? null : distinct.join('\n');
}

String? _combineSourcePackages(Set<String> sourcePackages) {
  if (sourcePackages.isEmpty) return null;

  final sorted = sourcePackages.toList()..sort();
  return sorted.join(',');
}

class _DateRange {
  final DateTime start;
  final DateTime end;

  const _DateRange(this.start, this.end);

  Duration get duration => end.difference(start);
}

class _StageRange {
  final String stage;
  final int? stageCode;
  final DateTime start;
  final DateTime end;

  const _StageRange({
    required this.stage,
    required this.stageCode,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);

  bool hasSameStage(_StageRange other) {
    return stage == other.stage && stageCode == other.stageCode;
  }

  _StageRange copyWith({DateTime? start, DateTime? end}) {
    return _StageRange(
      stage: stage,
      stageCode: stageCode,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}
