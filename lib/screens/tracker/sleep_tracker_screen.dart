import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
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

          await sp.setInt(
            'sleep_active_start_ms',
            _activeStart!.millisecondsSinceEpoch,
          );
          await sp.setString('sleep_active_doc', _activeDocId!);
        }
      }

      if (_activeStart != null) {
        _elapsed = DateTime.now().difference(_activeStart!);
      }

      setState(() => _initializing = false);
    } catch (e) {
      if (kDebugMode) {
        print('Restore failed: $e');
      }
      setState(() => _initializing = false);
    }
  }

  void _listenTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _activeStart == null) return;
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

      await _loadWeeklyPreview();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop error: $e')),
      );
    }
  }

  Future<void> _loadWeeklyPreview() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final startOfWeek =
        now.subtract(Duration(days: (now.weekday + 6) % 7));

    final q = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sleep_records')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .orderBy('start', descending: true)
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

    final avg = completedCount == 0 ? 0.0 : totalHours / completedCount;

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
    if (result == true) {
      _loadWeeklyPreview();
    }
  }

  String _formatElapsed(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:'
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isActive = _activeStart != null;

    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kBrand)),
      );
    }

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.tracker),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: RefreshIndicator(
            color: kBrand,
            onRefresh: _loadWeeklyPreview,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _glassCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sleep Tracker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isActive
                            ? 'Your session is running. Keep this going until you wake up.'
                            : 'Start tracking when you go to bed, or add a session manually if needed.',
                        style: const TextStyle(
                          color: kTextSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildMainTrackerCard(isActive),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _glassCard(
                        child: _smallActionTile(
                          icon: Icons.edit_calendar_rounded,
                          title: 'Add manually',
                          subtitle: 'Log a night yourself',
                          onTap: _openManualAddScreen,
                          accent: kAccentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _glassCard(
                        child: _smallActionTile(
                          icon: Icons.nightlight_round,
                          title: isActive ? 'Tracking now' : 'Ready tonight',
                          subtitle: isActive
                              ? 'Session is active'
                              : 'Press start at bedtime',
                          onTap: null,
                          accent: kBrand,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Sleep Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              label: 'Avg sleep',
                              value: '${_avgHoursThisWeek.toStringAsFixed(1)}h',
                              accent: kAccentBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              label: 'Longest',
                              value: '${_longestHours.toStringAsFixed(1)}h',
                              accent: kBrand,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              label: 'Streak',
                              value: '$_streakDays days',
                              accent: const Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _glassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: kAccentBlue, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Consistency matters more than one perfect night. Try to keep your sleep and wake times within a regular window.',
                          style: TextStyle(
                            color: kTextSecondary,
                            height: 1.45,
                          ),
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

  Widget _buildMainTrackerCard(bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isActive
              ? kAccentBlue.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? kAccentBlue.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isActive
                    ? [kAccentBlue, const Color(0xFF0EA5E9)]
                    : [kBrand, kBrandDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              isActive ? Icons.bedtime_rounded : Icons.nightlight_round,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isActive ? 'Tracking your sleep' : 'Ready to sleep?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isActive ? _formatElapsed(_elapsed) : 'Press Start when going to bed',
            style: TextStyle(
              color: isActive ? Colors.white : kTextSecondary,
              fontSize: isActive ? 34 : 18,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: isActive ? 1.0 : 0.0,
            ),
          ),
          if (_activeStart != null) ...[
            const SizedBox(height: 8),
            Text(
              'Started ${DateFormat('EEE, h:mm a').format(_activeStart!)}',
              style: const TextStyle(color: kTextMuted),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isActive ? null : _startSession,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isActive ? _stopSession : null,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isActive ? Colors.white : kTextMuted,
                    side: BorderSide(
                      color: isActive
                          ? const Color(0xFFFB7185)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    backgroundColor: isActive
                        ? const Color(0x22FB7185)
                        : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            width: 36,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _smallActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: kTextMuted),
        ],
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