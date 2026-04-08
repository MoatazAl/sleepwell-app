import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
import '../history/sleep_history_screen.dart';
import '../tracker/manual_sleep_entry_screen.dart';
import '../tracker/sleep_tracker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _lastSleep;
  List<Map<String, dynamic>> _recentDays = [];

  double _weeklyAverage = 0.0;
  String? _bestDay;
  double? _bestDuration;
  String? _worstDay;
  double? _worstDuration;
  int _weekCount = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSleepData();
  }

  Future<void> _loadSleepData() async {
    if (_user == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    final snapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .limit(60)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _lastSleep = null;
        _recentDays = [];
        _weeklyAverage = 0.0;
        _bestDay = null;
        _bestDuration = null;
        _worstDay = null;
        _worstDuration = null;
        _weekCount = 0;
        _loading = false;
      });
      return;
    }

    final sessions = snapshot.docs.map((doc) {
      final data = doc.data();
      final start = (data['start'] as Timestamp?)?.toDate();
      final end = (data['end'] as Timestamp?)?.toDate();

      double duration = 0.0;
      if (start != null && end != null && end.isAfter(start)) {
        duration = end.difference(start).inMinutes / 60.0;
      }

      if (duration > 14) duration = 0.0;

      return {
        'start': start,
        'duration': duration,
      };
    }).toList();

    final Map<String, double> dailyTotals = {};
    final Map<String, DateTime> dayDates = {};

    for (final s in sessions) {
      final start = s['start'] as DateTime?;
      final duration = s['duration'] as double;

      if (start == null || duration <= 0) continue;

      final key = DateFormat('yyyy-MM-dd').format(start);
      dailyTotals[key] = (dailyTotals[key] ?? 0) + duration;
      dayDates[key] = start;
    }

    final recentDays = dailyTotals.entries
        .map((e) => {
              'date': dayDates[e.key]!,
              'duration': e.value,
            })
        .toList()
      ..sort((a, b) =>
          (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    Map<String, dynamic>? lastSleep;
    if (recentDays.isNotEmpty) {
      lastSleep = recentDays.first;
    }

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));

    final weekDays = recentDays.where((d) {
      final date = d['date'] as DateTime;
      return date.isAfter(weekStart);
    }).toList();

    final weeklyAverage = weekDays.isEmpty
        ? 0.0
        : weekDays
                .map((d) => d['duration'] as double)
                .reduce((a, b) => a + b) /
            weekDays.length;

    String? bestDay;
    String? worstDay;
    double bestDur = -1;
    double worstDur = double.infinity;

    for (final d in weekDays) {
      final dur = d['duration'] as double;
      final label = DateFormat('E').format(d['date'] as DateTime);

      if (dur > bestDur) {
        bestDur = dur;
        bestDay = label;
      }
      if (dur < worstDur) {
        worstDur = dur;
        worstDay = label;
      }
    }

    setState(() {
      _lastSleep = lastSleep;
      _recentDays = recentDays.take(5).toList();
      _weeklyAverage = weeklyAverage;
      _bestDay = bestDay;
      _worstDay = worstDay;
      _bestDuration = bestDur > 0 ? bestDur : null;
      _worstDuration = worstDur < double.infinity ? worstDur : null;
      _weekCount = weekDays.length;
      _loading = false;
    });
  }

  String _formatDate(DateTime d) => DateFormat('E, MMM d').format(d);

  String _firstName() {
    final user = _user;
    if (user == null) return 'there';

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final email = user.email?.trim();
    if (email != null && email.contains('@')) {
      final raw = email.split('@').first.trim();
      if (raw.isNotEmpty) {
        return raw[0].toUpperCase() + raw.substring(1);
      }
    }

    return 'there';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _heroSubtitle() {
    if (_recentDays.isEmpty) {
      return 'Track your first night, build your sleep profile, and start turning habits into real progress.';
    }

    if (_weeklyAverage < 6) {
      return 'Your recent sleep is below a healthy target. Let’s work on getting more hours and a steadier routine.';
    }

    if (_hasHighVariance()) {
      return 'You have some good nights, but your schedule varies. Consistency is your biggest opportunity right now.';
    }

    if (_weeklyAverage < 7) {
      return 'You are getting close. A slightly earlier bedtime could move you into a healthier range.';
    }

    return 'You are building a solid routine. Keep tracking and stay consistent to protect your progress.';
  }

  bool _hasHighVariance() {
    if (_bestDuration == null || _worstDuration == null) return false;
    return (_bestDuration! - _worstDuration!).abs() > 2.0;
  }

  String _snapshotTitle() {
    if (_recentDays.isEmpty) return 'Your sleep snapshot';
    if (_weeklyAverage < 6) return 'Focus for this week';
    if (_hasHighVariance()) return 'Focus for this week';
    if (_weeklyAverage < 7) return 'You are getting closer';
    return 'You are on a good track';
  }

  String _snapshotBody() {
    if (_recentDays.isEmpty) {
      return 'No sleep data yet. Record your first night to unlock weekly patterns, recent history, and more meaningful feedback.';
    }

    if (_weeklyAverage < 6) {
      return 'You are averaging ${_weeklyAverage.toStringAsFixed(1)} hours per night. Try protecting your bedtime and aiming for more total sleep.';
    }

    if (_hasHighVariance()) {
      return 'Your sleep duration changes noticeably across the week. Try going to bed and waking up within a more regular time window.';
    }

    if (_weeklyAverage < 7) {
      return 'Your average is ${_weeklyAverage.toStringAsFixed(1)} hours. You are close to the recommended range, and small improvements could help a lot.';
    }

    return 'Your recent average is ${_weeklyAverage.toStringAsFixed(1)} hours, which is a strong base. Keep the routine steady and watch for consistency over time.';
  }

  String _recommendationTitle() {
    if (_recentDays.isEmpty) return 'Start building your sleep profile';
    if (_weeklyAverage < 6) return 'Sleep longer';
    if (_hasHighVariance()) return 'Sleep more consistently';
    if (_weeklyAverage < 7) return 'Aim for 7–9 hours';
    return 'Keep the momentum going';
  }

  String _recommendationBody() {
    if (_recentDays.isEmpty) {
      return 'Start with tracking or add a recent night manually. Once you have a few records, SleepWell can begin showing clearer patterns.';
    }
    if (_weeklyAverage < 6) {
      return 'Try moving bedtime earlier by 30–60 minutes and reducing late-night screen time when possible.';
    }
    if (_hasHighVariance()) {
      return 'A steadier sleep schedule can improve energy, focus, and recovery even before your total hours change dramatically.';
    }
    if (_weeklyAverage < 7) {
      return 'You are close to the target range. A small adjustment to your routine could make your sleep healthier and more reliable.';
    }
    return 'Your routine looks healthier this week. Keep logging sleep so you can spot changes early and stay consistent.';
  }

  String _consistencyText() {
    if (_bestDuration == null || _worstDuration == null) {
      return 'Track a few nights to reveal your sleep consistency.';
    }

    final diff = (_bestDuration! - _worstDuration!).abs();

    if (diff < 1.0) {
      return 'Your sleep duration looks fairly consistent this week.';
    } else if (diff < 2.0) {
      return 'Your sleep varies a bit through the week.';
    } else {
      return 'Your sleep duration changes a lot across the week.';
    }
  }

  void _openTracker() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SleepTrackerScreen()),
    );
  }

  void _openManualEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManualSleepEntryScreen()),
    ).then((result) {
      if (result == true) {
        _loadSleepData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavBar(current: NavSection.home),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: RefreshIndicator(
            color: kBrand,
            onRefresh: _loadSleepData,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kBrand),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      _buildHeroSection(),
                      const SizedBox(height: 18),
                      _buildPrimaryActions(),
                      const SizedBox(height: 18),
                      _buildHowItHelps(),
                      const SizedBox(height: 18),
                      _buildSleepSnapshot(),
                      const SizedBox(height: 18),
                      if (_recentDays.isNotEmpty) ...[
                        _buildPerformanceRow(),
                        const SizedBox(height: 18),
                      ],
                      _buildRecentHistory(),
                      const SizedBox(height: 18),
                      _buildRecommendationCard(),
                      const SizedBox(height: 18),
                      _buildTipOfDay(),
                    ],
                  ),
          ),
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

  Widget _buildHeroSection() {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [kBrand, kBrandDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: kBrand.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, ${_firstName()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sleep better, one night at a time.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _heroSubtitle(),
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openTracker,
            icon: const Icon(Icons.bedtime_rounded),
            label: const Text('Start Tracking'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openManualEntry,
            icon: const Icon(Icons.edit_calendar_rounded),
            label: const Text('Add Manually'),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItHelps() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How SleepWell helps',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _HelpItem(
                icon: Icons.schedule_rounded,
                title: 'Track sleep',
                subtitle: 'Log nights automatically or manually.',
              ),
              _HelpItem(
                icon: Icons.insights_rounded,
                title: 'Spot patterns',
                subtitle: 'See your recent averages and weekly trends.',
              ),
              _HelpItem(
                icon: Icons.auto_graph_rounded,
                title: 'Build consistency',
                subtitle: 'Use simple guidance to strengthen your routine.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepSnapshot() {
    if (_recentDays.isEmpty) {
      return _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your sleep snapshot',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.nights_stay_rounded, color: Colors.white70),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No sleep data yet. Record your first night to unlock weekly patterns, recent history, and personalized recommendations.',
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
      );
    }

    final lastDate = _lastSleep?['date'] as DateTime?;
    final lastDuration = _lastSleep?['duration'] as double?;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _snapshotTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _snapshotBody(),
            style: const TextStyle(
              color: kTextSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  label: 'Latest sleep',
                  value: lastDuration == null
                      ? '--'
                      : '${lastDuration.toStringAsFixed(1)}h',
                  helper: lastDate == null ? 'No date' : _formatDate(lastDate),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniMetric(
                  label: 'Weekly average',
                  value: '${_weeklyAverage.toStringAsFixed(1)}h',
                  helper:
                      _weekCount == 0 ? 'No nights yet' : 'Across $_weekCount night${_weekCount == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow() {
    return Row(
      children: [
        Expanded(
          child: _glassCard(
            child: _statTile(
              icon: Icons.hotel_rounded,
              title: 'Best night',
              value: _bestDay == null || _bestDuration == null
                  ? '--'
                  : '$_bestDay • ${_bestDuration!.toStringAsFixed(1)}h',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glassCard(
            child: _statTile(
              icon: Icons.tune_rounded,
              title: 'Consistency',
              value: _consistencyText(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Sleep',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SleepHistoryScreen(),
                ),
              ),
              child: const Text(
                'View All →',
                style: TextStyle(color: kBrand),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: _recentDays.isEmpty
              ? _glassCard(
                  child: const Center(
                    child: Text(
                      'No history yet',
                      style: TextStyle(color: kTextSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentDays.length,
                  itemBuilder: (_, i) {
                    final d = _recentDays[i];
                    return Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A0A4A), Color(0xFF4A1D74)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${d['duration'].toStringAsFixed(1)}h',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(d['date'] as DateTime),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _recommendationTitle(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _recommendationBody(),
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipOfDay() {
    final tips = [
      'Try keeping the same bedtime and wake-up time every day.',
      'Dim lights and reduce screen exposure before bed when possible.',
      'A cool, dark, and quiet room can improve sleep quality.',
      'Avoid caffeine late in the day if falling asleep is difficult.',
      'A short wind-down routine can help your body settle before sleep.',
    ];

    final tip = tips[DateTime.now().weekday % tips.length];

    return _glassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lightbulb_outline_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip of the day: $tip',
              style: const TextStyle(
                color: Colors.white,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required String label,
    required String value,
    required String helper,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12)),
          const SizedBox(height: 6),
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
            helper,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: kTextMuted, fontSize: 12)),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}