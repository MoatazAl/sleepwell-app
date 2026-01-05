import 'package:flutter/material.dart';
import '../../../services/firestore/firestore_service.dart';
import '../../../models/sleep_record.dart';
import 'edit_sleep_entry_screen.dart';

class SleepHistoryScreen extends StatelessWidget {
  const SleepHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sleep History")),
      body: FutureBuilder<List<SleepRecord>>(
        future: FirestoreService.getAllSleepRecords(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text("No sleep sessions yet."));
          }

          final list = snap.data!;

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];

              return ListTile(
                title: Text(
                  "${s.start} — ${s.computedDurationHours.toStringAsFixed(1)}h",
                ),
                subtitle: Text("Quality: ${s.sleepQuality ?? 'N/A'}"),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditSleepEntryScreen(record: s),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
