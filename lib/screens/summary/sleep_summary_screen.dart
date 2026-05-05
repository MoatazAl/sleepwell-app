import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
import '../history/sleep_history_screen.dart';
import '../../services/health_connect/health_connect_service.dart';
import '../../services/health_connect/health_connect_importer.dart';
import '../insights/sleep_stage_detail_screen.dart';

class SleepSummaryScreen extends StatefulWidget {
  const SleepSummaryScreen({super.key});

  @override
  State<SleepSummaryScreen> createState() => _SleepSummaryScreenState();
}

class _SleepSummaryScreenState extends State<SleepSummaryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  bool _hcBusy = false;
  bool _hcAvailable = false;
  bool _hcPermissionGranted = false;

  final Map<String, double> _dailyTotals = {};
  final List<_SleepRecord> _sessions = [];

  double _avg7 = 0.0;
  double _avg30 = 0.0;
  int _daysWithSleep30 = 0;

  double _sleepGoalHours = 8.0;
  String _scheduleType = 'regular_daytime';

  late final List<DateTime> _heatmapDays = List.generate(
    28,
    (i) => DateTime.now().subtract(Duration(days: 27 - i)),
  );

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadProfilePreferences();
    await _loadAnalytics();
    await _initHealthConnect();
  }

  void _openSleepStageDetails({
    required String stageKey,
    required String stageLabel,
    required Color stageColor,
    required double minutes,
    required Map<String, double> totals,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SleepStageDetailScreen(
          stageKey: stageKey,
          stageLabel: stageLabel,
          stageColor: stageColor,
          minutes: minutes,
          totals: totals,
        ),
      ),
    );
  }

  Widget _buildSleepStagesCard(List<_SleepStage> stages) {
    final totals = _stageTotals(stages);
    final totalMinutes = totals.values.fold<double>(
      0.0,
      (total, value) => total + value,
    );

    if (totalMinutes <= 0) return const SizedBox.shrink();

    final orderedStages = [
      ('awake', const Color(0xFFF59E0B), 'Awake'),
      ('light', const Color(0xFF60A5FA), 'Light'),
      ('deep', const Color(0xFF4338CA), 'Deep'),
      ('rem', const Color(0xFF8B5CF6), 'REM'),
      ('sleeping', const Color(0xFF7C3AED), 'Sleep'),
    ];

    final visible = orderedStages
        .where((item) => (totals[item.$1] ?? 0.0) > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sleep Stages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 14,
            child: Row(
              children: visible.map((item) {
                final key = item.$1;
                final color = item.$2;
                final label = item.$3;
                final minutes = totals[key] ?? 0.0;
                final fraction = minutes / totalMinutes;

                return Expanded(
                  flex: (fraction * 1000).round().clamp(1, 1000),
                  child: InkWell(
                    onTap: () => _openSleepStageDetails(
                      stageKey: key,
                      stageLabel: label,
                      stageColor: color,
                      minutes: minutes,
                      totals: totals,
                    ),
                    child: Container(color: color),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: visible.map((item) {
            final key = item.$1;
            final color = item.$2;
            final label = item.$3;
            final minutes = totals[key] ?? 0.0;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _openSleepStageDetails(
                  stageKey: key,
                  stageLabel: label,
                  stageColor: color,
                  minutes: minutes,
                  totals: totals,
                ),
                child: _stageLegendChip(
                  color: color,
                  label: label,
                  minutes: minutes,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTrendCard() {
    final trend = _lastNDays(14);

    return _glassCard(
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
            height: 210,
            child: _LineChart(days: trend, goal: _sleepGoalHours),
          ),
        ],
      ),
    );
  }

  Map<String, double> _stageTotals(List<_SleepStage> stages) {
    final totals = <String, double>{};

    for (final stage in stages) {
      final key = stage.stage.toLowerCase();
      totals[key] = (totals[key] ?? 0.0) + stage.minutes;
    }

    return totals;
  }

  Widget _stageLegendChip({
    required Color color,
    required String label,
    required double minutes,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ${_formatStageMinutes(minutes)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatStageMinutes(double minutes) {
    final total = minutes.round();
    final h = total ~/ 60;
    final m = total % 60;

    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Future<void> _initHealthConnect() async {
    try {
      final availability = await HealthConnectService.getAvailability();
      _hcAvailable = availability.available;

      if (_hcAvailable) {
        _hcPermissionGranted = await HealthConnectService.hasSleepPermission();
      } else {
        _hcPermissionGranted = false;
      }

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadProfilePreferences() async {
    if (_user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(_user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      _sleepGoalHours = ((data['sleepGoalHours'] as num?)?.toDouble() ?? 8.0)
          .clamp(4.0, 12.0);

      _scheduleType = (data['scheduleType'] ?? 'regular_daytime').toString();
    } catch (_) {
      _sleepGoalHours = 8.0;
      _scheduleType = 'regular_daytime';
    }
  }

  Future<void> _handleHealthConnect() async {
    setState(() => _hcBusy = true);

    try {
      if (!_hcAvailable) {
        await HealthConnectService.openHealthConnectSettings();
        return;
      }

      if (!_hcPermissionGranted) {
        final granted = await HealthConnectService.requestSleepPermission();
        _hcPermissionGranted = granted;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                granted
                    ? 'Health Connect connected.'
                    : 'Sleep permission was not granted.',
              ),
            ),
          );
        }
      } else {
        await HealthConnectImporter.importLatestSleep();
        await _loadAnalytics();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Latest smartwatch sleep imported.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _hcBusy = false);
    }
  }

  Future<void> _loadAnalytics() async {
    if (_user == null) {
      setState(() => _loading = false);
      return;
    }

    final snap = await _firestore
        .collection('users')
        .doc(_user.uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .limit(120)
        .get();

    _dailyTotals.clear();
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

      final rawStages = (data['stages'] as List?) ?? const [];
      final stages = rawStages
          .map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final startStr = map['start']?.toString();
            final endStr = map['end']?.toString();
            if (startStr == null || endStr == null) return null;

            return _SleepStage(
              stage: (map['stage'] ?? 'unknown').toString(),
              start: DateTime.parse(startStr),
              end: DateTime.parse(endStr),
            );
          })
          .whereType<_SleepStage>()
          .toList();

      _sessions.add(
        _SleepRecord(
          start: start,
          end: end,
          durationHours: durationHours,
          source: source,
          stages: stages,
        ),
      );

      final key = DateFormat('yyyy-MM-dd').format(start);
      _dailyTotals[key] = (_dailyTotals[key] ?? 0.0) + durationHours;
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

  String _scheduleTypeLabel() {
    switch (_scheduleType) {
      case 'regular_daytime':
        return 'regular daytime';
      case 'night_shift':
        return 'night shift';
      case 'rotating_shift':
        return 'rotating shift';
      case 'student_irregular':
        return 'student irregular';
      default:
        return 'personal';
    }
  }

  String _scoreDescription() {
    if (_avg7 == 0) {
      return 'Record a few nights to unlock a personalized sleep score for your ${_scheduleTypeLabel()} routine and ${_sleepGoalHours.toStringAsFixed(1)}h goal.';
    }

    final diff = _sleepGoalHours - _avg7;
    final schedule = _scheduleTypeLabel();

    if (diff <= 0.2) {
      return 'You are sleeping close to your ${_sleepGoalHours.toStringAsFixed(1)}h goal. For a $schedule schedule, the priority now is keeping that routine consistent.';
    }

    if (diff <= 1.0) {
      return 'You are slightly below your ${_sleepGoalHours.toStringAsFixed(1)}h goal. For a $schedule schedule, a bit more sleep and steadier timing could improve your score.';
    }

    return 'You are clearly below your ${_sleepGoalHours.toStringAsFixed(1)}h goal. For a $schedule schedule, your next focus should be increasing sleep duration and protecting your routine.';
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
    if (diff >= 0.5) {
      return 'Your last 7 days are trending better than your 30-day average.';
    }
    if (diff <= -0.5) {
      return 'Your recent sleep is below your longer-term average.';
    }
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
    if (h >= 7 && h <= 8.5) {
      return 'Great night. This is a strong range for healthy sleep.';
    }
    if (h >= 6) {
      return 'Decent sleep, though still slightly below the ideal range.';
    }
    if (h >= 4) {
      return 'This was a short night. A calmer wind-down routine may help.';
    }
    return 'Very low sleep for one night. If this happens often, your schedule may need adjustment.';
  }

  List<_DayHours> _lastNDays(int n) {
    return List.generate(n, (i) {
      final date = DateTime.now().subtract(Duration(days: n - 1 - i));
      return _DayHours(date: date, hours: _hoursForDate(date));
    });
  }

  // ignore: unused_element
  _DayHours? _bestRecentNight() {
    final days = _lastNDays(14).where((d) => d.hours > 0).toList();
    if (days.isEmpty) return null;
    days.sort((a, b) => b.hours.compareTo(a.hours));
    return days.first;
  }

  // ignore: unused_element
  _DayHours? _worstRecentNight() {
    final days = _lastNDays(14).where((d) => d.hours > 0).toList();
    if (days.isEmpty) return null;
    days.sort((a, b) => a.hours.compareTo(b.hours));
    return days.first;
  }

  double _weekdayAverage() {
    final days = _lastNDays(30)
        .where(
          (d) =>
              d.hours > 0 &&
              d.date.weekday >= DateTime.monday &&
              d.date.weekday <= DateTime.friday,
        )
        .toList();

    if (days.isEmpty) return 0.0;
    return days.fold(0.0, (total, d) => total + d.hours) / days.length;
  }

  double _weekendAverage() {
    final days = _lastNDays(30)
        .where(
          (d) =>
              d.hours > 0 &&
              (d.date.weekday == DateTime.saturday ||
                  d.date.weekday == DateTime.sunday),
        )
        .toList();

    if (days.isEmpty) return 0.0;
    return days.fold(0.0, (total, d) => total + d.hours) / days.length;
  }

  List<double> _weekdayPattern() {
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);

    final days = _lastNDays(30).where((d) => d.hours > 0);
    for (final d in days) {
      final index = d.date.weekday - 1;
      sums[index] += d.hours;
      counts[index] += 1;
    }

    return List.generate(7, (i) {
      if (counts[i] == 0) return 0.0;
      return sums[i] / counts[i];
    });
  }

  List<_InsightData> _smartInsights() {
    final insights = <_InsightData>[];

    if (_avg7 == 0 && _avg30 == 0) {
      insights.add(
        _InsightData(
          icon: Icons.auto_awesome_rounded,
          text:
              'No sleep trend yet. Record a few nights and this section will start generating personalized feedback.',
          color: kBrand,
        ),
      );
      return insights;
    }

    if (_avg7 < 6) {
      insights.add(
        _InsightData(
          icon: Icons.bedtime_rounded,
          text:
              'Your recent sleep is quite low. Increasing duration should be the biggest priority right now.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else if (_avg7 < 7) {
      insights.add(
        _InsightData(
          icon: Icons.hotel_rounded,
          text:
              'You are sleeping a bit below the recommended range. Even 30 to 60 extra minutes could improve your weekly average.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else if (_avg7 <= 8.5) {
      insights.add(
        _InsightData(
          icon: Icons.check_circle_rounded,
          text:
              'Your recent average falls in a healthy range. The next goal is keeping it steady across the week.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else {
      insights.add(
        _InsightData(
          icon: Icons.nights_stay_rounded,
          text:
              'Your recent sleep is on the longer side. This may reflect recovery, accumulated fatigue, or inconsistent timing.',
          color: kAccentBlue,
        ),
      );
    }

    final diff = _avg7 - _avg30;
    if (diff >= 0.7) {
      insights.add(
        _InsightData(
          icon: Icons.trending_up_rounded,
          text:
              'Your last 7 days are noticeably stronger than your 30-day baseline. That suggests recent improvement.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else if (diff <= -0.7) {
      insights.add(
        _InsightData(
          icon: Icons.trending_down_rounded,
          text:
              'Your recent week is clearly below your monthly baseline. Something in the last few days may be disrupting your routine.',
          color: const Color(0xFFF59E0B),
        ),
      );
    } else {
      insights.add(
        _InsightData(
          icon: Icons.insights_rounded,
          text:
              'Your recent trend is relatively stable compared with your monthly average.',
          color: kAccentBlue,
        ),
      );
    }

    if (_daysWithSleep30 >= 24) {
      insights.add(
        _InsightData(
          icon: Icons.calendar_month_rounded,
          text:
              'You are tracking sleep consistently, which makes the analytics much more reliable.',
          color: const Color(0xFF22C55E),
        ),
      );
    } else if (_daysWithSleep30 < 12) {
      insights.add(
        _InsightData(
          icon: Icons.edit_calendar_rounded,
          text:
              'Tracking is still sparse. Recording more nights will make your patterns and scores much more meaningful.',
          color: kBrand,
        ),
      );
    }

    final weekdayAvg = _weekdayAverage();
    final weekendAvg = _weekendAverage();

    if (weekdayAvg > 0 && weekendAvg > 0) {
      final weekendDiff = weekendAvg - weekdayAvg;
      if (weekendDiff >= 1.0) {
        insights.add(
          _InsightData(
            icon: Icons.weekend_rounded,
            text:
                'You sleep noticeably longer on weekends than weekdays, which may indicate weekday sleep debt.',
            color: kAccentBlue,
          ),
        );
      } else if (weekendDiff <= -0.7) {
        insights.add(
          _InsightData(
            icon: Icons.schedule_rounded,
            text:
                'Your weekends are shorter than your weekdays, which is unusual and may reflect schedule disruption.',
            color: const Color(0xFFF59E0B),
          ),
        );
      } else {
        insights.add(
          _InsightData(
            icon: Icons.balance_rounded,
            text:
                'Your weekday and weekend sleep are fairly close, which suggests a steadier routine.',
            color: const Color(0xFF22C55E),
          ),
        );
      }
    }

    return insights.take(4).toList();
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
              ? const Center(child: CircularProgressIndicator(color: kBrand))
              : RefreshIndicator(
                  color: kBrand,
                  onRefresh: _loadAnalytics,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      _buildHero(score),
                      const SizedBox(height: 18),
                      _buildSmartwatchTile(),
                      const SizedBox(height: 18),
                      _buildLastNightCard(),
                      const SizedBox(height: 18),
                      _buildInsightsStrip(),
                      const SizedBox(height: 18),
                      _buildTrendCard(),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _ScoreRing(score: score)),
                const SizedBox(height: 18),
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
                  style: const TextStyle(color: kTextSecondary, height: 1.45),
                ),
              ],
            );
          }

          return Row(
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
          );
        },
      ),
    );
  }

  Widget _buildSmartwatchTile() {
    final statusColor = _hcPermissionGranted
        ? const Color(0xFF22C55E)
        : (_hcAvailable ? kAccentBlue : const Color(0xFFF59E0B));

    final actionLabel = _hcPermissionGranted ? 'Import' : 'Connect';

    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _circleIcon(Icons.watch_rounded, kBrand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smartwatch Sync',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hcAvailable
                      ? (_hcPermissionGranted
                            ? 'Import sleep recorded by your watch'
                            : 'Connect Health Connect to import watch sleep')
                      : 'Health Connect is not available on this phone',
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.circle, color: statusColor, size: 12),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _hcBusy ? null : _handleHealthConnect,
            child: Text(
              _hcBusy ? '...' : actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastNightCard() {
    if (_sessions.isEmpty) return const SizedBox.shrink();

    final last = _sessions.first;
    final hours = last.durationHours;
    final timeRange =
        '${DateFormat('HH:mm').format(last.start)} - ${DateFormat('HH:mm').format(last.end)}';

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last Night',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hours.toStringAsFixed(1)}h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'sleep',
                  style: TextStyle(color: kTextSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('EEEE, MMM d').format(last.start)} • $timeRange',
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _sourceBadge(last.source),
              const SizedBox(width: 8),
              _qualityDot(hours),
            ],
          ),

          if (last.stages.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSleepStagesCard(last.stages),
          ],
        ],
      ),
    );
  }

  Widget _sourceBadge(String source) {
    final isWatch = source == 'health_connect';
    final color = isWatch ? const Color(0xFF22C55E) : kAccentBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        isWatch ? 'Watch-recorded' : 'Manual',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _qualityDot(double hours) {
    late final String label;
    late final Color color;

    if (hours >= 7 && hours <= 8.5) {
      label = 'Strong';
      color = const Color(0xFF22C55E);
    } else if (hours >= 6) {
      label = 'Okay';
      color = const Color(0xFFF59E0B);
    } else {
      label = 'Low';
      color = const Color(0xFFF97316);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsStrip() {
    final insights = _smartInsights();

    if (insights.isEmpty) return const SizedBox.shrink();

    final main = insights.first;
    final rest = insights.skip(1).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Focus Tonight",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),

        _buildFocusCard(main),

        if (rest.isNotEmpty) const SizedBox(height: 14),

        ...rest.map((i) => _buildMiniInsight(i)),
      ],
    );
  }

  Widget _buildFocusCard(_InsightData item) {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [item.color, item.color.withValues(alpha: 0.6)],
              ),
            ),
            child: Icon(item.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _focusRewrite(item),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInsight(_InsightData item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(item.icon, color: item.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _miniRewrite(item),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _focusRewrite(_InsightData item) {
    if (item.icon == Icons.bedtime_rounded ||
        item.icon == Icons.hotel_rounded) {
      return "Sleep longer — this is your biggest improvement area right now.";
    }

    if (item.icon == Icons.trending_down_rounded) {
      return "Your sleep dropped recently — recover before it compounds.";
    }

    if (item.icon == Icons.check_circle_rounded) {
      return "You’re in a solid range — maintain consistency.";
    }

    return item.text;
  }

  String _miniRewrite(_InsightData item) {
    if (item.icon == Icons.trending_up_rounded) {
      return "Trend is improving";
    }

    if (item.icon == Icons.calendar_month_rounded ||
        item.icon == Icons.edit_calendar_rounded) {
      return "Consistency is low";
    }

    if (item.icon == Icons.weekend_rounded) {
      return "Weekend pattern differs";
    }

    if (item.icon == Icons.schedule_rounded) {
      return "Irregular sleep timing";
    }

    return item.text;
  }

  Widget _circleIcon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.16),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // ignore: unused_element
  Widget _buildChartsSection(bool isWide) {
    final bars = _lastNDays(7);
    final trend = _lastNDays(14);

    final barCard = _glassCard(
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
          Text(
            _avg7 == 0
                ? 'No recent sleep data yet'
                : 'Average: ${_avg7.toStringAsFixed(1)} h • Goal: ${_sleepGoalHours.toStringAsFixed(1)} h',
            style: const TextStyle(color: kTextSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: _BarChart(days: bars, goal: _sleepGoalHours),
          ),
        ],
      ),
    );

    final lineCard = _glassCard(
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
            height: 210,
            child: _LineChart(days: trend, goal: _sleepGoalHours),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: barCard),
          const SizedBox(width: 12),
          Expanded(child: lineCard),
        ],
      );
    }

    return Column(children: [barCard, const SizedBox(height: 12), lineCard]);
  }

  // ignore: unused_element
  Widget _buildTopStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 880;
        final children = [
          Expanded(
            child: _buildStatCard(
              title: 'Avg (7 days)',
              value: '${_avg7.toStringAsFixed(1)} h',
              subtitle: 'Recent sleep average',
              accent: kAccentBlue,
            ),
          ),
          const SizedBox(width: 12, height: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Avg (30 days)',
              value: '${_avg30.toStringAsFixed(1)} h',
              subtitle: 'Monthly average',
              accent: kBrand,
            ),
          ),
          const SizedBox(width: 12, height: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Recent trend',
              value: _trendShortLabel(),
              subtitle: _trendMessage(),
              accent: const Color(0xFF22C55E),
            ),
          ),
        ];

        if (wide) {
          return Row(children: children);
        }

        return Column(
          children: [
            Row(children: [children[0], children[1]]),
            const SizedBox(height: 12),
            Row(children: [children[2]]),
          ],
        );
      },
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
          Text(title, style: const TextStyle(color: kTextMuted, fontSize: 12)),
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

  // ignore: unused_element
  Widget _buildBestWorstSection(
    _DayHours? best,
    _DayHours? worst,
    bool isWide,
  ) {
    final cards = [
      Expanded(
        child: _buildNightCard(
          title: 'Best Recent Night',
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFF22C55E),
          day: best,
          fallback: 'No recorded sleep yet',
        ),
      ),
      const SizedBox(width: 12, height: 12),
      Expanded(
        child: _buildNightCard(
          title: 'Worst Recent Night',
          icon: Icons.bolt_rounded,
          color: const Color(0xFFF59E0B),
          day: worst,
          fallback: 'No recorded sleep yet',
        ),
      ),
    ];

    if (isWide) {
      return Row(children: cards);
    }

    return Column(
      children: [
        Row(children: [cards[0]]),
        const SizedBox(height: 12),
        Row(children: [cards[2]]),
      ],
    );
  }

  Widget _buildNightCard({
    required String title,
    required IconData icon,
    required Color color,
    required _DayHours? day,
    required String fallback,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (day == null)
            Text(fallback, style: const TextStyle(color: kTextSecondary))
          else ...[
            Text(
              '${day.hours.toStringAsFixed(1)} h',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('EEEE, MMM d').format(day.date),
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              _sleepInsight(day.hours),
              style: const TextStyle(color: kTextSecondary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWeekdayPatternCard() {
    final pattern = _weekdayPattern();
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekday Pattern',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Average sleep duration by day of week over the last month.',
            style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(pattern.length, (i) {
              final hours = pattern[i];
              final factor = (hours / 9).clamp(0.0, 1.0);
              final isWeekend = i >= 5;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        hours == 0 ? '0' : hours.toStringAsFixed(1),
                        style: const TextStyle(color: kTextMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 110,
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: factor,
                          child: Container(
                            width: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isWeekend
                                    ? [const Color(0xFF8B5CF6), kBrand]
                                    : [kAccentBlue, kBrand],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[i],
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
            style: const TextStyle(color: kTextSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
            style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.4),
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
              mainAxisExtent: 44,
            ),
            itemBuilder: (_, i) {
              final day = _heatmapDays[i];
              final hours = _hoursForDate(day);

              final double intensity = hours == 0
                  ? 0.0
                  : (hours / 9).clamp(0.18, 1.0).toDouble();

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
                      borderRadius: BorderRadius.circular(6),
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
                value: (hours / _sleepGoalHours).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                color: kAccentBlue,
                minHeight: 10,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              Text(
                _sleepInsight(hours),
                style: const TextStyle(color: kTextSecondary, height: 1.45),
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
                  style: TextStyle(color: kTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SleepHistoryScreen()),
              );
            },
            child: const Text('Open', style: TextStyle(color: kBrand)),
          ),
        ],
      ),
    );
  }
}

class _SleepRecord {
  final DateTime start;
  final DateTime end;
  final double durationHours;
  final String source;
  final List<_SleepStage> stages;

  const _SleepRecord({
    required this.start,
    required this.end,
    required this.durationHours,
    required this.source,
    required this.stages,
  });
}

class _SleepStage {
  final String stage;
  final DateTime start;
  final DateTime end;

  const _SleepStage({
    required this.stage,
    required this.start,
    required this.end,
  });

  double get minutes => end.difference(start).inMinutes.toDouble();
}

class _DayHours {
  final DateTime date;
  final double hours;

  _DayHours({required this.date, required this.hours});
}

class _InsightData {
  final IconData icon;
  final String text;
  final Color color;

  const _InsightData({
    required this.icon,
    required this.text,
    required this.color,
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
  final double goal;

  const _BarChart({required this.days, required this.goal});

  @override
  Widget build(BuildContext context) {
    final maxHours = math.max(
      math.max(9.0, goal),
      days.fold<double>(0.0, (max, d) => d.hours > max ? d.hours : max),
    );

    final validDays = days.where((d) => d.hours > 0).toList();
    final best = validDays.isEmpty
        ? null
        : validDays.reduce((a, b) => a.hours >= b.hours ? a : b);
    final worst = validDays.isEmpty
        ? null
        : validDays.reduce((a, b) => a.hours <= b.hours ? a : b);

    final avg = validDays.isEmpty
        ? 0.0
        : validDays.fold(0.0, (total, d) => total + d.hours) / validDays.length;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BarChartGuidePainter(
                    maxHours: maxHours,
                    avg: avg,
                    goal: goal,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((d) {
                  final heightFactor = maxHours == 0
                      ? 0.0
                      : (d.hours / maxHours).clamp(0.0, 1.0);
                  final isBest = best != null && identical(d, best);
                  final isWorst = worst != null && identical(d, worst);
                  final isGood = d.hours >= 7;

                  final colors = isBest
                      ? [const Color(0xFF22C55E), kBrand]
                      : isWorst
                      ? [const Color(0xFFF59E0B), kBrand]
                      : isGood
                      ? [kAccentBlue, kBrand]
                      : [const Color(0xFF334155), const Color(0xFF7C3AED)];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            d.hours == 0 ? '0' : d.hours.toStringAsFixed(1),
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 11,
                            ),
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
                                      colors: colors,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.first.withValues(
                                          alpha: 0.20,
                                        ),
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
                            style: const TextStyle(
                              color: kTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MiniLegend(color: Color(0xFF22C55E), label: 'Best'),
            SizedBox(width: 10),
            _MiniLegend(color: Color(0xFFF59E0B), label: 'Lowest'),
            SizedBox(width: 10),
            _MiniLegend(color: kAccentBlue, label: 'Good'),
          ],
        ),
      ],
    );
  }
}

class _BarChartGuidePainter extends CustomPainter {
  final double maxHours;
  final double avg;
  final double goal;

  _BarChartGuidePainter({
    required this.maxHours,
    required this.avg,
    required this.goal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double mapY(double value) {
      return size.height - ((value / maxHours) * size.height);
    }

    final goalY = mapY(goal).clamp(0.0, size.height);
    final goalPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2;

    canvas.drawLine(Offset(0, goalY), Offset(size.width, goalY), goalPaint);

    if (avg > 0) {
      final avgY = mapY(avg).clamp(0.0, size.height);
      final avgPaint = Paint()
        ..color = kBrand.withValues(alpha: 0.28)
        ..strokeWidth = 2;

      canvas.drawLine(Offset(0, avgY), Offset(size.width, avgY), avgPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartGuidePainter oldDelegate) {
    return oldDelegate.maxHours != maxHours ||
        oldDelegate.avg != avg ||
        oldDelegate.goal != goal;
  }
}

class _LineChart extends StatelessWidget {
  final List<_DayHours> days;
  final double goal;

  const _LineChart({required this.days, required this.goal});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(days: days, goal: goal),
      child: Container(),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_DayHours> days;
  final double goal;

  _LineChartPainter({required this.days, required this.goal});

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
      math.max(9.0, goal),
      days.fold<double>(0.0, (max, d) => d.hours > max ? d.hours : max),
    );

    double mapY(double value) {
      return size.height - ((value / maxHours) * (size.height - 16)) - 8;
    }

    final goalY = mapY(goal);
    final goalPaint = Paint()
      ..color = kBrand.withValues(alpha: 0.35)
      ..strokeWidth = 2;

    canvas.drawLine(Offset(0, goalY), Offset(size.width, goalY), goalPaint);

    final points = <Offset>[];
    for (int i = 0; i < days.length; i++) {
      final x = days.length == 1
          ? size.width / 2
          : i * size.width / (days.length - 1);
      final y = mapY(days[i].hours);
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

    final bestPoint = _bestPoint(points);
    final worstPoint = _worstPoint(points);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final hours = days[i].hours;

      final isBest = bestPoint == p && hours > 0;
      final isWorst = worstPoint == p && hours > 0;

      final glowPaint = Paint()
        ..color =
            (isBest
                    ? const Color(0xFF22C55E)
                    : isWorst
                    ? const Color(0xFFF59E0B)
                    : kAccentBlue)
                .withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final dotPaint = Paint()
        ..color = isBest
            ? const Color(0xFF22C55E)
            : isWorst
            ? const Color(0xFFF59E0B)
            : Colors.white;

      canvas.drawCircle(p, 6, glowPaint);
      canvas.drawCircle(p, 3.2, dotPaint);
    }
  }

  Offset? _bestPoint(List<Offset> points) {
    if (days.isEmpty) return null;
    int bestIndex = -1;
    double bestHours = -1;
    for (int i = 0; i < days.length; i++) {
      if (days[i].hours > bestHours) {
        bestHours = days[i].hours;
        bestIndex = i;
      }
    }
    if (bestIndex == -1) return null;
    return points[bestIndex];
  }

  Offset? _worstPoint(List<Offset> points) {
    final validIndices = <int>[];
    for (int i = 0; i < days.length; i++) {
      if (days[i].hours > 0) validIndices.add(i);
    }
    if (validIndices.isEmpty) return null;

    int worstIndex = validIndices.first;
    double worstHours = days[worstIndex].hours;

    for (final i in validIndices) {
      if (days[i].hours < worstHours) {
        worstHours = days[i].hours;
        worstIndex = i;
      }
    }

    return points[worstIndex];
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.days != days || oldDelegate.goal != goal;
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
          style: const TextStyle(color: kTextSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _MiniLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _MiniLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: kTextSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
