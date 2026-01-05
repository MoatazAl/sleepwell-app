import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../widgets/app_navbar.dart';
import '../../theme.dart';

class DayInsightsScreen extends StatefulWidget {
  final DateTime date;

  const DayInsightsScreen({super.key, required this.date});

  @override
  State<DayInsightsScreen> createState() => _DayInsightsScreenState();
}

class _DayInsightsScreenState extends State<DayInsightsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadDaySessions();
  }

  Future<void> _loadDaySessions() async {
    if (_user == null) return;

    final startOfDay =
        DateTime(widget.date.year, widget.date.month, widget.date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('sleep_records')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('start', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('start')
        .get();

    final sessions = snapshot.docs.map((doc) {
      final data = doc.data();
      final start = (data['start'] as Timestamp?)?.toDate();
      final end = (data['end'] as Timestamp?)?.toDate();

      double duration = 0;
      if (start != null && end != null && end.isAfter(start)) {
        duration = end.difference(start).inMinutes / 60.0;
      }

      return {
        'start': start,
        'end': end,
        'duration': duration,
      };
    }).where((s) => (s['duration'] as double) > 0).toList();

    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  String _fmt(DateTime? t) =>
      t == null ? '—' : DateFormat('h:mm a').format(t);

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
                    Text(
                      DateFormat('EEEE, MMM d').format(widget.date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${_sessions.length} sleep session${_sessions.length == 1 ? '' : 's'}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),

                    ..._sessions.map(_buildSessionCard).toList(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> s) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_fmt(s['start'])} → ${_fmt(s['end'])}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${(s['duration'] as double).toStringAsFixed(1)} hours",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
