import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_navbar.dart';
import '../../theme.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Timer? _ticker;
  DateTime? _activeStart;
  String? _activeDocId;
  Duration _elapsed = Duration.zero;
  bool _initializing = true;

  double _avgHoursThisWeek = 0;
  double _longestHours = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _restoreActiveSession().then((_) {
      _listenTicker();
      _loadWeeklyPreview();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _restoreActiveSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _initializing = false);
        return;
      }

      final sp = await SharedPreferences.getInstance();
      final millis = sp.getInt('sleep_active_start_ms');
      final docId = sp.getString('sleep_active_doc');
      if (millis != null && docId != null) {
        _activeStart = DateTime.fromMillisecondsSinceEpoch(millis);
        _activeDocId = docId;
      } else {
        final q = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sleep_sessions')
            .where('end', isNull: true)
            .orderBy('start', descending: true)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          final d = q.docs.first;
          _activeDocId = d.id;
          _activeStart = (d['start'] as Timestamp).toDate();
          await sp.setInt('sleep_active_start_ms', _activeStart!.millisecondsSinceEpoch);
          await sp.setString('sleep_active_doc', _activeDocId!);
        }
      }

      if (_activeStart != null) {
        _elapsed = DateTime.now().difference(_activeStart!);
      }

      setState(() => _initializing = false);
    } catch (e) {
      if (kDebugMode) print('Failed to restore session: $e');
      setState(() => _initializing = false);
    }
  }

  void _listenTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_activeStart == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_activeStart!);
      });
    });
  }

  Future<void> _startSession() async {
    final user = _auth.currentUser;
    if (user == null || _activeStart != null) return;

    final now = DateTime.now();
    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sleep_sessions')
        .add({
      'start': Timestamp.fromDate(now),
      'end': null,
      'source': 'manual',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final sp = await SharedPreferences.getInstance();
    await sp.setInt('sleep_active_start_ms', now.millisecondsSinceEpoch);
    await sp.setString('sleep_active_doc', docRef.id);

    setState(() {
      _activeStart = now;
      _activeDocId = docRef.id;
      _elapsed = Duration.zero;
    });
  }

  Future<void> _stopSession() async {
    final user = _auth.currentUser;
    if (user == null || _activeStart == null || _activeDocId == null) return;

    final end = DateTime.now();
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sleep_sessions')
          .doc(_activeDocId!)
          .update({'end': Timestamp.fromDate(end)});

      final sp = await SharedPreferences.getInstance();
      await sp.remove('sleep_active_start_ms');
      await sp.remove('sleep_active_doc');

      setState(() {
        _activeStart = null;
        _activeDocId = null;
        _elapsed = Duration.zero;
      });

      _loadWeeklyPreview();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep session saved. Good morning! ☀️')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping session: $e')),
      );
    }
  }

  Future<void> _loadWeeklyPreview() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (DateTime.now().weekday + 6) % 7));

    final q = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sleep_sessions')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .orderBy('start', descending: true)
        .get();

    double totalHours = 0;
    double longest = 0;
    int completedCount = 0;

    final completedDays = <String>{};
    final df = DateFormat('yyyy-MM-dd');

    for (final doc in q.docs) {
      final start = (doc['start'] as Timestamp).toDate();
      final endTs = doc.data().containsKey('end') ? doc['end'] as Timestamp? : null;
      final end = endTs?.toDate();
      if (end != null && end.isAfter(start)) {
        final hours = end.difference(start).inMinutes / 60.0;
        totalHours += hours;
        completedCount += 1;
        if (hours > longest) longest = hours;
        completedDays.add(df.format(end));
      }
    }

    final avg = completedCount == 0 ? 0 : totalHours / completedCount;

    int streak = 0;
    for (int i = 0; i < 14; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      if (completedDays.contains(df.format(day))) {
        streak += 1;
      } else {
        break;
      }
    }

    setState(() {
      _avgHoursThisWeek = double.parse(avg.toStringAsFixed(2));
      _longestHours = double.parse(longest.toStringAsFixed(2));
      _streakDays = streak;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _activeStart != null;

    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.tracker),
      body: RefreshIndicator(
        onRefresh: _loadWeeklyPreview,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SessionCard(
              isActive: isActive,
              elapsed: _elapsed,
              onStart: _startSession,
              onStop: _stopSession,
            ),
            const SizedBox(height: 16),
            _PreviewStats(
              avgHoursThisWeek: _avgHoursThisWeek,
              longestHours: _longestHours,
              streakDays: _streakDays,
              onViewHistory: () => Navigator.pushReplacementNamed(context, '/summary'),
            ),
            const SizedBox(height: 16),
            _TipCard(
              text: isActive
                  ? 'Try dimming lights and silencing notifications for better sleep quality. 🌙'
                  : 'Aim for consistent bedtimes to improve sleep balance.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.isActive,
    required this.elapsed,
    required this.onStart,
    required this.onStop,
  });

  final bool isActive;
  final Duration elapsed;
  final VoidCallback onStart;
  final VoidCallback onStop;

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isActive ? Icons.nightlight_round : Icons.bedtime_outlined,
              size: 48,
              color: isActive ? kBrand : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              isActive ? 'Tracking your sleep…' : 'Ready to sleep?',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              isActive ? _fmt(elapsed) : 'Press Start when you go to bed',
              style: const TextStyle(fontSize: 20, letterSpacing: 1),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isActive ? null : onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: isActive ? onStop : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Recent sessions are shown in Summary.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStats extends StatelessWidget {
  const _PreviewStats({
    required this.avgHoursThisWeek,
    required this.longestHours,
    required this.streakDays,
    required this.onViewHistory,
  });

  final double avgHoursThisWeek;
  final double longestHours;
  final int streakDays;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Stats Preview', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(label: 'Avg (week)', value: '${avgHoursThisWeek.toStringAsFixed(2)} h'),
                _StatChip(label: 'Longest', value: '${longestHours.toStringAsFixed(2)} h'),
                _StatChip(label: 'Streak', value: '$streakDays days'),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewHistory,
                icon: const Icon(Icons.chevron_right),
                label: const Text('View Full Summary'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lightbulb, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
