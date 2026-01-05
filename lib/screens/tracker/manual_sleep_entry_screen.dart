import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManualSleepEntryScreen extends StatefulWidget {
  final DocumentSnapshot? existingDoc;

  const ManualSleepEntryScreen({super.key, this.existingDoc});

  @override
  State<ManualSleepEntryScreen> createState() => _ManualSleepEntryScreenState();
}

class _ManualSleepEntryScreenState extends State<ManualSleepEntryScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  DateTime? _startTime;
  DateTime? _endTime;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDoc != null) {
      final data = widget.existingDoc!.data()! as Map<String, dynamic>;
      _startTime = (data['start'] as Timestamp).toDate();
      _endTime = (data['end'] as Timestamp?)?.toDate();
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? (_startTime ?? now) : (_endTime ?? now);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;
    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _saveSession() async {
    if (_startTime == null || _endTime == null || _endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid start or end time')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = _auth.currentUser!;
      final collection = _firestore.collection('users').doc(user.uid).collection('sleep_records');

      if (widget.existingDoc == null) {
        // New entry
        await collection.add({
          'start': Timestamp.fromDate(_startTime!),
          'end': Timestamp.fromDate(_endTime!),
          'source': 'manual_entry',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing
        await collection.doc(widget.existingDoc!.id).update({
          'start': Timestamp.fromDate(_startTime!),
          'end': Timestamp.fromDate(_endTime!),
          'source': 'manual_entry',
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingDoc != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? "Edit Sleep Session" : "Add Sleep Session"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Start Time", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickDateTime(true),
              icon: const Icon(Icons.access_time),
              label: Text(
                _startTime == null
                    ? "Select Start"
                    : DateFormat('EEE, MMM d - h:mm a').format(_startTime!),
              ),
            ),
            const SizedBox(height: 20),
            const Text("End Time", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickDateTime(false),
              icon: const Icon(Icons.alarm),
              label: Text(
                _endTime == null
                    ? "Select End"
                    : DateFormat('EEE, MMM d - h:mm a').format(_endTime!),
              ),
            ),
            const Spacer(),
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.deepPurple,
                    ),
                    onPressed: _saveSession,
                    icon: Icon(editing ? Icons.save : Icons.add),
                    label: Text(editing ? "Save Changes" : "Add Session"),
                  ),
          ],
        ),
      ),
    );
  }
}
