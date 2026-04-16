import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';

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

  double _avg7 = 0.0;
  double _avg30 = 0.0;
  int _trackedDays30 = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _openRecommendation(_Recommendation rec) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RecommendationSheet(rec: rec),
  );
}

  Future<void> _loadData() async {
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

    _sessions.clear();

    for (final doc in snap.docs) {
      final data = doc.data();
      final start = (data['start'] as Timestamp?)?.toDate();
      final end = (data['end'] as Timestamp?)?.toDate();

      if (start == null || end == null || !end.isAfter(start)) continue;

      final durationHours =
          (data['durationHours'] as num?)?.toDouble() ??
          end.difference(start).inMinutes / 60.0;

      final source = (data['source'] ?? 'manual').toString();

      _sessions.add(
        _SleepRecord(
          start: start,
          end: end,
          durationHours: durationHours,
          source: source,
        ),
      );
    }

    _computeStats();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _computeStats() {
    final now = DateTime.now();
    final dailyMap = <String, double>{};

    for (final s in _sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.start);
      dailyMap[key] = (dailyMap[key] ?? 0) + s.durationHours;
    }

    double total7 = 0;
    double total30 = 0;
    int count7 = 0;
    int count30 = 0;
    final tracked = <String>{};

    dailyMap.forEach((key, hours) {
      final date = DateTime.parse(key);
      final diff = now.difference(date).inDays;

      if (diff >= 0 && diff <= 6) {
        total7 += hours;
        count7++;
      }

      if (diff >= 0 && diff <= 29) {
        total30 += hours;
        count30++;
        if (hours > 0) tracked.add(key);
      }
    });

    _avg7 = count7 == 0 ? 0 : total7 / count7;
    _avg30 = count30 == 0 ? 0 : total30 / count30;
    _trackedDays30 = tracked.length;
  }

  List<_InsightItem> _mainInsights() {
    final items = <_InsightItem>[];

    if (_sessions.isEmpty) {
      return [
        _InsightItem(
          icon: Icons.auto_awesome_rounded,
          title: 'No insights yet',
          body:
              'Track a few nights of sleep and SleepWell will start detecting patterns and giving personalized feedback.',
          color: kBrand,
        ),
      ];
    }

    if (_avg7 < 6) {
      items.add(
        _InsightItem(
          icon: Icons.bedtime_rounded,
          title: 'Sleep duration is low',
          body:
              'Your recent average is well below the recommended range. Sleeping longer is the single biggest improvement area right now.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else if (_avg7 < 7) {
      items.add(
        _InsightItem(
          icon: Icons.hotel_rounded,
          title: 'You are close, but still short',
          body:
              'Your recent sleep is slightly below target. Even an extra 30 to 60 minutes could improve your weekly average noticeably.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else if (_avg7 <= 8.5) {
      items.add(
        _InsightItem(
          icon: Icons.check_circle_rounded,
          title: 'You are in a healthy range',
          body:
              'Your recent average is in a strong zone. The next goal is keeping that pattern consistent across the week.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else {
      items.add(
        _InsightItem(
          icon: Icons.nights_stay_rounded,
          title: 'Sleep is longer than usual',
          body:
              'Your recent sleep is on the longer side. This may reflect recovery, fatigue, or inconsistent sleep timing.',
          color: kAccentBlue,
        ),
      );
    }

    final diff = _avg7 - _avg30;
    if (diff >= 0.7) {
      items.add(
        _InsightItem(
          icon: Icons.trending_up_rounded,
          title: 'Recent trend is improving',
          body:
              'Your last 7 days are clearly better than your monthly baseline. That suggests recent progress.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else if (diff <= -0.7) {
      items.add(
        _InsightItem(
          icon: Icons.trending_down_rounded,
          title: 'Recent trend has dropped',
          body:
              'Your recent week is below your normal monthly level. Something in the last few days may be hurting your routine.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else {
      items.add(
        _InsightItem(
          icon: Icons.insights_rounded,
          title: 'Trend is relatively stable',
          body:
              'Your recent sleep is broadly in line with your longer-term average.',
          color: kAccentBlue,
        ),
      );
    }

    final weekdayAvg = _weekdayAverage();
    final weekendAvg = _weekendAverage();

    if (weekdayAvg > 0 && weekendAvg > 0) {
      final weekendDiff = weekendAvg - weekdayAvg;

      if (weekendDiff >= 1.0) {
        items.add(
          _InsightItem(
            icon: Icons.weekend_rounded,
            title: 'Weekend catch-up pattern detected',
            body:
                'You sleep noticeably longer on weekends than weekdays, which can signal weekday sleep debt.',
            color: kBrand,
          ),
        );
      } else if (weekendDiff <= -0.7) {
        items.add(
          _InsightItem(
            icon: Icons.schedule_rounded,
            title: 'Weekend pattern looks unusual',
            body:
                'Your weekends are shorter than your weekdays, which may reflect schedule disruption.',
            color: const Color(0xFFF59E0B),
          ),
        );
      } else {
        items.add(
          _InsightItem(
            icon: Icons.balance_rounded,
            title: 'Week pattern is fairly balanced',
            body:
                'Your weekday and weekend sleep are fairly close, which points to a steadier routine.',
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
              'You do not have many tracked nights yet. More consistent logging will make these insights much stronger.',
          color: kBrand,
        ),
      );
    }

    return items.take(4).toList();
  }

  List<_QuickMetric> _quickMetrics() {
    return [
      _QuickMetric(
        label: 'Avg 7 days',
        value: '${_avg7.toStringAsFixed(1)} h',
        color: kAccentBlue,
        icon: Icons.bedtime_rounded,
      ),
      _QuickMetric(
        label: 'Avg 30 days',
        value: '${_avg30.toStringAsFixed(1)} h',
        color: kBrand,
        icon: Icons.calendar_month_rounded,
      ),
      _QuickMetric(
        label: 'Tracked days',
        value: '$_trackedDays30 / 30',
        color: const Color(0xFF22C55E),
        icon: Icons.checklist_rounded,
      ),
    ];
  }

  List<_Recommendation> _recommendations() {
    final items = <_Recommendation>[];

    if (_avg7 < 7) {
      items.add(
        _Recommendation(
          title: 'Aim for more sleep time',
          body: 'Try increasing total sleep by 30–60 minutes this week.',
          color: const Color(0xFFF59E0B),
          icon: Icons.hotel_rounded,
        ),
      );
    }

    if (_trackedDays30 < 20) {
      items.add(
        _Recommendation(
          title: 'Track more nights',
          body: 'More recorded sleep will unlock stronger patterns and smarter feedback.',
          color: kBrand,
          icon: Icons.edit_note_rounded,
        ),
      );
    }

    final weekdayAvg = _weekdayAverage();
    final weekendAvg = _weekendAverage();

    if (weekdayAvg > 0 && weekendAvg > 0 && (weekendAvg - weekdayAvg) >= 1.0) {
      items.add(
        _Recommendation(
          title: 'Reduce weekday sleep debt',
          body: 'Try making weekday sleep more consistent so weekends are less compensatory.',
          color: kAccentBlue,
          icon: Icons.weekend_rounded,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _Recommendation(
          title: 'Maintain your current routine',
          body: 'Your recent pattern looks stable. Keep tracking and preserve consistency.',
          color: const Color(0xFF22C55E),
          icon: Icons.favorite_rounded,
        ),
      );
    }

    return items.take(3).toList();
  }

  double _weekdayAverage() {
    final days = _sessions
        .where(
          (s) =>
              s.start.weekday >= DateTime.monday &&
              s.start.weekday <= DateTime.friday,
        )
        .toList();

    if (days.isEmpty) return 0.0;
    return days.fold(0.0, (sum, s) => sum + s.durationHours) / days.length;
  }

  double _weekendAverage() {
    final days = _sessions
        .where(
          (s) =>
              s.start.weekday == DateTime.saturday ||
              s.start.weekday == DateTime.sunday,
        )
        .toList();

    if (days.isEmpty) return 0.0;
    return days.fold(0.0, (sum, s) => sum + s.durationHours) / days.length;
  }

  List<_SleepRecord> _recentSessions() {
    final copy = [..._sessions];
    copy.sort((a, b) => b.start.compareTo(a.start));
    return copy.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final insights = _mainInsights();
    final metrics = _quickMetrics();
    final recs = _recommendations();
    final recent = _recentSessions();
    final isWide = MediaQuery.of(context).size.width >= 900;

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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      _buildHero(insights.isNotEmpty ? insights.first : null),
                      const SizedBox(height: 18),
                      _buildMetricsRow(metrics, isWide),
                      const SizedBox(height: 22),
                      const Text(
                        'What matters most',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (insights.isNotEmpty) _buildFocusCard(insights.first),
                      const SizedBox(height: 12),
                      ...insights.skip(1).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildSupportInsight(item),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Recommended next steps',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(recs.length, (i) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: i == recs.length - 1 ? 0 : 12,
                                ),
                                child: _buildRecommendationCard(recs[i]),
                              ),
                            );
                          }),
                        )
                      else
                        Column(
                          children: recs
                              .map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildRecommendationCard(r),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 22),
                      const Text(
                        'Recent nights',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentSessionsStrip(recent),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHero(_InsightItem? focus) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (focus?.color ?? kBrand).withValues(alpha: 0.95),
                  (focus?.color ?? kBrand).withValues(alpha: 0.55),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (focus?.color ?? kBrand).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              focus?.icon ?? Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  focus?.title ?? 'Sleep patterns and recommendations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  focus?.body ??
                      'SleepWell highlights what matters most in your recent sleep behavior.',
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

  Widget _buildMetricsRow(List<_QuickMetric> metrics, bool isWide) {
    if (isWide) {
      return Row(
        children: List.generate(metrics.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == metrics.length - 1 ? 0 : 12),
              child: _buildMetricCard(metrics[i]),
            ),
          );
        }),
      );
    }

    return Column(
      children: metrics
          .map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMetricCard(m),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMetricCard(_QuickMetric metric) {
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCard(_InsightItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [item.color, item.color.withValues(alpha: 0.6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: item.color.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
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
              border: Border.all(color: item.color.withValues(alpha: 0.24)),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rec.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(rec.icon, color: rec.color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            rec.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.body,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRecentSessionsStrip(List<_SleepRecord> sessions) {
    if (sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration,
        child: const Text(
          'No recorded sleep yet.',
          style: TextStyle(color: kTextSecondary),
        ),
      );
    }

    return Column(
      children: sessions.map((s) {
        final qualityColor = s.durationHours >= 7
            ? const Color(0xFF22C55E)
            : s.durationHours >= 6
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF97316);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: glassCardDecoration,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 42,
                  decoration: BoxDecoration(
                    color: qualityColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, MMM d').format(s.start),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('HH:mm').format(s.start)} - ${DateFormat('HH:mm').format(s.end)}',
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: (s.source == 'health_connect'
                            ? const Color(0xFF22C55E)
                            : kAccentBlue)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    s.source == 'health_connect' ? 'Watch' : 'Manual',
                    style: TextStyle(
                      color: s.source == 'health_connect'
                          ? const Color(0xFF22C55E)
                          : kAccentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${s.durationHours.toStringAsFixed(1)} h',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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

class _QuickMetric {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _QuickMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
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

class _RecommendationSheet extends StatelessWidget {
  final _Recommendation rec;

  const _RecommendationSheet({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF120018),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rec.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(rec.icon, color: rec.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rec.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
            "What you can do",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
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
    if (rec.title.contains("sleep time")) {
      return "Sleeping less than your body needs affects recovery, focus, and long-term health. Even small increases in duration can significantly improve how you feel.";
    }

    if (rec.title.contains("Track more")) {
      return "SleepWell relies on data to detect patterns. The more nights you track, the more accurate and personalized your insights become.";
    }

    if (rec.title.contains("weekday sleep debt")) {
      return "Large differences between weekday and weekend sleep often indicate accumulated fatigue. This can disrupt your natural rhythm.";
    }

    return "Improving this area can help stabilize your sleep patterns and improve overall sleep quality.";
  }

  List<String> _actions(_Recommendation rec) {
    if (rec.title.contains("sleep time")) {
      return [
        "Go to bed 30 minutes earlier",
        "Avoid screens before sleep",
        "Keep a consistent wake time",
      ];
    }

    if (rec.title.contains("Track more")) {
      return [
        "Log sleep every morning",
        "Use smartwatch import if available",
        "Avoid skipping nights",
      ];
    }

    if (rec.title.contains("weekday sleep debt")) {
      return [
        "Try to match weekend and weekday sleep",
        "Avoid late-night shifts on weekdays",
        "Keep bedtime consistent",
      ];
    }

    return [
      "Maintain a consistent routine",
      "Track your sleep regularly",
      "Monitor changes over time",
    ];
  }
}