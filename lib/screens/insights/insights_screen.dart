import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
import '../assessment/assessment_hub_screen.dart';
import '../coach/sleep_coach_screen.dart';
import 'dart:ui' as ui;

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  final List<_SleepRecord> _sessions = [];

  double _avg7 = 0;
  double _avg30 = 0;
  int _trackedDays30 = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (_user == null) {
        debugPrint('Insights: no signed-in user');
        return;
      }

      final snap = await _firestore
          .collection('users')
          .doc(_user.uid)
          .collection('sleep_records')
          .limit(120)
          .get()
          .timeout(const Duration(seconds: 8));

      _sessions.clear();

      for (final doc in snap.docs) {
        final data = doc.data();

        final start = (data['start'] as Timestamp?)?.toDate();
        final end = (data['end'] as Timestamp?)?.toDate();

        if (start == null || end == null || !end.isAfter(start)) continue;

        final hours =
            (data['durationHours'] as num?)?.toDouble() ??
            end.difference(start).inMinutes / 60.0;

        _sessions.add(
          _SleepRecord(
            start: start,
            end: end,
            durationHours: hours,
            source: (data['source'] ?? 'manual').toString(),
          ),
        );
      }

      _sessions.sort((a, b) => b.start.compareTo(a.start));
      _computeStats();
    } catch (e) {
      debugPrint('Insights load failed: $e');
      _sessions.clear();
      _avg7 = 0;
      _avg30 = 0;
      _trackedDays30 = 0;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _computeStats() {
    final now = DateTime.now();
    final daily = _dailyTotals();

    double total7 = 0;
    double total30 = 0;
    int count7 = 0;
    int count30 = 0;

    daily.forEach((key, hours) {
      final date = DateTime.parse(key);
      final diff = now.difference(date).inDays;

      if (diff >= 0 && diff <= 6) {
        total7 += hours;
        count7++;
      }

      if (diff >= 0 && diff <= 29) {
        total30 += hours;
        count30++;
      }
    });

    _avg7 = count7 == 0 ? 0 : total7 / count7;
    _avg30 = count30 == 0 ? 0 : total30 / count30;
    _trackedDays30 = count30;
  }

  Map<String, double> _dailyTotals() {
    final map = <String, double>{};

    for (final s in _sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.start);
      map[key] = (map[key] ?? 0) + s.durationHours;
    }

    return map;
  }

  List<_SleepDay> _lastNDays(int n) {
    final daily = _dailyTotals();
    final today = DateTime.now();

    return List.generate(n, (i) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: n - 1 - i));
      final key = DateFormat('yyyy-MM-dd').format(date);

      return _SleepDay(date: date, hours: daily[key] ?? 0);
    });
  }

  double _weekdayAverage() {
    final days = _sessions
        .where(
          (s) =>
              s.start.weekday >= DateTime.monday &&
              s.start.weekday <= DateTime.friday,
        )
        .toList();

    if (days.isEmpty) return 0;
    return days.fold(0.0, (total, s) => total + s.durationHours) / days.length;
  }

  double _weekendAverage() {
    final days = _sessions
        .where(
          (s) =>
              s.start.weekday == DateTime.saturday ||
              s.start.weekday == DateTime.sunday,
        )
        .toList();

    if (days.isEmpty) return 0;
    return days.fold(0.0, (total, s) => total + s.durationHours) / days.length;
  }

  String _scoreLabel() {
    if (_sessions.isEmpty) return 'Building profile';
    if (_avg7 >= 7 && _avg7 <= 8.5 && _trackedDays30 >= 20) {
      return 'Strong rhythm';
    }
    if (_avg7 < 6) return 'Needs recovery';
    if (_avg7 < 7) return 'Almost there';
    if (_avg7 > 8.8) return 'Long sleep phase';
    return 'Stable pattern';
  }

  Color _scoreColor() {
    if (_avg7 >= 7 && _avg7 <= 8.5) return const Color(0xFF22C55E);
    if (_avg7 < 6) return const Color(0xFFF97316);
    return const Color(0xFFF59E0B);
  }

  List<_InsightItem> _mainInsights() {
    if (_sessions.isEmpty) {
      return [
        _InsightItem(
          icon: Icons.auto_awesome_rounded,
          title: 'No insights yet',
          body:
              'Track a few nights and SleepWell will start detecting your sleep rhythm, weak spots, and progress.',
          color: kBrand,
        ),
      ];
    }

    final items = <_InsightItem>[];

    if (_avg7 < 6) {
      items.add(
        _InsightItem(
          icon: Icons.bedtime_off_rounded,
          title: 'Your recent sleep is too low',
          body:
              'Your 7-day average is below the common adult sleep range. The main improvement is simple: protect more total sleep time.',
          color: const Color(0xFFF97316),
        ),
      );
    } else if (_avg7 < 7) {
      items.add(
        _InsightItem(
          icon: Icons.hotel_rounded,
          title: 'Close, but still short',
          body:
              'You are near the target zone. Adding 30–60 minutes per night would noticeably improve your weekly average.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else if (_avg7 <= 8.5) {
      items.add(
        _InsightItem(
          icon: Icons.check_circle_rounded,
          title: 'Healthy sleep range',
          body:
              'Your recent average sits in a strong range. Your next goal is consistency, not just duration.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else {
      items.add(
        _InsightItem(
          icon: Icons.nights_stay_rounded,
          title: 'Longer sleep pattern',
          body:
              'Your recent sleep is on the longer side. This may reflect recovery, fatigue, or irregular timing.',
          color: kAccentBlue,
        ),
      );
    }

    final diff = _avg7 - _avg30;

    if (diff >= 0.7) {
      items.add(
        _InsightItem(
          icon: Icons.trending_up_rounded,
          title: 'Your recent trend is improving',
          body:
              'The last 7 days are higher than your 30-day baseline, which suggests recent progress.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else if (diff <= -0.7) {
      items.add(
        _InsightItem(
          icon: Icons.trending_down_rounded,
          title: 'Your recent trend dropped',
          body:
              'The last 7 days are below your monthly baseline. Something recent may be disrupting your routine.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else {
      items.add(
        _InsightItem(
          icon: Icons.show_chart_rounded,
          title: 'Trend is stable',
          body:
              'Your weekly average is close to your monthly baseline, meaning your pattern is not changing sharply.',
          color: kAccentBlue,
        ),
      );
    }

    final weekday = _weekdayAverage();
    final weekend = _weekendAverage();

    if (weekday > 0 && weekend > 0) {
      final gap = weekend - weekday;

      if (gap >= 1.0) {
        items.add(
          _InsightItem(
            icon: Icons.weekend_rounded,
            title: 'Weekend catch-up detected',
            body:
                'You sleep noticeably longer on weekends. This often means weekdays are creating sleep debt.',
            color: kBrand,
          ),
        );
      } else if (gap <= -0.7) {
        items.add(
          _InsightItem(
            icon: Icons.schedule_rounded,
            title: 'Weekend rhythm looks disrupted',
            body:
                'Your weekends are shorter than weekdays, which may point to schedule changes or late nights.',
            color: const Color(0xFFF59E0B),
          ),
        );
      } else {
        items.add(
          _InsightItem(
            icon: Icons.balance_rounded,
            title: 'Week rhythm is balanced',
            body:
                'Weekday and weekend sleep are close, which is a good sign for routine stability.',
            color: const Color(0xFF22C55E),
          ),
        );
      }
    }

    if (_trackedDays30 < 12) {
      items.add(
        _InsightItem(
          icon: Icons.edit_calendar_rounded,
          title: 'Tracking is still sparse',
          body:
              'More tracked nights will make the charts and recommendations much smarter.',
          color: kBrand,
        ),
      );
    }

    return items.take(4).toList();
  }

  List<_Recommendation> _recommendations() {
    final items = <_Recommendation>[];

    if (_avg7 < 7) {
      items.add(
        _Recommendation(
          title: 'Increase total sleep',
          body: 'Try adding 30–60 minutes to your sleep window this week.',
          color: const Color(0xFFF59E0B),
          icon: Icons.hotel_rounded,
        ),
      );
    }

    if (_trackedDays30 < 20) {
      items.add(
        _Recommendation(
          title: 'Track more nights',
          body: 'Consistent logging unlocks stronger pattern detection.',
          color: kBrand,
          icon: Icons.edit_note_rounded,
        ),
      );
    }

    final weekday = _weekdayAverage();
    final weekend = _weekendAverage();

    if (weekday > 0 && weekend > 0 && weekend - weekday >= 1) {
      items.add(
        _Recommendation(
          title: 'Reduce weekday sleep debt',
          body: 'Make weekdays closer to weekends so recovery is less extreme.',
          color: kAccentBlue,
          icon: Icons.weekend_rounded,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _Recommendation(
          title: 'Maintain your rhythm',
          body: 'Your recent pattern looks good. Preserve consistency.',
          color: const Color(0xFF22C55E),
          icon: Icons.favorite_rounded,
        ),
      );
    }

    return items.take(3).toList();
  }

  void _openRecommendation(_Recommendation rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RecommendationSheet(rec: rec),
    );
  }

  Widget _buildAssessmentEntry(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentHubScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: kBrand.withValues(alpha: 0.16),
              ),
              child: const Icon(Icons.quiz_rounded, color: kBrand, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sleep Assessments',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Check sleep quality, fatigue, and insomnia patterns.',
                    style: TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachEntry(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SleepCoachScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: kAccentBlue.withValues(alpha: 0.16),
                border: Border.all(color: kAccentBlue.withValues(alpha: 0.22)),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: kAccentBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sleep Coach',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Learn schedule, environment, stages, habits, and recovery basics.',
                    style: TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final insights = _mainInsights();
    final recs = _recommendations();

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.insights),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrand))
              : RefreshIndicator(
                  color: kBrand,
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _buildHero(insights.first),

                      const SizedBox(height: 18),

                      _buildAssessmentEntry(context),

                      const SizedBox(height: 18),

                      _buildCoachEntry(context),

                      const SizedBox(height: 18),

                      _buildMetrics(isWide),

                      const SizedBox(height: 22),

                      _sectionTitle('Sleep patterns'),
                      const SizedBox(height: 12),
                      _buildChartsSection(isWide),

                      const SizedBox(height: 22),

                      _sectionTitle('Key signals'),
                      const SizedBox(height: 12),
                      ...insights
                          .skip(1)
                          .map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildSupportInsight(i),
                            ),
                          ),

                      const SizedBox(height: 22),

                      _sectionTitle('Recommended next steps'),
                      const SizedBox(height: 12),
                      _buildRecommendations(recs, isWide),

                      const SizedBox(height: 22),
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
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildHero(_InsightItem focus) {
    final color = _scoreColor();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          _SleepRing(
            progress: (_avg7 / 8).clamp(0.0, 1.15),
            color: color,
            center: _avg7 == 0 ? '--' : _avg7.toStringAsFixed(1),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _scoreLabel(),
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  focus.body,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
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

  Widget _buildMetrics(bool isWide) {
    final metrics = [
      _Metric(
        'Avg 7 days',
        '${_avg7.toStringAsFixed(1)} h',
        Icons.bedtime_rounded,
        kAccentBlue,
      ),
      _Metric(
        'Avg 30 days',
        '${_avg30.toStringAsFixed(1)} h',
        Icons.calendar_month_rounded,
        kBrand,
      ),
      _Metric(
        'Tracked',
        '$_trackedDays30 / 30',
        Icons.checklist_rounded,
        const Color(0xFF22C55E),
      ),
    ];

    if (isWide) {
      return Row(
        children: List.generate(
          metrics.length,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == metrics.length - 1 ? 0 : 12),
              child: _metricCard(metrics[i]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: metrics
          .map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _metricCard(m),
            ),
          )
          .toList(),
    );
  }

  Widget _metricCard(_Metric metric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isWide) {
    final last7 = _lastNDays(7);
    final trend14 = _lastNDays(14);
    final heatmap = _lastNDays(28);

    final trendCard = _chartCard(
      title: '14-day trend',
      subtitle: 'Your sleep direction over time',
      child: _LineChart(days: trend14, goal: 7.5),
    );

    final barCard = _chartCard(
      title: 'Last 7 nights',
      subtitle: 'Night-by-night duration',
      child: _BarChart(days: last7),
    );

    final heatCard = _chartCard(
      title: '28-day consistency',
      subtitle: 'Darker means closer to target',
      child: _HeatMap(days: heatmap),
    );

    final bestWorst = _BestWorstCard(days: _lastNDays(30));

    if (isWide) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: trendCard),
              const SizedBox(width: 12),
              Expanded(child: barCard),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heatCard),
              const SizedBox(width: 12),
              Expanded(child: bestWorst),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        trendCard,
        const SizedBox(height: 12),
        barCard,
        const SizedBox(height: 12),
        heatCard,
        const SizedBox(height: 12),
        bestWorst,
      ],
    );
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 190, child: child),
        ],
      ),
    );
  }

  Widget _buildSupportInsight(_InsightItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<_Recommendation> recs, bool isWide) {
    if (isWide) {
      return Row(
        children: List.generate(
          recs.length,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == recs.length - 1 ? 0 : 12),
              child: _buildRecommendationCard(recs[i]),
            ),
          ),
        ),
      );
    }

    return Column(
      children: recs
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRecommendationCard(r),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecommendationCard(_Recommendation rec) {
    return GestureDetector(
      onTap: () => _openRecommendation(rec),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(rec.icon, color: rec.color, size: 28),
            const SizedBox(height: 14),
            Text(
              rec.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rec.body,
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepRing extends StatelessWidget {
  final double progress;
  final Color color;
  final String center;

  const _SleepRing({
    required this.progress,
    required this.color,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Text(
            center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = 9.0;

    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..shader = SweepGradient(
        colors: [color, color.withValues(alpha: 0.35), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect.deflate(stroke), -math.pi / 2, math.pi * 2, false, bg);

    canvas.drawArc(
      rect.deflate(stroke),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _LineChart extends StatelessWidget {
  final List<_SleepDay> days;
  final double goal;

  const _LineChart({required this.days, required this.goal});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(days: days, goal: goal),
      size: Size.infinite,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_SleepDay> days;
  final double goal;

  _LineChartPainter({required this.days, required this.goal});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const bottom = 28.0;
    const top = 14.0;
    const right = 8.0;

    final chartW = size.width - left - right;
    final chartH = size.height - top - bottom;
    final maxY = 10.0;

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (final h in [4, 6, 8]) {
      final y = top + chartH - (h / maxY) * chartH;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);

      textPainter.text = TextSpan(
        text: '${h}h',
        style: const TextStyle(color: kTextMuted, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 7));
    }

    final goalY = top + chartH - (goal / maxY) * chartH;
    final goalPaint = Paint()
      ..color = kBrand.withValues(alpha: 0.45)
      ..strokeWidth = 1.4;

    canvas.drawLine(
      Offset(left, goalY),
      Offset(size.width - right, goalY),
      goalPaint,
    );

    if (days.isEmpty) return;

    final points = <Offset>[];

    for (int i = 0; i < days.length; i++) {
      final x = left + (days.length == 1 ? 0 : i / (days.length - 1)) * chartW;
      final y = top + chartH - (days[i].hours.clamp(0, maxY) / maxY) * chartH;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, top + chartH)
      ..lineTo(points.first.dx, top + chartH)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kAccentBlue.withValues(alpha: 0.22),
            kAccentBlue.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(left, top, chartW, chartH)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = kAccentBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    for (final p in points) {
      canvas.drawCircle(p, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(p, 2.4, Paint()..color = kAccentBlue);
    }

    for (int i = 0; i < days.length; i += 3) {
      textPainter.text = TextSpan(
        text: DateFormat('E').format(days[i].date),
        style: const TextStyle(color: kTextMuted, fontSize: 10),
      );
      textPainter.layout();
      final x = left + (i / (days.length - 1)) * chartW;
      textPainter.paint(canvas, Offset(x - 8, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

class _BarChart extends StatelessWidget {
  final List<_SleepDay> days;

  const _BarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(days: days),
      size: Size.infinite,
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_SleepDay> days;

  _BarChartPainter({required this.days});

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 24.0;
    const top = 12.0;
    final chartH = size.height - top - bottom;
    final barW = size.width / (days.length * 1.8);

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final x = (i + 0.45) * (size.width / days.length);
      final h = (d.hours.clamp(0, 10) / 10) * chartH;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top + chartH - h, barW, h),
        const Radius.circular(999),
      );

      final color = d.hours >= 7
          ? const Color(0xFF22C55E)
          : d.hours >= 6
          ? const Color(0xFFF59E0B)
          : d.hours == 0
          ? Colors.white24
          : const Color(0xFFF97316);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, barW, chartH),
          const Radius.circular(999),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withValues(alpha: 0.35)],
          ).createShader(rect.outerRect),
      );

      textPainter.text = TextSpan(
        text: DateFormat('E').format(d.date).substring(0, 1),
        style: const TextStyle(color: kTextMuted, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + barW / 2 - 4, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

class _HeatMap extends StatelessWidget {
  final List<_SleepDay> days;

  const _HeatMap({required this.days});

  @override
  Widget build(BuildContext context) {
    final shownDays = days.take(28).toList();

    return LayoutBuilder(
      builder: (_, constraints) {
        const columns = 7;
        const rows = 4;
        const gap = 8.0;

        final cellW = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final cellH = (constraints.maxHeight - (rows - 1) * gap) / rows;
        final cell = math.min(cellW, cellH);

        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: shownDays.map((d) {
              final color = d.hours == 0
                  ? Colors.white.withValues(alpha: 0.08)
                  : d.hours >= 7 && d.hours <= 8.5
                  ? const Color(0xFF22C55E)
                  : d.hours >= 6
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFF97316);

              return Container(
                width: cell,
                height: cell,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _BestWorstCard extends StatelessWidget {
  final List<_SleepDay> days;

  const _BestWorstCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final valid = days.where((d) => d.hours > 0).toList();

    if (valid.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration,
        child: const Text(
          'Best and worst nights will appear after more tracking.',
          style: TextStyle(color: kTextSecondary),
        ),
      );
    }

    double distanceFromTarget(_SleepDay d) {
      const target = 7.5;
      return (d.hours - target).abs();
    }

    valid.sort((a, b) {
      final aDistance = distanceFromTarget(a);
      final bDistance = distanceFromTarget(b);
      return aDistance.compareTo(bDistance);
    });

    final best = valid.first;
    final worst = valid.last;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Best / worst nights',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Closest and farthest from your sleep target',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _row(
            'Best',
            best,
            const Color(0xFF22C55E),
            Icons.emoji_events_rounded,
          ),
          const SizedBox(height: 12),
          _row(
            'Lowest',
            worst,
            const Color(0xFFF97316),
            Icons.warning_amber_rounded,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, _SleepDay day, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label · ${DateFormat('MMM d').format(day.date)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${day.hours.toStringAsFixed(1)} h',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RecommendationSheet extends StatelessWidget {
  final _Recommendation rec;

  const _RecommendationSheet({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF120018),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(rec.icon, color: rec.color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rec.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _explanation(rec),
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'What you can do',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ..._actions(rec).map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.white38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _explanation(_Recommendation rec) {
    if (rec.title.contains('Increase')) {
      return 'Sleep duration is one of the strongest levers in your current profile. A small increase repeated over several nights can improve the weekly average quickly.';
    }

    if (rec.title.contains('Track')) {
      return 'SleepWell becomes more useful when it sees enough nights. More data means better trends, stronger averages, and more accurate recommendations.';
    }

    if (rec.title.contains('weekday')) {
      return 'A large weekday/weekend gap often means you are recovering on weekends instead of sleeping enough during the week.';
    }

    return 'Your sleep rhythm looks stable. The goal now is preserving the routine and watching for changes.';
  }

  List<String> _actions(_Recommendation rec) {
    if (rec.title.contains('Increase')) {
      return [
        'Move bedtime 30 minutes earlier',
        'Avoid screens close to sleep',
        'Keep wake time consistent',
      ];
    }

    if (rec.title.contains('Track')) {
      return [
        'Log sleep every morning',
        'Use smartwatch import when available',
        'Avoid skipping nights',
      ];
    }

    if (rec.title.contains('weekday')) {
      return [
        'Bring weekday sleep closer to weekend sleep',
        'Avoid late weekday shifts',
        'Protect a fixed wind-down time',
      ];
    }

    return [
      'Keep your bedtime stable',
      'Continue tracking',
      'Watch for sudden drops',
    ];
  }
}

class _SleepRecord {
  final DateTime start;
  final DateTime end;
  final double durationHours;
  final String source;

  const _SleepRecord({
    required this.start,
    required this.end,
    required this.durationHours,
    required this.source,
  });
}

class _SleepDay {
  final DateTime date;
  final double hours;

  const _SleepDay({required this.date, required this.hours});
}

class _InsightItem {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _InsightItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _Recommendation {
  final String title;
  final String body;
  final Color color;
  final IconData icon;

  const _Recommendation({
    required this.title,
    required this.body,
    required this.color,
    required this.icon,
  });
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Metric(this.label, this.value, this.icon, this.color);
}
