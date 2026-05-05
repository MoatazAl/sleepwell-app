import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/ai_coach_service.dart';
import '../../theme.dart';
import '../../widgets/app_navbar.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _service = AiCoachService();

  AiCoachInputSummary? _summary;
  AiSleepReport? _report;
  _CoachNotice? _notice;
  bool _loadingSummary = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _service.loadInputSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loadingSummary = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notice = _CoachNotice.error(_messageFor(error));
        _loadingSummary = false;
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _generating = true;
      _notice = null;
    });

    try {
      final report = await _service.generateWeeklyReport();
      if (!mounted) return;
      setState(() {
        _report = report;
        _summary = report.inputSummary ?? _summary;
        _notice = report.isLocalFallback
            ? const _CoachNotice(
                icon: Icons.cloud_off_rounded,
                color: kAccentBlue,
                title: 'Gemini temporarily unavailable',
                body:
                    'Gemini is temporarily overloaded. Please try again in a minute.',
              )
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _notice = _noticeFor(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _messageFor(Object error) {
    if (error is AiCoachException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  _CoachNotice _noticeFor(Object error) {
    if (error is AiCoachMissingApiKeyException) {
      return const _CoachNotice(
        icon: Icons.key_rounded,
        color: kAccentBlue,
        title: 'Gemini API key not configured yet',
        body:
            'Add your Google AI Studio key in ai_coach_service.dart to enable plan generation.',
      );
    }
    if (error is AiCoachNoDataException) {
      return _CoachNotice.empty(error.message);
    }
    if (error is AiCoachGeminiUnavailableException) {
      return _CoachNotice.error(error.message);
    }
    return _CoachNotice.error(_messageFor(error));
  }

  @override
  Widget build(BuildContext context) {
    final activeSummary = _report?.inputSummary ?? _summary;

    return Scaffold(
      backgroundColor: kBackgroundBottom,
      appBar: const AppNavBar(current: NavSection.aiCoach),
      body: DecoratedBox(
        decoration: _coachBackground,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 18,
                  12,
                  isWide ? 32 : 18,
                  34,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroSection(
                            generating: _generating,
                            onGenerate: _generateReport,
                          ),
                          const SizedBox(height: 22),
                          _bodyContent(isWide, activeSummary),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bodyContent(bool isWide, AiCoachInputSummary? summary) {
    if (_generating) return const _LoadingReportPanel();

    final primary = Column(
      children: [
        if (_notice != null) ...[_NoticePanel(notice: _notice!)],
        if (_notice != null) const SizedBox(height: 18),
        if (_report != null)
          _ReportDashboard(report: _report!)
        else if (_loadingSummary)
          const _PreReportPanel.loading()
        else if (summary == null || !summary.hasSleepData)
          const _EmptyUnlockPanel()
        else
          _PreReportPanel(summary: summary),
      ],
    );

    final side = Column(
      children: [
        if (summary != null) ...[
          _DataUsedPanel(summary: summary),
          const SizedBox(height: 18),
        ],
        _ReportHistory(
          stream: _service.watchReportHistory(),
          onOpen: (report) {
            setState(() {
              _report = report;
              _summary = report.inputSummary ?? _summary;
              _notice = null;
            });
          },
        ),
      ],
    );

    if (!isWide) {
      return Column(children: [primary, const SizedBox(height: 18), side]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: primary),
        const SizedBox(width: 18),
        Expanded(flex: 4, child: side),
      ],
    );
  }
}

final BoxDecoration _coachBackground = BoxDecoration(
  gradient: LinearGradient(
    colors: [const Color(0xFF180729), kBackgroundTop, kBackgroundBottom],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

class _HeroSection extends StatelessWidget {
  final bool generating;
  final VoidCallback onGenerate;

  const _HeroSection({required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            kBrand.withValues(alpha: 0.12),
            kAccentBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
        boxShadow: [
          BoxShadow(
            color: kBrand.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;
          final copy = _HeroCopy(
            generating: generating,
            onGenerate: onGenerate,
          );

          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 24),
                const SizedBox(
                  width: double.infinity,
                  child: _IntelligenceBadge(),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              const SizedBox(width: 250, child: _IntelligenceBadge()),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final bool generating;
  final VoidCallback onGenerate;

  const _HeroCopy({required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _Pill(label: 'Personalized plan', color: kAccentBlue),
            _Pill(label: '7-day coaching', color: kBrand),
            _Pill(label: 'AI generated', color: Color(0xFF34D399)),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'AI Sleep Plan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 1.02,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'A personalized coaching plan built from your sleep patterns, assessments, and recent trends.',
          style: TextStyle(color: kTextSecondary, fontSize: 16, height: 1.55),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: generating ? null : onGenerate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF16051F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                generating ? 'Generating plan...' : 'Generate sleep plan',
              ),
            ),
            const Text(
              'Uses your recent sleep history and latest assessments.',
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntelligenceBadge extends StatelessWidget {
  const _IntelligenceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.black.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Container(
            width: 98,
            height: 98,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [kAccentBlue, Color(0xFF34D399), kBrand, kAccentBlue],
              ),
              boxShadow: [
                BoxShadow(
                  color: kAccentBlue.withValues(alpha: 0.26),
                  blurRadius: 34,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: const BoxDecoration(
                  color: Color(0xFF12051D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sleep intelligence',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Patterns, consistency, recovery signals, and assessment context.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ReportDashboard extends StatelessWidget {
  final AiSleepReport report;

  const _ReportDashboard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (report.isLocalFallback) ...[
          const _LocalFallbackBanner(),
          const SizedBox(height: 16),
        ],
        _MainInsightCard(report: report),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cards = [
              _InsightCard(
                label: 'Core pattern',
                title: 'Pattern to coach',
                body: report.corePattern,
                color: kAccentBlue,
              ),
              _InsightCard(
                label: 'Why this matters',
                title: 'The reason behind the plan',
                body: report.whyItMatters,
                color: kBrand,
              ),
            ];
            if (!isWide) {
              return Column(
                children: [cards[0], const SizedBox(height: 14), cards[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 14),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _RecommendationsSection(items: report.sevenDayPlan),
        const SizedBox(height: 16),
        _ExperimentCard(experiment: report.experiment),
        const SizedBox(height: 16),
        _EvidencePanel(items: report.dataEvidence),
        const SizedBox(height: 16),
        _AvoidThisWeekPanel(items: report.avoidThisWeek),
        const SizedBox(height: 16),
        _EncouragementCard(text: report.encouragement),
        const SizedBox(height: 16),
        _DisclaimerCard(text: report.disclaimer),
      ],
    );
  }
}

class _LocalFallbackBanner extends StatelessWidget {
  const _LocalFallbackBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: kAccentBlue.withValues(alpha: 0.08),
        border: Border.all(color: kAccentBlue.withValues(alpha: 0.18)),
      ),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt_rounded, color: kAccentBlue, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Generated locally because AI service was unavailable.',
              style: TextStyle(
                color: kTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainInsightCard extends StatelessWidget {
  final AiSleepReport report;

  const _MainInsightCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: _panelDecoration(
        borderColor: kAccentBlue.withValues(alpha: 0.18),
        glowColor: kAccentBlue.withValues(alpha: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week\'s Focus',
            style: const TextStyle(
              color: kAccentBlue,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.planTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.thisWeeksFocus,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String title;
  final String body;
  final Color color;

  const _InsightCard({
    required this.label,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(borderColor: color.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(label: label, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body.isEmpty ? 'Not enough detail returned.' : body,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsSection extends StatelessWidget {
  final List<DailyPlanAction> items;

  const _RecommendationsSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(
        borderColor: kBrand.withValues(alpha: 0.16),
        glowColor: kBrand.withValues(alpha: 0.09),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-Day Plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = List.generate(
                items.length,
                (index) => _RecommendationTile(
                  action: items[index],
                  isLast: index == items.length - 1,
                ),
              );
              return Column(children: cards);
            },
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final DailyPlanAction action;
  final bool isLast;

  const _RecommendationTile({required this.action, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [kAccentBlue, kBrand]),
                ),
                child: Center(
                  child: Text(
                    action.day.replaceAll('Day ', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.055),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.day,
                      style: const TextStyle(
                        color: kAccentBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.action,
                      style: const TextStyle(
                        color: kTextSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExperimentCard extends StatelessWidget {
  final PlanExperiment experiment;

  const _ExperimentCard({required this.experiment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(
        borderColor: const Color(0xFF34D399).withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Pill(label: 'Experiment to Try', color: Color(0xFF34D399)),
          const SizedBox(height: 14),
          Text(
            experiment.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            experiment.description,
            style: const TextStyle(color: kTextSecondary, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF34D399).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF34D399).withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFF34D399),
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    experiment.successMetric,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  final List<String> items;

  const _EvidencePanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return _ListPanel(
      title: 'Evidence from your data',
      icon: Icons.query_stats_rounded,
      color: kAccentBlue,
      items: items,
    );
  }
}

class _AvoidThisWeekPanel extends StatelessWidget {
  final List<String> items;

  const _AvoidThisWeekPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return _ListPanel(
      title: 'Avoid this week',
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFFFBBF24),
      items: items,
    );
  }
}

class _ListPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _ListPanel({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(borderColor: color.withValues(alpha: 0.16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((item) => _EvidenceChip(text: item, color: color))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EvidenceChip extends StatelessWidget {
  final String text;
  final Color color;

  const _EvidenceChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kTextSecondary,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EncouragementCard extends StatelessWidget {
  final String text;

  const _EncouragementCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(
        borderColor: const Color(0xFF34D399).withValues(alpha: 0.16),
        glowColor: const Color(0xFF34D399).withValues(alpha: 0.08),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_rounded, color: Color(0xFF34D399)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataUsedPanel extends StatelessWidget {
  final AiCoachInputSummary summary;

  const _DataUsedPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric('Avg 7 days', _hours(summary.avg7), kAccentBlue),
      _Metric('Avg 30 days', _hours(summary.avg30), kBrand),
      _Metric(
        'Tracked days',
        '${summary.trackedDays30}',
        const Color(0xFF34D399),
      ),
      _Metric(
        'Weekday avg',
        _hours(summary.weekdayAvg),
        const Color(0xFF93C5FD),
      ),
      _Metric(
        'Weekend avg',
        _hours(summary.weekendAvg),
        const Color(0xFFF0ABFC),
      ),
      _Metric('Trend', _trend(summary.trendDirection), const Color(0xFF34D399)),
      _Metric('Best night', _night(summary.bestNight), kAccentBlue),
      _Metric(
        'Worst night',
        _night(summary.worstNight),
        const Color(0xFFFBBF24),
      ),
      _Metric('Latest PSQI', _assessment(summary.latestPsqi), kBrand),
      _Metric(
        'Latest ESS',
        _assessment(summary.latestEss),
        const Color(0xFF38BDF8),
      ),
      _Metric(
        'Latest ISI',
        _assessment(summary.latestIsi),
        const Color(0xFF34D399),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data used',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'What the AI considered before writing your plan.',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map(
                  (metric) => _MetricChip(
                    label: metric.label,
                    value: metric.value,
                    color: metric.color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _hours(double? value) =>
      value == null ? 'No data' : '${value.toStringAsFixed(1)}h';

  String _night(NightSummary? night) {
    if (night == null) return 'No data';
    return '${night.hours.toStringAsFixed(1)}h';
  }

  String _assessment(AssessmentSummary? assessment) {
    if (assessment == null) return 'Missing';
    final score = assessment.score == null ? '--' : assessment.score.toString();
    return assessment.level == null ? score : '$score · ${assessment.level}';
  }

  String _trend(String value) {
    switch (value) {
      case 'improving':
        return 'Improving';
      case 'declining':
        return 'Lower';
      case 'stable':
        return 'Stable';
      default:
        return 'Sparse';
    }
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
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
          const SizedBox(height: 5),
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
    );
  }
}

class _ReportHistory extends StatelessWidget {
  final Stream<List<AiSleepReport>> stream;
  final ValueChanged<AiSleepReport> onOpen;

  const _ReportHistory({required this.stream, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AiSleepReport>>(
      stream: stream,
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <AiSleepReport>[];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Previous AI plans',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              if (reports.isEmpty)
                const Text(
                  'Generated plans will appear here.',
                  style: TextStyle(color: kTextMuted, height: 1.45),
                )
              else
                for (final report in reports.take(6)) ...[
                  _HistoryRow(report: report, onTap: () => onOpen(report)),
                  if (report != reports.take(6).last)
                    Divider(color: Colors.white.withValues(alpha: 0.08)),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final AiSleepReport report;
  final VoidCallback onTap;

  const _HistoryRow({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = report.createdAt == null
        ? 'Just now'
        : DateFormat('MMM d, yyyy').format(report.createdAt!);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: kAccentBlue.withValues(alpha: 0.10),
                border: Border.all(color: kAccentBlue.withValues(alpha: 0.16)),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: kAccentBlue,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.planTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: const TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: kTextMuted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreReportPanel extends StatelessWidget {
  final AiCoachInputSummary? summary;
  final bool loading;

  const _PreReportPanel({required this.summary}) : loading = false;
  const _PreReportPanel.loading() : summary = null, loading = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(
        borderColor: kBrand.withValues(alpha: 0.18),
        glowColor: kBrand.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(
            label: loading ? 'Syncing data' : 'Ready for analysis',
            color: loading ? kAccentBlue : const Color(0xFF34D399),
          ),
          const SizedBox(height: 18),
          Text(
            loading
                ? 'Preparing your sleep intelligence layer...'
                : 'Generate your weekly coaching plan when you are ready.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Loading recent sleep records and assessment results.'
                : 'The plan will use ${summary?.trackedDays30 ?? 0} tracked days, trend direction, weekday/weekend patterns, and assessment context.',
            style: const TextStyle(color: kTextSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _EmptyUnlockPanel extends StatelessWidget {
  const _EmptyUnlockPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(
        borderColor: kAccentBlue.withValues(alpha: 0.18),
        glowColor: kAccentBlue.withValues(alpha: 0.08),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(label: 'More data needed', color: kAccentBlue),
          SizedBox(height: 18),
          Text(
            'Track a few more nights to unlock richer AI guidance.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Completing at least one PSQI, ESS, or ISI assessment will make the weekly plan more personalized.',
            style: TextStyle(color: kTextSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _LoadingReportPanel extends StatefulWidget {
  const _LoadingReportPanel();

  @override
  State<_LoadingReportPanel> createState() => _LoadingReportPanelState();
}

class _LoadingReportPanelState extends State<_LoadingReportPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = 0.08 + (_controller.value * 0.08);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: _panelDecoration(
            borderColor: kAccentBlue.withValues(alpha: 0.16 + pulse),
            glowColor: kAccentBlue.withValues(alpha: pulse),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Pill(label: 'Generating intelligence', color: kAccentBlue),
              const SizedBox(height: 18),
              const Text(
                'Analyzing your recent sleep patterns...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reviewing consistency, recovery, weekday/weekend timing, and assessment context.',
                style: TextStyle(color: kTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              _GlowLine(widthFactor: 0.94, opacity: pulse + 0.08),
              const SizedBox(height: 12),
              _GlowLine(widthFactor: 0.72, opacity: pulse + 0.05),
              const SizedBox(height: 12),
              _GlowLine(widthFactor: 0.84, opacity: pulse + 0.02),
            ],
          ),
        );
      },
    );
  }
}

class _GlowLine extends StatelessWidget {
  final double widthFactor;
  final double opacity;

  const _GlowLine({required this.widthFactor, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: opacity),
              kAccentBlue.withValues(alpha: opacity + 0.06),
              kBrand.withValues(alpha: opacity),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticePanel extends StatelessWidget {
  final _CoachNotice notice;

  const _NoticePanel({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(
        borderColor: notice.color.withValues(alpha: 0.20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: notice.color.withValues(alpha: 0.12),
              border: Border.all(color: notice.color.withValues(alpha: 0.20)),
            ),
            child: Icon(notice.icon, color: notice.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notice.body,
                  style: const TextStyle(color: kTextSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final String text;

  const _DisclaimerCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final displayText = text.trim().isEmpty
        ? 'AI guidance is educational and supportive. It is not medical advice.'
        : text;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        displayText,
        style: const TextStyle(color: kTextMuted, height: 1.45, fontSize: 12),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration({Color? borderColor, Color? glowColor}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    color: Colors.white.withValues(alpha: 0.065),
    border: Border.all(
      color: borderColor ?? Colors.white.withValues(alpha: 0.09),
    ),
    boxShadow: [
      BoxShadow(
        color: glowColor ?? Colors.black.withValues(alpha: 0.28),
        blurRadius: glowColor == null ? 28 : 36,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.24),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _CoachNotice {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _CoachNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  const _CoachNotice.empty(this.body)
    : icon = Icons.nights_stay_rounded,
      color = kAccentBlue,
      title = 'Richer guidance is almost ready';

  const _CoachNotice.error(this.body)
    : icon = Icons.error_outline_rounded,
      color = const Color(0xFFFBBF24),
      title = 'Could not generate report';
}

class _Metric {
  final String label;
  final String value;
  final Color color;

  const _Metric(this.label, this.value, this.color);
}
