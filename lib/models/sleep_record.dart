import 'package:cloud_firestore/cloud_firestore.dart';
import 'sleep_event.dart';

class SleepRecord {
  final String id;
  final DateTime start;
  final DateTime? end;

  final double? durationHours;
  final double? sleepQuality;
  final double? efficiency;
  final List<SleepEvent>? events;

  final String? note;
  final String source;
  final DateTime? createdAt;

  SleepRecord({
    required this.id,
    required this.start,
    required this.source,
    this.end,
    this.durationHours,
    this.sleepQuality,
    this.efficiency,
    this.events,
    this.note,
    this.createdAt,
  });

  factory SleepRecord.fromMap(Map<String, dynamic> map, String id) {
    final Timestamp startTs = map['start'];
    final Timestamp? endTs = map['end'];

    final DateTime start = startTs.toDate();
    final DateTime? end = endTs?.toDate();

    return SleepRecord(
      id: id,
      start: start,
      end: end,
      source: map['source'] ?? 'manual',
      durationHours: map['durationHours']?.toDouble() ??
          _computeDuration(start, end),
      sleepQuality: map['sleepQuality'] != null
          ? (map['sleepQuality'] as num).toDouble()
          : null,
      efficiency: map['efficiency'] != null
          ? (map['efficiency'] as num).toDouble()
          : null,
      note: map['note'],
      createdAt:
          map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      events: map['events'] != null
          ? (map['events'] as List)
              .map((e) => SleepEvent.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'start': Timestamp.fromDate(start),
        'end': end != null ? Timestamp.fromDate(end!) : null,
        'durationHours': durationHours,
        'sleepQuality': sleepQuality,
        'efficiency': efficiency,
        'note': note,
        'source': source,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'events': events?.map((e) => e.toMap()).toList(),
      };

  static double _computeDuration(DateTime start, DateTime? end) {
    if (end == null) return 0;
    final diff = end.difference(start).inMinutes / 60.0;
    return diff > 0 ? diff : 0;
  }

  double get computedDurationHours => _computeDuration(start, end);

  SleepRecord copyWith({
    String? id,
    DateTime? start,
    DateTime? end,
    double? durationHours,
    double? sleepQuality,
    double? efficiency,
    List<SleepEvent>? events,
    String? note,
    String? source,
    DateTime? createdAt,
  }) {
    return SleepRecord(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      durationHours: durationHours ?? this.durationHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      efficiency: efficiency ?? this.efficiency,
      events: events ?? this.events,
      note: note ?? this.note,
      source: source ?? this.source,
       createdAt: createdAt ?? this.createdAt,
    );
  }
}
