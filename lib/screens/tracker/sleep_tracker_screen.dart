import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_navbar.dart';
import '../../theme.dart';
import 'manual_sleep_entry_screen.dart';

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
            .collection('sleep_records')
            .where('end', isNull: true)
            .orderBy('start', descending: true)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          final d = q.docs.first;
          _activeDocId = d.id;
          _activeStart = (d['start'] as Timestamp).toDate();

          await sp.setInt('sleep_active_start_ms',
              _activeStart!.millisecondsSinceEpoch);
          await sp.setString('sleep_active_doc', _activeDocId!);
        }
      }

      if (_activeStart != null) {
        _elapsed = DateTime.now().difference(_activeStart!);
      }

      setState(() => _initializing = false);
    } catch (e) {
      if (kDebugMode) print("Restore failed: $e");
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
        .collection('sleep_records')
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
          .collection('sleep_records')
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
        const SnackBar(content: Text("Session saved. Good morning! ☀️")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Stop error: $e")));
    }
  }

  Future<void> _loadWeeklyPreview() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final startOfWeek =
        now.subtract(Duration(days: (now.weekday + 6) % 7)); // Sunday start

    final q = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sleep_records')
        .where("start", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .orderBy("start", descending: true)
        .get();

    double totalHours = 0;
    double longest = 0;
    int completedCount = 0;

    final df = DateFormat('yyyy-MM-dd');
    final completedDays = <String>{};

    for (final doc in q.docs) {
      final start = (doc['start'] as Timestamp).toDate();
      final endTs = doc['end'] as Timestamp?;
      final end = endTs?.toDate();

      if (end != null && end.isAfter(start)) {
        final hours = end.difference(start).inMinutes / 60.0;
        totalHours += hours;
        completedCount++;
        if (hours > longest) longest = hours;
        completedDays.add(df.format(end));
      }
    }

    final double avg =
        completedCount == 0 ? 0.0 : totalHours / completedCount;

    int streak = 0;
    for (int i = 0; i < 14; i++) {
      final day = now.subtract(Duration(days: i));
      if (completedDays.contains(df.format(day))) {
        streak++;
      } else {
        break;
      }
    }

    setState(() {
      _avgHoursThisWeek = avg;
      _longestHours = longest;
      _streakDays = streak;
    });
  }

  Future<void> _openManualAddScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManualSleepEntryScreen()),
    );
    if (result == true) _loadWeeklyPreview();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _activeStart != null;

    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.tracker),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF120022), Color(0xFF050010)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: kBrand,
            onRefresh: _loadWeeklyPreview,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  "Sleep Tracker",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                _glassCard(child: _TrackerCardUI(isActive, _elapsed, _startSession, _stopSession)),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: _openManualAddScreen,
                  child: _glassCard(
                    child: Row(
                      children: const [
                        Icon(Icons.add_circle, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text("Add Sleep Session Manually",
                            style: TextStyle(color: Colors.white, fontSize: 16))
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _glassCard(
                  child: _StatsPreviewUI(
                    avg: _avgHoursThisWeek,
                    longest: _longestHours,
                    streak: _streakDays,
                  ),
                ),

                const SizedBox(height: 20),

                _glassCard(
                  child: Row(
                    children: const [
                      Icon(Icons.lightbulb, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Try to keep your sleep and wake times consistent for better rest 🌙",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TrackerCardUI extends StatelessWidget {
  final bool isActive;
  final Duration elapsed;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _TrackerCardUI(
    this.isActive,
    this.elapsed,
    this.onStart,
    this.onStop);

  String _fmt(Duration d) =>
      "${d.inHours.toString().padLeft(2, '0')}:"
      "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:"
      "${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          isActive ? Icons.nightlight_round : Icons.bedtime_outlined,
          size: 60,
          color: Colors.white,
        ),
        const SizedBox(height: 12),
        Text(
          isActive ? "Tracking your sleep…" : "Ready to sleep?",
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          isActive ? _fmt(elapsed) : "Press Start when going to bed",
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),

        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isActive ? null : onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrand,
                  disabledBackgroundColor: Colors.deepPurple.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Start", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isActive ? onStop : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  disabledBackgroundColor: Colors.red.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Stop", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsPreviewUI extends StatelessWidget {
  final double avg;
  final double longest;
  final int streak;

  const _StatsPreviewUI({
    required this.avg,
    required this.longest,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Weekly Sleep Summary",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _stat("Avg Sleep", "${avg.toStringAsFixed(1)}h"),
            _stat("Longest", "${longest.toStringAsFixed(1)}h"),
            _stat("Streak", "$streak days"),
          ],
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
