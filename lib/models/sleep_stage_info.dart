enum SleepStageType {
  deep,
  light,
  rem,
  awake,
}

class SleepStageInfo {
  final SleepStageType type;
  final String title;
  final String subtitle;
  final String description;
  final List<String> benefits;
  final List<String> factors;
  final String tip;

  const SleepStageInfo({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.benefits,
    required this.factors,
    required this.tip,
  });
}