import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_navbar.dart';
import '../../theme.dart';
import 'day_insights_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;

  /// Each item:
  /// {
  ///   date: DateTime,
  ///   total: double,
  ///   sessions: int
  /// }
  final List<Map<String, dynamic>> _days = [];

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  // =====================================================
  // LOAD + AGGREGATE
  // =====================================================

  Future<void> _loadInsights() async {
    if (_user == null) return;

    setState(() => _loading = true);

    final snapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_records')
        .orderBy('start', descending: true)
        .limit(100)
        .get();

    final Map<String, Map<String, dynamic>> daily = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final start = (data['start'] as Timestamp?)?.toDate();
      final end = (data['end'] as Timestamp?)?.toDate();

      if (start == null || end == null || !end.isAfter(start)) continue;

      final hours = end.difference(start).inMinutes / 60.0;
      if (hours <= 0 || hours > 14) continue;

      final key = DateFormat('yyyy-MM-dd').format(start);

      daily.putIfAbsent(key, () {
        return {
          'date': DateTime(start.year, start.month, start.day),
          'total': 0.0,
          'sessions': 0,
        };
      });

      daily[key]!['total'] += hours;
      daily[key]!['sessions'] += 1;
    }

    final list = daily.values.toList()
      ..sort((a, b) =>
          (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    setState(() {
      _days
        ..clear()
        ..addAll(list);
      _loading = false;
    });
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavBar(current: NavSection.insights),
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
                      "Insights",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_days.isEmpty)
                      const Text(
                        "No sleep data yet.",
                        style: TextStyle(color: Colors.white70),
                      )
                    else
                      ..._days.map(_buildDayTile),
                  ],
                ),
        ),
      ),
    );
  }

  // =====================================================
  // DAY TILE
  // =====================================================

  Widget _buildDayTile(Map<String, dynamic> d) {
    final date = d['date'] as DateTime;
    final total = d['total'] as double;
    final sessions = d['sessions'] as int;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DayInsightsScreen(date: date),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withValues(alpha: 0.08),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('E, MMM d').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$sessions session${sessions == 1 ? '' : 's'}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            Text(
              "${total.toStringAsFixed(1)} h",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
