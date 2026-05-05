class SleepStageRange {
  final double min;
  final double max;

  const SleepStageRange(this.min, this.max);
}

const Map<String, SleepStageRange> stageRanges = {
  'rem': SleepStageRange(20, 25),
  'deep': SleepStageRange(10, 20),
  'light': SleepStageRange(40, 60), // combined light sleep (N1+N2)
  // awake intentionally excluded (not a target stage)
};