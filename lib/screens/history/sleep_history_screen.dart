import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';

class SleepHistoryScreen extends StatefulWidget {
  const SleepHistoryScreen({super.key});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  String? _error;
  final List<_SleepHistoryRecord> _records = [];

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
        _error = 'You need to sign in to view sleep history.';
        return;
      }

      final snap = await _firestore
          .collection('users')
          .doc(_user.uid)
          .collection('sleep_records')
          .orderBy('start', descending: true)
          .limit(180)
          .get()
          .timeout(const Duration(seconds: 10));

      _records.clear();

      for (final doc in snap.docs) {
        final data = doc.data();

        final start = (data['start'] as Timestamp?)?.toDate();
        final end = (data['end'] as Timestamp?)?.toDate();

        if (start == null || end == null || !end.isAfter(start)) continue;

        final durationHours =
            (data['durationHours'] as num?)?.toDouble() ??
            end.difference(start).inMinutes / 60.0;

        final rawStages = (data['stages'] as List?) ?? const [];

        _records.add(
          _SleepHistoryRecord(
            id: doc.id,
            start: start,
            end: end,
            durationHours: durationHours,
            source: (data['source'] ?? 'manual').toString(),
            stages: rawStages
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          ),
        );
      }

      _records.sort((a, b) => b.start.compareTo(a.start));
    } on FirebaseException catch (error) {
      _error = error.code == 'permission-denied'
          ? 'Sleep history is unavailable because Firestore permissions blocked this request.'
          : 'Could not load sleep history. Please try again.';
    } catch (_) {
      _error = 'Could not load sleep history. Please try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByMonth(_records);

    return Scaffold(
      appBar: const AppNavBar(current: NavSection.history),
      backgroundColor: Colors.transparent,
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
                      _summaryCards(),
                      const SizedBox(height: 22),
                      if (_error != null) _errorCard(),
                      if (_records.isEmpty && _error == null) _emptyState(),
                      ...groups.entries.expand(
                        (entry) => [
                          const SizedBox(height: 18),
                          _monthHeader(entry.key),
                          const SizedBox(height: 10),
                          ...entry.value.map(_recordCard),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Map<String, List<_SleepHistoryRecord>> _groupByMonth(
    List<_SleepHistoryRecord> records,
  ) {
    final map = <String, List<_SleepHistoryRecord>>{};

    for (final r in records) {
      final key = DateFormat('MMMM yyyy').format(r.start);
      map.putIfAbsent(key, () => []).add(r);
    }

    return map;
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassCardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Review your recorded nights, compare sources, and inspect sleep stages over time.',
            style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    final avg = _records.isEmpty
        ? 0.0
        : _records.fold<double>(0, (total, r) => total + r.durationHours) /
              _records.length;

    final watchCount = _records
        .where(
          (r) => r.source == 'health_connect' || r.source == 'samsung_health',
        )
        .length;

    final stats = [
      _miniStat('Records', '${_records.length}', Icons.history_rounded, kBrand),
      _miniStat(
        'Average',
        '${avg.toStringAsFixed(1)} h',
        Icons.bedtime_rounded,
        kAccentBlue,
      ),
      _miniStat(
        'Watch',
        '$watchCount',
        Icons.watch_rounded,
        const Color(0xFF22C55E),
      ),
    ];

    if (MediaQuery.of(context).size.width < 680) {
      return Column(
        children: stats
            .map(
              (stat) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: stat,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: List.generate(
        stats.length,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == stats.length - 1 ? 0 : 12),
            child: stats[index],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: kTextMuted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
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

  Widget _monthHeader(String month) {
    return Text(
      month,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _recordCard(_SleepHistoryRecord r) {
    final qualityColor = _qualityColor(r.durationHours);
    final sourceLabel = _sourceLabel(r.source);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openDetails(r),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: glassCardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(Icons.nights_stay_rounded, color: qualityColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEE, MMM d').format(r.start),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('HH:mm').format(r.start)} – ${DateFormat('HH:mm').format(r.end)}',
                          style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${r.durationHours.toStringAsFixed(1)} h',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _stageBar(r),
              const SizedBox(height: 14),
              Row(
                children: [
                  _pill(sourceLabel, kAccentBlue),
                  const SizedBox(width: 8),
                  _pill(_qualityLabel(r.durationHours), qualityColor),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white38,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageBar(_SleepHistoryRecord r) {
    if (r.stages.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: (r.durationHours / 9).clamp(0.0, 1.0),
          minHeight: 9,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: AlwaysStoppedAnimation<Color>(
            _qualityColor(r.durationHours),
          ),
        ),
      );
    }

    final totalMinutes = r.end.difference(r.start).inMinutes.clamp(1, 100000);
    final segments = r.stages.map((stage) {
      final s = _readDate(stage['start']);
      final e = _readDate(stage['end']);

      final minutes = s != null && e != null && e.isAfter(s)
          ? e.difference(s).inMinutes
          : 0;

      return _StageSegment(
        label: (stage['stage'] ?? 'unknown').toString(),
        fraction: (minutes / totalMinutes).clamp(0.03, 1.0),
      );
    }).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: segments.map((s) {
            return Expanded(
              flex: (s.fraction * 1000).round().clamp(1, 1000),
              child: Container(color: _stageColor(s.label)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassCardDecoration,
      child: const Column(
        children: [
          Icon(Icons.bedtime_off_rounded, color: kTextMuted, size: 42),
          SizedBox(height: 12),
          Text(
            'No sleep history yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Manual logs and smartwatch imports will appear here.',
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

  void _openDetails(_SleepHistoryRecord r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HistoryDetailSheet(record: r),
    );
  }

  Color _qualityColor(double hours) {
    if (hours >= 7 && hours <= 8.8) return const Color(0xFF22C55E);
    if (hours >= 6) return const Color(0xFFF59E0B);
    return const Color(0xFFF97316);
  }

  String _qualityLabel(double hours) {
    if (hours >= 7 && hours <= 8.8) return 'Good range';
    if (hours >= 6) return 'Almost there';
    return 'Low duration';
  }

  String _sourceLabel(String source) {
    if (source == 'manual_entry') return 'Manual';
    if (source == 'health_connect') return 'Health Connect';
    if (source == 'samsung_health') return 'Samsung Health';
    return 'Manual';
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  Color _stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'awake':
      case 'awake_in_bed':
      case 'out_of_bed':
        return const Color(0xFFF59E0B);
      case 'light':
        return const Color(0xFF60A5FA);
      case 'deep':
        return const Color(0xFF6D28D9);
      case 'rem':
        return const Color(0xFFC026D3);
      default:
        return Colors.white24;
    }
  }
}

class _HistoryDetailSheet extends StatelessWidget {
  final _SleepHistoryRecord record;

  const _HistoryDetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    final duration = record.end.difference(record.start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final durationText = '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    final screenWidth = MediaQuery.of(context).size.width;
    final stageSummaries = _stageSummaries();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth >= 820 ? 760 : double.infinity,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF120018),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 36,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _sheetHeader(durationText),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                        children: [
                          _detailGrid(context, durationText),
                          const SizedBox(height: 16),
                          if (stageSummaries.isNotEmpty) ...[
                            _sectionTitle('Sleep stages'),
                            const SizedBox(height: 10),
                            _stageSummaryBar(stageSummaries),
                            const SizedBox(height: 12),
                            ...stageSummaries.map(_stageSummaryCard),
                          ] else
                            _emptyStagesCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sheetHeader(String durationText) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF120018).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kBrand.withValues(alpha: 0.95),
                      kAccentBlue.withValues(alpha: 0.62),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kBrand.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.nights_stay_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(record.start),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('HH:mm').format(record.start)} – ${DateFormat('HH:mm').format(record.end)}',
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _durationBadge(durationText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durationBadge(String durationText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        durationText,
        style: const TextStyle(
          color: Color(0xFF86EFAC),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _detailGrid(BuildContext context, String durationText) {
    final isWide = MediaQuery.of(context).size.width >= 620;
    final cards = [
      _detailCard(
        icon: Icons.timer_rounded,
        label: 'Duration',
        value: durationText,
        color: const Color(0xFF22C55E),
      ),
      _detailCard(
        icon: Icons.schedule_rounded,
        label: 'Start',
        value: DateFormat('HH:mm').format(record.start),
        color: kAccentBlue,
      ),
      _detailCard(
        icon: Icons.wb_twilight_rounded,
        label: 'End',
        value: DateFormat('HH:mm').format(record.end),
        color: kBrand,
      ),
      _detailCard(
        icon: Icons.watch_rounded,
        label: 'Source',
        value: _sourceLabel(record.source),
        color: kAccentBlue,
      ),
    ];

    if (!isWide) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _sheetCardDecoration,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.stacked_bar_chart_rounded, color: kBrand, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _stageSummaryBar(List<_StageSummary> summaries) {
    final totalMinutes = _sessionMinutes();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _sheetCardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 14,
          child: Row(
            children: summaries
                .map(
                  (summary) => Expanded(
                    flex: ((summary.minutes / totalMinutes) * 1000)
                        .round()
                        .clamp(1, 1000),
                    child: Container(color: summary.color),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _stageSummaryCard(_StageSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: _sheetCardDecoration,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: summary.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(summary.icon, color: summary.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  summary.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _stageChip(summary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _minutesText(summary.minutes),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stageChip(_StageSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: summary.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: summary.color.withValues(alpha: 0.24)),
      ),
      child: Text(
        summary.label,
        style: TextStyle(
          color: summary.color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyStagesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _sheetCardDecoration,
      child: const Row(
        children: [
          Icon(Icons.bedtime_off_rounded, color: kTextMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No sleep stages were recorded for this session.',
              style: TextStyle(color: kTextSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  List<_StageSummary> _stageSummaries() {
    final totals = <_StageType, int>{
      for (final type in _StageType.values) type: 0,
    };

    for (final stage in record.stages) {
      final start = _readDate(stage['start']);
      final end = _readDate(stage['end']);

      if (start == null || end == null || !end.isAfter(start)) continue;

      final type = _stageType((stage['stage'] ?? 'unknown').toString());
      final minutes = end.difference(start).inMinutes;
      if (minutes <= 0) continue;

      totals[type] = (totals[type] ?? 0) + minutes;
    }

    final sessionMinutes = _sessionMinutes();

    return _StageType.values
        .map((type) {
          final minutes = totals[type] ?? 0;
          if (minutes <= 0) return null;

          return _StageSummary(
            type: type,
            label: _stageLabel(type),
            minutes: minutes,
            percent: (minutes / sessionMinutes) * 100,
            color: _stageColor(type),
            icon: _stageIcon(type),
          );
        })
        .whereType<_StageSummary>()
        .toList();
  }

  _StageType _stageType(String stage) {
    switch (stage.toLowerCase()) {
      case 'awake':
      case 'awake_in_bed':
      case 'out_of_bed':
        return _StageType.awake;
      case 'light':
        return _StageType.light;
      case 'deep':
        return _StageType.deep;
      case 'rem':
        return _StageType.rem;
      case 'sleeping':
      case 'unknown':
      default:
        return _StageType.other;
    }
  }

  String _stageLabel(_StageType type) {
    switch (type) {
      case _StageType.awake:
        return 'Awake';
      case _StageType.light:
        return 'Light';
      case _StageType.deep:
        return 'Deep';
      case _StageType.rem:
        return 'REM';
      case _StageType.other:
        return 'Other';
    }
  }

  Color _stageColor(_StageType type) {
    switch (type) {
      case _StageType.awake:
        return const Color(0xFFF59E0B);
      case _StageType.light:
        return kAccentBlue;
      case _StageType.deep:
        return const Color(0xFF8B5CF6);
      case _StageType.rem:
        return const Color(0xFFC026D3);
      case _StageType.other:
        return Colors.white54;
    }
  }

  IconData _stageIcon(_StageType type) {
    switch (type) {
      case _StageType.awake:
        return Icons.visibility_rounded;
      case _StageType.light:
        return Icons.nights_stay_outlined;
      case _StageType.deep:
        return Icons.dark_mode_rounded;
      case _StageType.rem:
        return Icons.auto_awesome_rounded;
      case _StageType.other:
        return Icons.bedtime_rounded;
    }
  }

  BoxDecoration get _sheetCardDecoration {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  int _sessionMinutes() {
    return record.end.difference(record.start).inMinutes.clamp(1, 100000);
  }

  String _minutesText(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _sourceLabel(String source) {
    if (source == 'manual_entry') return 'Manual';
    if (source == 'health_connect') return 'Health Connect';
    if (source == 'samsung_health') return 'Samsung Health';
    return 'Manual';
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

enum _StageType { awake, light, deep, rem, other }

class _StageSummary {
  final _StageType type;
  final String label;
  final int minutes;
  final double percent;
  final Color color;
  final IconData icon;

  const _StageSummary({
    required this.type,
    required this.label,
    required this.minutes,
    required this.percent,
    required this.color,
    required this.icon,
  });
}

class _SleepHistoryRecord {
  final String id;
  final DateTime start;
  final DateTime end;
  final double durationHours;
  final String source;
  final List<Map<String, dynamic>> stages;

  const _SleepHistoryRecord({
    required this.id,
    required this.start,
    required this.end,
    required this.durationHours,
    required this.source,
    required this.stages,
  });
}

class _StageSegment {
  final String label;
  final double fraction;

  const _StageSegment({required this.label, required this.fraction});
}
