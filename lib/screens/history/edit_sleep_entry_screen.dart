import 'package:flutter/material.dart';
import '../../../models/sleep_record.dart';
import '../../../services/firestore/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditSleepEntryScreen extends StatefulWidget {
  final SleepRecord record;

  const EditSleepEntryScreen({super.key, required this.record});

  @override
  State<EditSleepEntryScreen> createState() => _EditSleepEntryScreenState();
}

class _EditSleepEntryScreenState extends State<EditSleepEntryScreen> {
  late DateTime start;
  late DateTime end;
  late TextEditingController noteCtrl;

  @override
  void initState() {
    super.initState();
    start = widget.record.start;
    end = widget.record.end ?? widget.record.start;
    noteCtrl = TextEditingController(text: widget.record.note ?? "");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Sleep Session")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Start: $start"),
            Text("End: $end"),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "Note"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final updated = widget.record.copyWith(
                  start: start,
                  end: end,
                  durationHours: widget.record
                      .copyWith(start: start, end: end)
                      .computedDurationHours,
                  note: noteCtrl.text.trim(),
                );

                await FirestoreService.updateSleepRecord(widget.record.id, {
                  'start': Timestamp.fromDate(start),
                  'end': Timestamp.fromDate(end),
                  'durationHours': updated.durationHours,
                  'note': updated.note,
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
