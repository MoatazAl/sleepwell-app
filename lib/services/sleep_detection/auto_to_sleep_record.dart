import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sleep_record.dart';
import '../../models/sleep_event.dart';
import 'sleep_detector.dart'; // AutoSleepSession

class AutoSleepMapper {
  /// Converts an automatically detected session into a SleepRecord
  static SleepRecord toSleepRecord(AutoSleepSession session) {
    final durationHours =
        session.duration.inMinutes / 60.0;

    // Create a few helpful "events" the user can see in the timeline
    final List<SleepEvent> events = [
      SleepEvent(
        type: 'auto_detect_start',
        timestamp: session.start,
        value: null,
        note: 'Automatic sleep detection started',
      ),
      SleepEvent(
        type: 'auto_detect_end',
        timestamp: session.end,
        value: session.confidence,
        note:
            'Auto-detected sleep end (confidence ${(session.confidence * 100).round()}%)',
      ),
      SleepEvent(
        type: 'auto_meta',
        timestamp: session.end,
        value: null,
        note:
            'Still: ${session.totalStillDuration.inMinutes} min | Charging: ${session.wasChargingMostOfTime}',
      ),
    ];

    return SleepRecord(
      id: "", // Firestore will assign later
      start: session.start,
      end: session.end,
      durationHours: durationHours,
      sleepQuality: null,    // optional later
      efficiency: null,      // optional later
      note: null,
      source: 'auto',
      createdAt: DateTime.now(),
      events: events,
    );
  }
}
