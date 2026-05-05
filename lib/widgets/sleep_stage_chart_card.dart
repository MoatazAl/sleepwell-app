import 'package:flutter/material.dart';
import '../models/sleep_stage_info.dart';

class SleepStageChartCard extends StatelessWidget {
  final SleepStageType highlightedStage;

  const SleepStageChartCard({super.key, required this.highlightedStage});

  @override
  Widget build(BuildContext context) {
    final segments = <_StageSegment>[
      _StageSegment(SleepStageType.light, 0.14),
      _StageSegment(SleepStageType.deep, 0.18),
      _StageSegment(SleepStageType.light, 0.12),
      _StageSegment(SleepStageType.rem, 0.10),
      _StageSegment(SleepStageType.light, 0.13),
      _StageSegment(SleepStageType.deep, 0.11),
      _StageSegment(SleepStageType.light, 0.09),
      _StageSegment(SleepStageType.rem, 0.13),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Stage Pattern',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Selected stage is highlighted in the timeline below.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: segments.map((segment) {
                final isHighlighted = segment.stage == highlightedStage;
                final height = _heightForStage(segment.stage);

                return Expanded(
                  flex: (segment.widthFactor * 100).toInt(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: height,
                      decoration: BoxDecoration(
                        color: _stageColor(
                          segment.stage,
                        ).withValues(alpha: isHighlighted ? 1.0 : 0.22),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isHighlighted
                            ? [
                                BoxShadow(
                                  color: _stageColor(
                                    segment.stage,
                                  ).withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                        border: Border.all(
                          color: isHighlighted
                              ? Colors.white.withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.05),
                          width: isHighlighted ? 1.4 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: SleepStageType.values.map((stage) {
              final isActive = stage == highlightedStage;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _stageColor(
                    stage,
                  ).withValues(alpha: isActive ? 0.20 : 0.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isActive
                        ? _stageColor(stage).withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: _stageColor(stage),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _label(stage),
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  double _heightForStage(SleepStageType stage) {
    switch (stage) {
      case SleepStageType.awake:
        return 118;
      case SleepStageType.rem:
        return 92;
      case SleepStageType.light:
        return 74;
      case SleepStageType.deep:
        return 48;
    }
  }

  String _label(SleepStageType stage) {
    switch (stage) {
      case SleepStageType.deep:
        return 'Deep';
      case SleepStageType.light:
        return 'Light';
      case SleepStageType.rem:
        return 'REM';
      case SleepStageType.awake:
        return 'Awake';
    }
  }

  Color _stageColor(SleepStageType stage) {
    switch (stage) {
      case SleepStageType.deep:
        return const Color(0xFF5B8CFF);
      case SleepStageType.light:
        return const Color(0xFF8E7CFF);
      case SleepStageType.rem:
        return const Color(0xFFFF6FAE);
      case SleepStageType.awake:
        return const Color(0xFFFFB454);
    }
  }
}

class _StageSegment {
  final SleepStageType stage;
  final double widthFactor;

  _StageSegment(this.stage, this.widthFactor);
}
