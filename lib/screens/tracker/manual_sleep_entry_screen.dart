import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';

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

    if (!mounted) return;
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
    if (_startTime == null ||
        _endTime == null ||
        _endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid start or end time')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = _auth.currentUser!;
      final collection = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sleep_records');

      if (widget.existingDoc == null) {
        await collection.add({
          'start': Timestamp.fromDate(_startTime!),
          'end': Timestamp.fromDate(_endTime!),
          'source': 'manual_entry',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await collection.doc(widget.existingDoc!.id).update({
          'start': Timestamp.fromDate(_startTime!),
          'end': Timestamp.fromDate(_endTime!),
          'source': 'manual_entry',
        });
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving session: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _durationText() {
    if (_startTime == null ||
        _endTime == null ||
        _endTime!.isBefore(_startTime!)) {
      return 'Choose a valid start and end time.';
    }

    final duration = _endTime!.difference(_startTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '$hours h ${minutes.toString().padLeft(2, '0')} min total';
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingDoc != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(editing ? 'Edit Sleep Session' : 'Add Sleep Session'),
      ),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _glassCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editing
                            ? 'Update a recorded sleep session'
                            : 'Add a sleep session manually',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Use this when you forgot to track a night or want to correct a previous entry.',
                        style: TextStyle(color: kTextSecondary, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Start time'),
                      const SizedBox(height: 10),
                      _timeButton(
                        icon: Icons.bedtime_rounded,
                        label: _startTime == null
                            ? 'Select start'
                            : DateFormat(
                                'EEE, MMM d • h:mm a',
                              ).format(_startTime!),
                        accent: kBrand,
                        onTap: () => _pickDateTime(true),
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('End time'),
                      const SizedBox(height: 10),
                      _timeButton(
                        icon: Icons.wb_sunny_outlined,
                        label: _endTime == null
                            ? 'Select end'
                            : DateFormat(
                                'EEE, MMM d • h:mm a',
                              ).format(_endTime!),
                        accent: kAccentBlue,
                        onTap: () => _pickDateTime(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _glassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: kAccentBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimated duration',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _durationText(),
                              style: const TextStyle(
                                color: kTextSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: kBrand),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveSession,
                          icon: Icon(
                            editing ? Icons.save_rounded : Icons.add_rounded,
                          ),
                          label: Text(editing ? 'Save Changes' : 'Add Session'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _timeButton({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: glassCardDecoration,
      child: child,
    );
  }
}
