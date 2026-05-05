import 'package:flutter/material.dart';
import '../../data/sleep_stage_ranges.dart';

class SleepStageDetailScreen extends StatelessWidget {
  final String stageKey;
  final String stageLabel;
  final Color stageColor;
  final double minutes;
  final Map<String, double> totals;

  const SleepStageDetailScreen({
    super.key,
    required this.stageKey,
    required this.stageLabel,
    required this.stageColor,
    required this.minutes,
    required this.totals,
  });

  StageStatus _getStatus(double value, SleepStageRange? range, String stageKey) {
    if (range == null) {
      return const StageStatus(
        label: 'No reference range',
        tip: 'This stage does not use a standard target range.',
        color: Colors.grey,
      );
    }

    if (value < range.min) {
      return StageStatus(
        label: 'Below optimal',
        tip: _getImprovementTip(stageKey),
        color: const Color(0xFFF59E0B),
      );
    }

    if (value > range.max) {
      return StageStatus(
        label: 'Above typical',
        tip: _getAboveRangeTip(stageKey),
        color: const Color(0xFF60A5FA),
      );
    }

    return StageStatus(
      label: 'Within optimal range',
      tip: _getWithinRangeTip(stageKey),
      color: const Color(0xFF22C55E),
    );
  }

  String _getImprovementTip(String stageKey) {
    switch (stageKey) {
      case 'rem':
        return 'REM tends to increase later in the night. Sleeping longer can help improve it.';
      case 'deep':
        return 'Deep sleep benefits from a consistent schedule and fewer late-night disruptions. Avoid late caffeine and protect your sleep window.';
      case 'light':
        return 'Frequent interruptions can keep sleep lighter. Improving sleep continuity may help balance your sleep structure.';
      case 'awake':
        return 'Reducing noise, light, stress, and late stimulation may help lower awake time during the night.';
      default:
        return 'Improving sleep consistency is a good next step.';
    }
  }

  String _getAboveRangeTip(String stageKey) {
    switch (stageKey) {
      case 'rem':
        return 'A slightly higher REM share can happen naturally. Focus on overall sleep quality and consistency rather than pushing this stage further.';
      case 'deep':
        return 'A higher deep sleep share may reflect recovery or sleep need. Keep your routine steady and watch for how rested you feel.';
      case 'light':
        return 'A higher light sleep share may happen when deeper stages are reduced. Better continuity and enough total sleep may help rebalance things.';
      case 'awake':
        return 'More awake time than usual may suggest fragmented sleep. Try improving your sleep environment and evening routine.';
      default:
        return 'Keep focusing on stable, sufficient sleep.';
    }
  }

  String _getWithinRangeTip(String stageKey) {
    switch (stageKey) {
      case 'rem':
        return 'Your REM sleep appears to be in a healthy range. The goal now is keeping enough total sleep to preserve it.';
      case 'deep':
        return 'Your deep sleep appears balanced. Keeping a steady routine can help maintain this.';
      case 'light':
        return 'Your light sleep looks balanced within common patterns.';
      case 'awake':
        return 'Your awake time does not stand out as a major issue in this session.';
      default:
        return 'This stage appears balanced within common patterns.';
    }
  }

  _StageContent _stageInfo(String key) {
    switch (key) {
      case 'awake':
        return const _StageContent(
          subtitle: 'Night-time interruptions and wake periods',
          description:
              'Awake time represents moments when you were not asleep during the night. Short awakenings can be normal, but frequent or long awake periods may reduce sleep continuity and make sleep feel less restorative.',
          whyItMatters: [
            'Helps reveal interrupted or fragmented sleep',
            'Too much awake time may reduce restfulness',
            'Can point to habits or environmental disruption',
          ],
          affectsIt: [
            'Stress and anxiety',
            'Noise, light, or temperature changes',
            'Caffeine late in the day',
          ],
          tip:
              'Reducing night-time interruptions can improve overall sleep continuity.',
        );

      case 'light':
        return const _StageContent(
          subtitle: 'Core sleep flow across the night',
          description:
              'Light sleep makes up a large share of the night and acts as the bridge between wakefulness, deep sleep, and REM sleep. It helps maintain a stable sleep cycle and supports overall sleep continuity.',
          whyItMatters: [
            'Supports normal sleep cycling',
            'Helps transitions between stages',
            'Contributes to steady, continuous sleep',
          ],
          affectsIt: [
            'Frequent interruptions',
            'Stress and poor sleep routines',
            'Irregular bedtimes',
          ],
          tip:
              'Stable bedtimes and fewer interruptions can improve sleep continuity.',
        );

      case 'deep':
        return const _StageContent(
          subtitle: 'Physical restoration and body recovery',
          description:
              'Deep sleep is the most restorative non-REM sleep stage. During this phase, the body relaxes deeply and important recovery processes take place. Deep sleep is commonly associated with physical restoration and waking up more refreshed.',
          whyItMatters: [
            'Supports physical recovery',
            'Helps the body restore and recharge',
            'Contributes to feeling more rested',
          ],
          affectsIt: [
            'Short sleep duration',
            'Alcohol late at night',
            'Irregular sleep timing',
          ],
          tip:
              'Protecting enough total sleep time helps preserve better deep sleep opportunity.',
        );

      case 'rem':
        return const _StageContent(
          subtitle: 'Dream-rich sleep linked to memory and emotion',
          description:
              'REM sleep is strongly associated with dreaming, emotional processing, and memory consolidation. REM periods usually become longer later in the night, which means short sleep can reduce REM opportunity.',
          whyItMatters: [
            'Supports memory and learning',
            'Helps emotional processing',
            'Important for cognitive recovery',
          ],
          affectsIt: [
            'Sleeping too little',
            'Stress',
            'Alcohol and inconsistent routines',
          ],
          tip:
              'Getting enough total sleep is one of the best ways to protect REM sleep.',
        );

      default:
        return const _StageContent(
          subtitle: 'Sleep stage information',
          description: 'This stage is part of your overnight sleep structure.',
          whyItMatters: [
            'Helps understand overall sleep quality',
          ],
          affectsIt: [
            'Sleep duration and sleep routine',
          ],
          tip: 'Consistent sleep habits improve overall sleep patterns.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalMinutes =
        totals.values.fold<double>(0.0, (a, b) => a + b);

    final double percent = totalMinutes > 0
        ? (minutes / totalMinutes) * 100.0
        : 0.0;

    final SleepStageRange? range = stageRanges[stageKey];
    final StageStatus status = _getStatus(percent, range, stageKey);
    final _StageContent info = _stageInfo(stageKey);

    return Scaffold(
      backgroundColor: const Color(0xFF140018),
      appBar: AppBar(
        backgroundColor: const Color(0xFF140018),
        elevation: 0,
        title: Text(stageLabel),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(
              stageLabel: stageLabel,
              stageColor: stageColor,
              subtitle: info.subtitle,
              minutes: minutes,
              percent: percent,
            ),
            const SizedBox(height: 16),
            _ComparisonCard(
              stageKey: stageKey,
              stageColor: stageColor,
              percent: percent,
              status: status,
            ),
            const SizedBox(height: 16),
            _StageGraphCard(
              highlightedStage: stageKey,
              totals: totals,
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'What this stage means',
              child: Text(
                info.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _BulletCard(
              title: 'Why it matters',
              items: info.whyItMatters,
            ),
            const SizedBox(height: 16),
            _BulletCard(
              title: 'What can affect it',
              items: info.affectsIt,
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'How to improve',
              child: Text(
                status.tip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'SleepWell note',
              child: Text(
                info.tip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StageStatus {
  final String label;
  final String tip;
  final Color color;

  const StageStatus({
    required this.label,
    required this.tip,
    required this.color,
  });
}

class _HeroCard extends StatelessWidget {
  final String stageLabel;
  final Color stageColor;
  final String subtitle;
  final double minutes;
  final double percent;

  const _HeroCard({
    required this.stageLabel,
    required this.stageColor,
    required this.subtitle,
    required this.minutes,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            stageColor.withValues(alpha: 0.24),
            const Color(0xFF1B0823),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stageLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${minutes.round()}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${percent.toStringAsFixed(0)}% of tracked stages',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final String stageKey;
  final Color stageColor;
  final double percent;
  final StageStatus status;

  const _ComparisonCard({
    required this.stageKey,
    required this.stageColor,
    required this.percent,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final SleepStageRange? range = stageRanges[stageKey];

    return _InfoCard(
      title: 'Compared to typical range',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: status.color.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status.tip,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _ProgressBar(
            label: 'Your sleep',
            percent: percent,
            color: stageColor,
          ),
          const SizedBox(height: 14),
          if (range != null)
            _RangeBar(
              min: range.min,
              max: range.max,
              color: status.color,
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _ProgressBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double normalized = (percent / 100.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label • ${percent.toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  final double min;
  final double max;
  final Color color;

  const _RangeBar({
    required this.min,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'Typical adult range: ${min.toInt()}–${max.toInt()}%',
      style: TextStyle(
        color: color.withValues(alpha: 0.95),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StageGraphCard extends StatelessWidget {
  final String highlightedStage;
  final Map<String, double> totals;

  const _StageGraphCard({
    required this.highlightedStage,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    final orderedStages = [
      ('awake', const Color(0xFFF59E0B), 'Awake'),
      ('light', const Color(0xFF60A5FA), 'Light'),
      ('deep', const Color(0xFF4338CA), 'Deep'),
      ('rem', const Color(0xFF8B5CF6), 'REM'),
      ('sleeping', const Color(0xFF7C3AED), 'Sleep'),
    ];

    final double totalMinutes =
        totals.values.fold<double>(0.0, (a, b) => a + b);

    final visible = orderedStages
        .where((item) => (totals[item.$1] ?? 0.0) > 0)
        .toList();

    return _InfoCard(
      title: 'Sleep Stage Pattern',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 18,
              child: Row(
                children: visible.map((item) {
                  final double minutes = (totals[item.$1] ?? 0.0).toDouble();
                  final double fraction = totalMinutes > 0
                      ? minutes / totalMinutes
                      : 0.0;
                  final bool isActive = item.$1 == highlightedStage;

                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: isActive
                            ? item.$2
                            : item.$2.withValues(alpha: 0.25),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: item.$2.withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: visible.map((item) {
              final bool isActive = item.$1 == highlightedStage;
              final double minutes = (totals[item.$1] ?? 0.0).toDouble();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? item.$2.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive
                        ? item.$2.withValues(alpha: 0.80)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  '${item.$3} ${minutes.round()}m',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A061F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: title,
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StageContent {
  final String subtitle;
  final String description;
  final List<String> whyItMatters;
  final List<String> affectsIt;
  final String tip;

  const _StageContent({
    required this.subtitle,
    required this.description,
    required this.whyItMatters,
    required this.affectsIt,
    required this.tip,
  });
}