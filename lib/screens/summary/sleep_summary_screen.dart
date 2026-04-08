import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
import '../history/sleep_history_screen.dart';

class SleepSummaryScreen extends StatefulWidget {
  const SleepSummaryScreen({super.key});

  @override
  State<SleepSummaryScreen> createState() => _SleepSummaryScreenState();
}

class _SleepSummaryScreenState extends State<SleepSummaryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;

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
    if (_user == null) {
      setState(() => _loading = false);
      return;
    }

    final snap = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .limit(120)
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

    if (mounted) {
      setState(() => _loading = false);
    }
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

  int _sleepScore() => (_avg7 * 10).clamp(0, 100).round();

  String _scoreLabel(int score) {
    if (score >= 80) return 'Strong recent sleep';
    if (score >= 65) return 'Good, with room to improve';
    if (score >= 45) return 'Short or inconsistent sleep';
    return 'Sleep needs attention';
  }

  String _scoreDescription() {
    if (_avg7 == 0) {
      return 'Record a few nights to unlock a more meaningful sleep score and stronger trend analysis.';
    }
    if (_avg7 >= 7 && _avg7 <= 8.5) {
      return 'Your recent average is in a healthy range. Focus on keeping the routine steady.';
    }
    if (_avg7 >= 6) {
      return 'You are close to a healthier range. A bit more sleep and consistency could improve this score.';
    }
    return 'Your recent average is low. Sleeping longer and keeping a steadier bedtime should be the next priority.';
  }

  String _routineLabel() {
    if (_daysWithSleep30 >= 25) return 'Very consistent';
    if (_daysWithSleep30 >= 18) return 'Fairly consistent';
    if (_daysWithSleep30 >= 10) return 'Irregular';
    return 'Highly irregular';
  }

  String _routineDescription() {
    if (_daysWithSleep30 >= 25) {
      return 'You recorded sleep on most days this month, which gives you a strong base for tracking patterns.';
    }
    if (_daysWithSleep30 >= 18) {
      return 'You are building a decent routine, though there are still gaps in your tracking and schedule.';
    }
    if (_daysWithSleep30 >= 10) {
      return 'Your routine is still uneven. More frequent tracking will make your feedback much more useful.';
    }
    return 'There is not enough regular data yet. Recording more nights will make your summary much stronger.';
  }

  String _trendMessage() {
    if (_avg7 == 0 && _avg30 == 0) return 'No meaningful trend yet.';
    final diff = _avg7 - _avg30;
    if (diff >= 0.5) return 'Your last 7 days are trending better than your 30-day average.';
    if (diff <= -0.5) return 'Your recent sleep is below your longer-term average.';
    return 'Your recent sleep is broadly in line with your monthly average.';
  }

  String _trendShortLabel() {
    if (_avg7 == 0 && _avg30 == 0) return 'No trend';
    final diff = _avg7 - _avg30;
    if (diff >= 0.5) return 'Improving';
    if (diff <= -0.5) return 'Dropping';
    return 'Stable';
  }

  String _sleepInsight(double h) {
    if (h >= 7 && h <= 8.5) return 'Great night. This is a strong range for healthy sleep.';
    if (h >= 6) return 'Decent sleep, though still slightly below the ideal range.';
    if (h >= 4) return 'This was a short night. A calmer wind-down routine may help.';
    return 'Very low sleep for one night. If this happens often, your schedule may need adjustment.';
  }

  List<_DayHours> _lastNDays(int n) {
    return List.generate(n, (i) {
      final date = DateTime.now().subtract(Duration(days: n - 1 - i));
      return _DayHours(date: date, hours: _hoursForDate(date));
    });
  }

  @override
  Widget build(BuildContext context) {
    final score = _sleepScore();

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.summary),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: kBrand),
                )
              : RefreshIndicator(
                  color: kBrand,
                  onRefresh: _loadAnalytics,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      _buildHero(score),
                      const SizedBox(height: 18),
                      _buildChartsSection(),
                      const SizedBox(height: 18),
                      _buildTopStats(),
                      const SizedBox(height: 18),
                      _buildRoutineCard(),
                      const SizedBox(height: 18),
                      _buildHeatmapCard(),
                      const SizedBox(height: 18),
                      _buildHistoryLink(),
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

  Widget _buildHero(int score) {
    return _glassCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          _ScoreRing(score: score),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sleep Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _scoreLabel(score),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _scoreDescription(),
                  style: const TextStyle(
                    color: kTextSecondary,
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

  Widget _buildChartsSection() {
    final bars = _lastNDays(7);
    final trend = _lastNDays(14);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last 7 Nights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quick comparison of recent sleep duration',
                  style: TextStyle(color: kTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: _BarChart(days: bars),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '14-Day Trend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _trendMessage(),
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: _LineChart(days: trend),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Avg (7 days)',
            value: '${_avg7.toStringAsFixed(1)} h',
            subtitle: 'Recent sleep average',
            accent: kAccentBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Avg (30 days)',
            value: '${_avg30.toStringAsFixed(1)} h',
            subtitle: 'Monthly average',
            accent: kBrand,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Recent trend',
            value: _trendShortLabel(),
            subtitle: _trendMessage(),
            accent: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            width: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: kTextSecondary,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Routine Stability',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InsightChip(
                icon: Icons.auto_graph_rounded,
                label: _routineLabel(),
                color: kAccentBlue,
              ),
              _InsightChip(
                icon: Icons.calendar_month_rounded,
                label: '$_daysWithSleep30 / 30 days',
                color: kBrand,
              ),
              _InsightChip(
                icon: Icons.trending_up_rounded,
                label: _trendShortLabel(),
                color: const Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _routineDescription(),
            style: const TextStyle(
              color: kTextSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 28 Days',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap any day with recorded sleep to view a quick breakdown.',
            style: TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _heatmapDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final day = _heatmapDays[i];
              final hours = _hoursForDate(day);

              final double intensity =
                  hours == 0 ? 0.0 : (hours / 9).clamp(0.18, 1.0).toDouble();

              final Color bgColor = hours == 0
                  ? Colors.white.withValues(alpha: 0.08)
                  : Color.lerp(
                      const Color(0xFF1D4ED8),
                      const Color(0xFF8B5CF6),
                      intensity,
                    )!;

              return Tooltip(
                message:
                    '${DateFormat('MMM d').format(day)} • ${hours.toStringAsFixed(1)} h',
                child: GestureDetector(
                  onTap: hours == 0
                      ? null
                      : () => _showDayDetails(context, day, hours),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: bgColor,
                      border: Border.all(
                        color: hours == 0
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          const _HeatmapLegend(),
        ],
      ),
    );
  }

  void _showDayDetails(BuildContext context, DateTime day, double hours) {
    final label = DateFormat('EEEE, MMM d').format(day);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16051F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${hours.toStringAsFixed(1)} h slept',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: (hours / 9).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                color: kAccentBlue,
                minHeight: 10,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              Text(
                _sleepInsight(hours),
                style: const TextStyle(
                  color: kTextSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryLink() {
    return _glassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: kBrand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: kBrand),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detailed Sleep History',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Open the full record of your past sleep sessions.',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
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
              'Open',
              style: TextStyle(color: kBrand),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHours {
  final DateTime date;
  final double hours;

  _DayHours({
    required this.date,
    required this.hours,
  });
}

class _ScoreRing extends StatelessWidget {
  final int score;

  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 128,
      child: CustomPaint(
        painter: _RingPainter(progress: score / 100),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                '/100',
                style: TextStyle(
                  color: kTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [kAccentBlue, kBrand],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _BarChart extends StatelessWidget {
  final List<_DayHours> days;

  const _BarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final maxHours = math.max(
      8.0,
      days.fold<double>(0, (max, d) => d.hours > max ? d.hours : max),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((d) {
        final heightFactor = maxHours == 0 ? 0.0 : (d.hours / maxHours).clamp(0.0, 1.0);
        final isGood = d.hours >= 7;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  d.hours == 0 ? '0' : d.hours.toStringAsFixed(1),
                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: heightFactor,
                      child: Container(
                        width: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isGood
                                ? [kAccentBlue, kBrand]
                                : [const Color(0xFF334155), const Color(0xFF7C3AED)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isGood ? kAccentBlue : kBrand)
                                  .withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('E').format(d.date).substring(0, 1),
                  style: const TextStyle(color: kTextSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<_DayHours> days;

  const _LineChart({required this.days});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(days: days),
      child: Container(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_DayHours> days;

  _LineChartPainter({required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (days.isEmpty) return;

    final maxHours = math.max(
      8.0,
      days.fold<double>(0, (max, d) => d.hours > max ? d.hours : max),
    );

    final points = <Offset>[];
    for (int i = 0; i < days.length; i++) {
      final x = days.length == 1 ? size.width / 2 : i * size.width / (days.length - 1);
      final y = size.height - ((days[i].hours / maxHours) * (size.height - 16)) - 8;
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          kAccentBlue.withValues(alpha: 0.22),
          kBrand.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final controlX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
    }

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [kAccentBlue, kBrand],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = Colors.white;
    final dotGlow = Paint()
      ..color = kAccentBlue.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final p in points) {
      canvas.drawCircle(p, 6, dotGlow);
      canvas.drawCircle(p, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.days != days;
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InsightChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: kTextMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _LegendItem(color: Color(0xFF243041), label: '0h'),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFF1D4ED8), label: 'Low'),
        SizedBox(width: 12),
        _LegendItem(color: Color(0xFF8B5CF6), label: 'High'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

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
          style: const TextStyle(
            color: kTextSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}