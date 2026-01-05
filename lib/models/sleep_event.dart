import 'package:cloud_firestore/cloud_firestore.dart';

class SleepEvent {
  final String type;
  final DateTime timestamp;
  final double? value;
  final String? note;

  SleepEvent({
    required this.type,
    required this.timestamp,
    this.value,
    this.note,
  });

  factory SleepEvent.fromMap(Map<String, dynamic> map) {
    return SleepEvent(
      type: map['type'] ?? 'unknown',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      value: map['value'] != null ? (map['value'] as num).toDouble() : null,
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'timestamp': Timestamp.fromDate(timestamp),
        'value': value,
        'note': note,
      };
}
