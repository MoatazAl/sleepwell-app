import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';

class AssessmentHistoryScreen extends StatefulWidget {
  const AssessmentHistoryScreen({super.key});

  @override
  State<AssessmentHistoryScreen> createState() =>
      _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  String? _error;
  final List<_AssessmentResultRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_user == null) {
        _error = 'You need to sign in to view assessment history.';
        return;
      }

      final snap = await _firestore
          .collection('users')
          .doc(_user.uid)
          .collection('assessments')
          .orderBy('createdAt', descending: true)
          .limit(120)
          .get()
          .timeout(const Duration(seconds: 10));

      _records
        ..clear()
        ..addAll(
          snap.docs.map((doc) {
            final data = doc.data();
            final type = (data['type'] ?? 'Assessment').toString();
            final score = (data['score'] as num?)?.toInt() ?? 0;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return _AssessmentResultRecord(
              id: doc.id,
              type: type,
              score: score,
              maxScore: _maxScore(type),
              level: (data['level'] ?? _levelFor(type, score)).toString(),
              message: (data['message'] ?? '').toString(),
              createdAt: createdAt,
              color: _colorFor(type, score),
            );
          }),
        );
    } on FirebaseException catch (error) {
      _error = error.code == 'permission-denied'
          ? 'Assessment history is unavailable because Firestore permissions blocked this request.'
          : 'Could not load assessment history. Please try again.';
    } catch (_) {
      _error = 'Could not load assessment history. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestByType();
    final groups = _groupByMonth(_records);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Assessment History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrand))
              : RefreshIndicator(
                  color: kBrand,
                  onRefresh: _loadHistory,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      _heroCard(),
                      const SizedBox(height: 18),
                      if (_error != null) _errorCard(),
                      if (_records.isEmpty && _error == null) _emptyState(),
                      if (_records.isNotEmpty) ...[
                        _latestScores(latest),
                        const SizedBox(height: 22),
                        _sectionTitle('Past results'),
                        const SizedBox(height: 12),
                        ...groups.entries.expand(
                          (entry) => [
                            _monthHeader(entry.key),
                            const SizedBox(height: 10),
                            ...entry.value.map(_resultCard),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kBrand, kAccentBlue.withValues(alpha: 0.82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kBrand.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.assignment_turned_in_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assessment History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Review your PSQI, ESS, and ISI scores over time.',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 14,
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

  Widget _latestScores(Map<String, _AssessmentResultRecord> latest) {
    final types = ['PSQI', 'ESS', 'ISI'];
    final isWide = MediaQuery.of(context).size.width >= 860;
    final cards = types.map((type) {
      final record = latest[type];
      final previous = _previousFor(type, record?.id);
      return _latestScoreCard(type, record, previous);
    }).toList();

    if (isWide) {
      return Row(
        children: List.generate(
          cards.length,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == cards.length - 1 ? 0 : 12,
              ),
              child: cards[index],
            ),
          ),
        ),
      );
    }

    return Column(
      children: cards
          .map(
            (card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
          )
          .toList(),
    );
  }

  Widget _latestScoreCard(
    String type,
    _AssessmentResultRecord? record,
    _AssessmentResultRecord? previous,
  ) {
    final color = record?.color ?? _baseColor(type);
    final trend = record == null || previous == null
        ? 'No trend yet'
        : _trendText(record.score, previous.score);
    final trendIcon = record == null || previous == null
        ? Icons.trending_flat_rounded
        : record.score == previous.score
        ? Icons.trending_flat_rounded
        : record.score < previous.score
        ? Icons.trending_down_rounded
        : Icons.trending_up_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Icon(_iconFor(type), color: color, size: 23),
              ),
              const Spacer(),
              _pill(type, color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            record == null ? '--' : '${record.score}',
            style: TextStyle(
              color: color,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            record == null ? 'No result yet' : 'out of ${record.maxScore}',
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text(
            record?.level ?? 'Take this assessment to start tracking.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.event_rounded, color: Colors.white38, size: 16),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  record == null ? 'Not taken' : _dateText(record.createdAt),
                  style: const TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendIcon, color: color, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  trend,
                  style: const TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(_AssessmentResultRecord record) {
    final previous = _previousFor(record.type, record.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: glassCardDecoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: record.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(_iconFor(record.type), color: record.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        record.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _pill(record.level, record.color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateText(record.createdAt),
                    style: const TextStyle(color: kTextSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    previous == null
                        ? 'First recorded result'
                        : _trendText(record.score, previous.score),
                    style: const TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.score}',
                  style: TextStyle(
                    color: record.color,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '/ ${record.maxScore}',
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ],
            ),
          ],
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

  Widget _monthHeader(String month) {
    return Text(
      month,
      style: const TextStyle(
        color: kTextSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassCardDecoration,
      child: const Column(
        children: [
          Icon(Icons.assignment_outlined, color: kTextMuted, size: 42),
          SizedBox(height: 12),
          Text(
            'No assessments yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your completed PSQI, ESS, and ISI results will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFF97316)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: kTextSecondary)),
          ),
          IconButton(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Map<String, _AssessmentResultRecord> _latestByType() {
    final latest = <String, _AssessmentResultRecord>{};

    for (final record in _records) {
      latest.putIfAbsent(record.type, () => record);
    }

    return latest;
  }

  _AssessmentResultRecord? _previousFor(String type, String? currentId) {
    if (currentId == null) return null;

    final typed = _records.where((record) => record.type == type).toList();
    final index = typed.indexWhere((record) => record.id == currentId);

    if (index == -1 || index + 1 >= typed.length) return null;
    return typed[index + 1];
  }

  Map<String, List<_AssessmentResultRecord>> _groupByMonth(
    List<_AssessmentResultRecord> records,
  ) {
    final map = <String, List<_AssessmentResultRecord>>{};

    for (final record in records) {
      final date = record.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final key = record.createdAt == null
          ? 'Date pending'
          : DateFormat('MMMM yyyy').format(date);
      map.putIfAbsent(key, () => []).add(record);
    }

    return map;
  }

  String _trendText(int current, int previous) {
    final diff = current - previous;

    if (diff == 0) return 'No change from previous result';

    final direction = diff < 0 ? 'improved' : 'increased';
    final points = diff.abs() == 1 ? 'point' : 'points';
    return '${diff.abs()} $points $direction from previous result';
  }

  String _dateText(DateTime? date) {
    if (date == null) return 'Date pending';
    return DateFormat('MMM d, yyyy').format(date);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'PSQI':
        return Icons.bedtime_rounded;
      case 'ISI':
        return Icons.nights_stay_rounded;
      case 'ESS':
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  static int _maxScore(String type) {
    switch (type) {
      case 'PSQI':
        return 21;
      case 'ISI':
        return 28;
      case 'ESS':
      default:
        return 24;
    }
  }

  static Color _baseColor(String type) {
    switch (type) {
      case 'PSQI':
        return const Color(0xFF22C55E);
      case 'ISI':
        return const Color(0xFFF59E0B);
      case 'ESS':
      default:
        return kBrand;
    }
  }

  static Color _colorFor(String type, int score) {
    switch (type) {
      case 'PSQI':
        if (score <= 5) return const Color(0xFF22C55E);
        if (score <= 10) return const Color(0xFFF59E0B);
        return const Color(0xFFF97316);
      case 'ISI':
        if (score <= 7) return const Color(0xFF22C55E);
        if (score <= 14) return const Color(0xFFF59E0B);
        if (score <= 21) return const Color(0xFFF97316);
        return const Color(0xFFEF4444);
      case 'ESS':
      default:
        if (score <= 10) return const Color(0xFF22C55E);
        if (score <= 14) return const Color(0xFFF59E0B);
        if (score <= 17) return const Color(0xFFF97316);
        return const Color(0xFFEF4444);
    }
  }

  static String _levelFor(String type, int score) {
    switch (type) {
      case 'PSQI':
        if (score <= 5) return 'Good sleep quality range';
        if (score <= 10) return 'Sleep quality may need attention';
        return 'Poor sleep-quality indicators';
      case 'ISI':
        if (score <= 7) return 'No clinically significant insomnia';
        if (score <= 14) return 'Subthreshold insomnia';
        if (score <= 21) return 'Moderate insomnia symptoms';
        return 'Severe insomnia symptoms';
      case 'ESS':
      default:
        if (score <= 10) return 'Normal daytime sleepiness';
        if (score <= 14) return 'Mild excessive daytime sleepiness';
        if (score <= 17) return 'Moderate excessive daytime sleepiness';
        return 'Severe excessive daytime sleepiness';
    }
  }
}

class _AssessmentResultRecord {
  final String id;
  final String type;
  final int score;
  final int maxScore;
  final String level;
  final String message;
  final DateTime? createdAt;
  final Color color;

  const _AssessmentResultRecord({
    required this.id,
    required this.type,
    required this.score,
    required this.maxScore,
    required this.level,
    required this.message,
    required this.createdAt,
    required this.color,
  });
}
