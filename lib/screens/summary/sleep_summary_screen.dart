import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_navbar.dart';
import '../history/sleep_history_screen.dart';
import '../../theme.dart';

class SleepSummaryScreen extends StatefulWidget {
  const SleepSummaryScreen({super.key});

  @override
  State<SleepSummaryScreen> createState() => _SleepSummaryScreenState();
}

class _SleepSummaryScreenState extends State<SleepSummaryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;

  // yyyy-MM-dd -> total hours slept that day
  final Map<String, double> _dailyTotals = {};

  double _avg7 = 0.0;
  double _avg30 = 0.0;
  int _daysWithSleep30 = 0;

  late final List<DateTime> _heatmapDays = List.generate(
    28,
    (i) => DateTime.now().subtract(Duration(days: 27 - i)),
  );

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (_user == null) return;

    final snap = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .limit(90)
        .get();

    _dailyTotals.clear();

    for (final doc in snap.docs) {
      final data = doc.data();
      final start = (data['start'] as Timestamp?)?.toDate();
      final end = (data['end'] as Timestamp?)?.toDate();
      if (start == null || end == null || !end.isAfter(start)) continue;

      final hours = end.difference(start).inMinutes / 60.0;
      final key = DateFormat('yyyy-MM-dd').format(start);
      _dailyTotals[key] = (_dailyTotals[key] ?? 0.0) + hours;
    }

    _computeAggregates();
    setState(() => _loading = false);
  }

  void _computeAggregates() {
    final now = DateTime.now();

    double total7 = 0;
    double total30 = 0;
    int count7 = 0;
    int count30 = 0;

    final daysWithSleep = <String>{};

    _dailyTotals.forEach((key, hours) {
      final date = DateTime.parse(key);
      final diff = now.difference(date).inDays;

      if (diff >= 0 && diff <= 6) {
        total7 += hours;
        count7++;
      }
      if (diff >= 0 && diff <= 29) {
        total30 += hours;
        count30++;
        if (hours > 0) daysWithSleep.add(key);
      }
    });

    _avg7 = count7 == 0 ? 0.0 : total7 / count7;
    _avg30 = count30 == 0 ? 0.0 : total30 / count30;
    _daysWithSleep30 = daysWithSleep.length;
  }

  double _hoursForDate(DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    return _dailyTotals[key] ?? 0.0;
  }

  // ========================= UI =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavBar(current: NavSection.summary),
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
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: kBrand),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      "Sleep Summary",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildSleepScoreHero(),
                    const SizedBox(height: 20),

                    _buildRecentStats(),
                    const SizedBox(height: 20),

                    _buildRoutineStability(),
                    const SizedBox(height: 20),

                    _buildHeatmapCard(),
                    const SizedBox(height: 20),

                    _buildHistoryLink(),
                  ],
                ),
        ),
      ),
    );
  }

  // ========================= CARDS =========================

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

  // ========================= SCORE =========================

  Widget _buildSleepScoreHero() {
    final int score = (_avg7 * 10).clamp(0, 100).round();

    final String label = score >= 80
        ? "Excellent sleep"
        : score >= 65
            ? "Good, but improvable"
            : score >= 45
                ? "Short or inconsistent sleep"
                : "Poor sleep quality";

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Sleep Score",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$score",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                "/ 100",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ========================= STATS =========================

  Widget _buildRecentStats() {
    return _glassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statBox("Avg (7 days)", "${_avg7.toStringAsFixed(1)} h"),
          _statBox("Avg (30 days)", "${_avg30.toStringAsFixed(1)} h"),
        ],
      ),
    );
  }

  Widget _statBox(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  // ========================= ROUTINE =========================

  Widget _buildRoutineStability() {
    final String label = _daysWithSleep30 >= 25
        ? "Very consistent"
        : _daysWithSleep30 >= 18
            ? "Fairly consistent"
            : _daysWithSleep30 >= 10
                ? "Irregular"
                : "Highly irregular";

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Routine Stability",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Sleep recorded on $_daysWithSleep30 of the last 30 days",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ========================= HEATMAP =========================

  Widget _buildHeatmapCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Last 28 Days",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tap a day with sleep to see details",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _heatmapDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, i) {
              final day = _heatmapDays[i];
              final hours = _hoursForDate(day);

              final double intensity =
                  hours == 0 ? 0.0 : (hours / 9).clamp(0.15, 1.0).toDouble();

              final Color bgColor = hours == 0
                  ? Colors.white.withValues(alpha: 0.12)
                  : Color.lerp(
                      const Color(0xFF4A00E0),
                      const Color(0xFF8E2DE2),
                      intensity,
                    )!;

              return GestureDetector(
                onTap: hours == 0
                    ? null
                    : () => _showDayDetails(context, day, hours),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: bgColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const _HeatmapLegend(),
        ],
      ),
    );
  }

  // ========================= DAY DETAILS =========================

  void _showDayDetails(BuildContext context, DateTime day, double hours) {
    final label = DateFormat('EEEE, MMM d').format(day);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A002E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${hours.toStringAsFixed(1)} h slept",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (hours / 9).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                color: kBrand,
                minHeight: 8,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              Text(
                _sleepInsight(hours),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  String _sleepInsight(double h) {
    if (h >= 7 && h <= 8.5) return "Great night. This is an optimal sleep range.";
    if (h >= 6) return "Decent sleep, slightly below optimal.";
    if (h >= 4) return "Short sleep. Try improving your wind-down routine.";
    return "Very low sleep. If frequent, consider adjusting your schedule.";
  }

  // ========================= HISTORY =========================

  Widget _buildHistoryLink() {
    return _glassCard(
      child: Row(
        children: [
          const Icon(Icons.timeline, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "View detailed sleep history",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SleepHistoryScreen(),
                ),
              );
            },
            child: const Text(
              "Open",
              style: TextStyle(color: kBrand),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================= LEGEND =========================

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendItem(color: Color(0xFF4A00E0), label: "0–3h"),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFF6A1BE0), label: "3–6h"),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFF8E2DE2), label: "6–9h"),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
