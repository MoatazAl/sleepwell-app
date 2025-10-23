import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_navbar.dart';
import '../../theme.dart';
import '../history/sleep_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _lastSession;
  List<Map<String, dynamic>> _recentSessions = [];
  double _weeklyAverage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSleepData();
  }

  Future<void> _loadSleepData() async {
    if (_user == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(_user.uid)
        .collection('sleep_sessions')
        .orderBy('start', descending: true)
        .limit(14)
        .get();

    if (snapshot.docs.isEmpty) return;

    final sessions = snapshot.docs.map((doc) {
      final data = doc.data();
      final start = (data['start'] as Timestamp).toDate();
      final end = data['end'] != null
          ? (data['end'] as Timestamp).toDate()
          : null;
      final duration = end == null ? 0 : end.difference(start).inMinutes / 60.0;
      return {'start': start, 'end': end, 'duration': duration};
    }).toList();

    // Calculate last 7 days average
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final List<double> lastWeekDurations = sessions
        .where((s) => (s['start'] as DateTime).isAfter(sevenDaysAgo))
        .map((s) => (s['duration'] as num).toDouble())
        .toList();

    final avg = lastWeekDurations.isEmpty
        ? 0.0
        : lastWeekDurations.reduce((a, b) => a + b) / lastWeekDurations.length;

    setState(() {
      _lastSession = sessions.first;
      _recentSessions = sessions.take(5).toList();
      _weeklyAverage = avg;
    });
  }

  String _formatTime(DateTime t) => DateFormat('h:mm a').format(t);

  String _motivation(double hours) {
    if (hours >= 8) return "Excellent sleep! 🌙";
    if (hours >= 6.5) return "Good rest, try for 8h tonight 💪";
    return "You need more rest 😴";
  }

  String _tipOfTheDay() {
    final tips = [
      "Avoid screens 30 minutes before bed 🌙",
      "Stick to a consistent bedtime and wake time ⏰",
      "Keep your room cool and dark for better sleep 🌑",
      "Avoid caffeine after 4 PM ☕",
      "Stretch or read a book before bed 📖",
    ];
    final i = DateTime.now().weekday % tips.length;
    return "Tip of the Day: ${tips[i]}";
  }

  @override
  Widget build(BuildContext context) {
    final last = _lastSession;
    return Scaffold(
      appBar: const AppNavBar(current: NavSection.home),
      backgroundColor: kSurface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSleepData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ===== LAST NIGHT =====
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: last == null
                      ? const Text(
                          "No sleep data yet. Start tracking tonight 🌙",
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Last Night",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${last['duration'].toStringAsFixed(1)} hours of sleep",
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "From ${_formatTime(last['start'])} to ${_formatTime(last['end'])}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _motivation(last['duration']),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ===== WEEKLY AVERAGE =====
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Weekly Average",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${_weeklyAverage.toStringAsFixed(1)} hours/night",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      Icon(
                        _weeklyAverage >= 8
                            ? Icons.emoji_events
                            : _weeklyAverage >= 6
                            ? Icons.trending_up
                            : Icons.bedtime,
                        color: Colors.deepPurple,
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ===== RECENT HISTORY =====
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Sleep History",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SleepHistoryScreen(),
                      ),
                    ),
                    child: const Text("View All →"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: _recentSessions.isEmpty
                    ? const Center(child: Text("No history available"))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentSessions.length,
                        itemBuilder: (context, i) {
                          final s = _recentSessions[i];
                          final date = DateFormat(
                            'E, MMM d',
                          ).format(s['start']);
                          return Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${s['duration'].toStringAsFixed(1)}h",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  date,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 24),

              // ===== TIP =====
              Card(
                color: const Color(0xffF3E5F5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _tipOfTheDay(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.deepPurple,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
