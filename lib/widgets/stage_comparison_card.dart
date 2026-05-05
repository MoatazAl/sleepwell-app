import 'package:flutter/material.dart';
import '../data/sleep_stage_ranges.dart';

class StageComparisonCard extends StatelessWidget {
  final String stageKey;
  final Color stageColor;
  final double userPercent;

  const StageComparisonCard({
    super.key,
    required this.stageKey,
    required this.stageColor,
    required this.userPercent,
  });

  @override
  Widget build(BuildContext context) {
    final range = stageRanges[stageKey];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A061F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compared to typical range',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),

          // USER BAR
          _Bar(label: 'Your sleep', percent: userPercent, color: stageColor),

          const SizedBox(height: 16),

          // REFERENCE RANGE BAR
          if (range != null)
            _RangeBar(min: range.min, max: range.max, color: stageColor),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _Bar({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label • ${percent.toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
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

  const _RangeBar({required this.min, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Typical range • ${min.toInt()}–${max.toInt()}%',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Positioned(
              left: min / 100 * MediaQuery.of(context).size.width * 0.7,
              child: Container(
                width:
                    (max - min) / 100 * MediaQuery.of(context).size.width * 0.7,
                height: 10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
