import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_navbar.dart';
import '../history/sleep_history_screen.dart';
import '../../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _lastNight; // ← AGGREGATED
  List<Map<String, dynamic>> _recentDays = [];

  double _weeklyAverage = 0.0;

  String? _bestDay;
  double? _bestDuration;
  String? _worstDay;
  double? _worstDuration;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSleepData();
  }

  // =====================================================
  // DATA LOADING & ANALYTICS
  // =====================================================

  Future<void> _loadSleepData() async {
    if (_user == null) return;

    setState(() => _loading = true);

    final snapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _lastNight = null;
        _recentDays = [];
        _weeklyAverage = 0;
        _bestDay = _worstDay = null;
        _bestDuration = _worstDuration = null;
        _loading = false;
      });
      return;
    }

    // ------------------------------
    // Parse sessions
    // ------------------------------
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

    // ------------------------------
    // AGGREGATE PER DAY
    // ------------------------------
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

    // ------------------------------
    // LAST NIGHT (MOST RECENT DAY)
    // ------------------------------
    Map<String, dynamic>? lastNight;
    if (recentDays.isNotEmpty) {
      lastNight = recentDays.first;
    }

    // ------------------------------
    // WEEKLY STATS (LAST 7 DAYS)
    // ------------------------------
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
      _lastNight = lastNight;
      _recentDays = recentDays.take(5).toList();
      _weeklyAverage = weeklyAverage;
      _bestDay = bestDay;
      _worstDay = worstDay;
      _bestDuration = bestDur > 0 ? bestDur : null;
      _worstDuration = worstDur < double.infinity ? worstDur : null;
      _loading = false;
    });
  }

  String _formatDate(DateTime d) => DateFormat('E, MMM d').format(d);

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavBar(current: NavSection.home),
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
            onRefresh: _loadSleepData,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kBrand),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        "Today’s Sleep Overview",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildLastNightCard(),
                      const SizedBox(height: 20),

                      _buildWeeklyAverageCard(),
                      const SizedBox(height: 20),

                      _buildBestWorstCard(),
                      const SizedBox(height: 24),

                      _buildRecentHistory(),
                      const SizedBox(height: 24),

                      _buildTipOfDay(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // CARDS
  // =====================================================

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.08),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLastNightCard() {
    if (_lastNight == null) {
      return _glassCard(
        child: const Text(
          "No sleep recorded yet 🌙",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Last Night",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            "${_lastNight!['duration'].toStringAsFixed(1)} hours",
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(_lastNight!['date'] as DateTime),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyAverageCard() {
    return _glassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Weekly Average",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                "${_weeklyAverage.toStringAsFixed(1)} hours / night",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const Icon(Icons.bedtime, color: Colors.white, size: 36),
        ],
      ),
    );
  }

  Widget _buildBestWorstCard() {
    if (_bestDay == null || _worstDay == null) {
      return _glassCard(
        child: const Text(
          "Not enough data to show weekly highlights.",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("This Week’s Highlights",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            "Best night: $_bestDay (${_bestDuration!.toStringAsFixed(1)} h)",
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            "Shortest night: $_worstDay (${_worstDuration!.toStringAsFixed(1)} h)",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Recent Sleep",
                style: TextStyle(color: Colors.white, fontSize: 18)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SleepHistoryScreen()),
              ),
              child:
                  const Text("View All →", style: TextStyle(color: kBrand)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: _recentDays.isEmpty
              ? const Center(
                  child: Text("No history yet",
                      style: TextStyle(color: Colors.white70)),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentDays.length,
                  itemBuilder: (_, i) {
                    final d = _recentDays[i];
                    return Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2D0B5A),
                            Color(0xFF451F78),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${d['duration'].toStringAsFixed(1)}h",
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDate(d['date'] as DateTime),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
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

  Widget _buildTipOfDay() {
    final tips = [
      "Avoid screens 30 minutes before bed",
      "Keep your bedroom cool and dark",
      "Stick to a consistent bedtime",
      "Avoid caffeine in the afternoon",
      "Wind down with calm breathing",
    ];
    final tip = tips[DateTime.now().weekday % tips.length];

    return _glassCard(
      child: Text(
        "Tip of the Day: $tip",
        style: const TextStyle(
            color: Colors.white, fontStyle: FontStyle.italic),
      ),
    );
  }
}
