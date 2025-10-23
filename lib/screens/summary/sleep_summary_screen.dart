import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/app_navbar.dart';
import '../../theme.dart';

class SleepSummaryScreen extends StatefulWidget {
  const SleepSummaryScreen({super.key});

  @override
  State<SleepSummaryScreen> createState() => _SleepSummaryScreenState();
}

class _SleepSummaryScreenState extends State<SleepSummaryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  String _currentView = 'Weekly';
  double totalHours = 0;
  double averageHours = 0;
  double longest = 0;
  double shortest = 0;
  Map<String, double> dailyHours = {};
  Map<String, double> monthlyHours = {};
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  DateTime get _startOfWeek {
    final now = DateTime.now().add(Duration(days: 7 * _weekOffset));
    return now.subtract(Duration(days: now.weekday % 7));
  }

  DateTime get _endOfWeek => _startOfWeek.add(const Duration(days: 7));

  Future<void> _loadSummary() async {
    if (_user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(_user.uid)
        .collection('sleep_sessions')
        .get();

    if (snapshot.docs.isEmpty) return;

    final allDurations = <double>[];
    final daily = {for (final d in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) d: 0.0};
    final monthly = {
      for (final m in ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']) m: 0.0
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final start = (data['start'] as Timestamp).toDate();
      final end = data['end'] == null ? null : (data['end'] as Timestamp).toDate();
      if (end == null) continue;

      final durationHr = end.difference(start).inMinutes / 60.0;
      allDurations.add(durationHr);

      if (start.isAfter(_startOfWeek) && start.isBefore(_endOfWeek)) {
        final day = DateFormat('E').format(start);
        daily[day] = (daily[day] ?? 0) + durationHr;
      }

      final month = DateFormat('MMM').format(start);
      monthly[month] = (monthly[month] ?? 0) + durationHr;
    }

    setState(() {
      totalHours = allDurations.fold(0, (a, b) => a + b);
      averageHours = allDurations.isEmpty ? 0 : totalHours / allDurations.length;
      longest = allDurations.isEmpty ? 0 : allDurations.reduce((a, b) => a > b ? a : b);
      shortest = allDurations.isEmpty ? 0 : allDurations.reduce((a, b) => a < b ? a : b);
      dailyHours = daily;
      monthlyHours = monthly;
    });
  }

  String _weekLabel() {
    final start = DateFormat('MMM d').format(_startOfWeek);
    final end = DateFormat('MMM d').format(_endOfWeek.subtract(const Duration(days: 1)));
    return "$start - $end";
  }

  @override
  Widget build(BuildContext context) {
    final weeklyGoal = 56.0;
    final weekTotal = dailyHours.values.fold(0.0, (a, b) => a + b);
    final goalProgress = (weekTotal / weeklyGoal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.summary),
      backgroundColor: kSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CupertinoSegmentedControl<String>(
                groupValue: _currentView,
                onValueChanged: (v) => setState(() => _currentView = v),
                children: const {
                  'Daily': Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Daily')),
                  'Weekly': Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Weekly')),
                  'Yearly': Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Yearly')),
                },
              ),
              const SizedBox(height: 20),
              if (_currentView == 'Weekly') _buildWeeklyView(goalProgress),
              if (_currentView == 'Daily') _buildDailyView(),
              if (_currentView == 'Yearly') _buildYearlyView(),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== WEEKLY VIEW =====================
  Widget _buildWeeklyView(double progress) {
    return Expanded(
      child: Column(
        key: const ValueKey('weekly'),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: kBrand),
                onPressed: () {
                  setState(() => _weekOffset--);
                  _loadSummary();
                },
              ),
              Text(
                _weekLabel(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: kBrand),
                onPressed: () {
                  setState(() => _weekOffset++);
                  _loadSummary();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard("Avg", "${averageHours.toStringAsFixed(1)}h"),
              const SizedBox(width: 8),
              _statCard("Longest", "${longest.toStringAsFixed(1)}h"),
              const SizedBox(width: 8),
              _statCard("Shortest", "${shortest.toStringAsFixed(1)}h"),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.deepPurple.shade50,
              valueColor: AlwaysStoppedAnimation(
                progress > 0.6 ? kBrand : Colors.purpleAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: BarChart(
                BarChartData(
                  maxY: 12,
                  minY: 0,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(6),
                      // Background color varies across fl_chart versions; omit for compatibility
                      getTooltipItem: (a, b, rod, c) => BarTooltipItem(
                        "${rod.toY.toStringAsFixed(1)}h",
                        const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, _) => Text(
                          "${value.toInt()}h",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                          if (v.toInt() >= 0 && v.toInt() < days.length) {
                            return Text(
                              days[v.toInt()],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                    final hours = dailyHours[days[i]] ?? 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: hours.clamp(0, 12),
                          color: kBrand,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView() {
    final today = DateFormat('E').format(DateTime.now());
    final hours = dailyHours[today] ?? 0;
    return Expanded(
      child: Center(
        child: Text(
          hours == 0
              ? 'No sleep data for today 😴'
              : 'Today you slept ${hours.toStringAsFixed(1)} hours 😴',
          style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== YEARLY VIEW =====================
  Widget _buildYearlyView() {
    final avg = monthlyHours.values.isEmpty
        ? 0.0
        : monthlyHours.values.fold(0.0, (a, b) => a + b) /
            monthlyHours.values.where((h) => h > 0).length.clamp(1, 12);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: BarChart(
          BarChartData(
            maxY: 12,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.all(6),
                // Omit background color for fl_chart compatibility
                getTooltipItem: (a, b, rod, c) => BarTooltipItem(
                  "${rod.toY.toStringAsFixed(1)}h",
                  const TextStyle(color: Colors.white),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: 2,
                  getTitlesWidget: (value, _) => Text(
                    "${value.toInt()}h",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) {
                    final months = monthlyHours.keys.toList();
                    if (v.toInt() < months.length) {
                      return Text(
                        months[v.toInt()],
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: avg.toDouble(),
                  color: kBrand.withOpacity(0.3),
                  strokeWidth: 2,
                  dashArray: const [5, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    labelResolver: (_) => "Avg ${avg.toStringAsFixed(1)}h",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            barGroups: List.generate(monthlyHours.length, (i) {
              final month = monthlyHours.keys.elementAt(i);
              final hours = monthlyHours[month] ?? 0;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: hours.clamp(0, 12),
                    gradient: const LinearGradient(
                      colors: [Color(0xff8E2DE2), Color(0xff4A00E0)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

