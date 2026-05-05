import 'package:flutter/material.dart';

import '../data/questionnaire_data.dart';

class QuestionnaireOption {
  final String text;
  final int score;

  const QuestionnaireOption({
    required this.text,
    required this.score,
  });
}

class QuestionnaireQuestion {
  final String text;
  final List<QuestionnaireOption> options;

  const QuestionnaireQuestion({
    required this.text,
    required this.options,
  });
}

class ScoreComponent {
  final String label;
  final int score;
  final int maxScore;
  final String explanation;

  const ScoreComponent({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'score': score,
      'maxScore': maxScore,
      'explanation': explanation,
    };
  }
}

class QuestionnaireDefinition {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<QuestionnaireQuestion> questions;

  const QuestionnaireDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.questions,
  });
}

class QuestionnaireResult {
  final String type;
  final int score;
  final int maxScore;
  final String level;
  final String message;
  final Color color;
  final List<String> actions;
  final List<ScoreComponent> components;

  const QuestionnaireResult({
    required this.type,
    required this.score,
    required this.maxScore,
    required this.level,
    required this.message,
    required this.color,
    required this.actions,
    required this.components,
  });
}

QuestionnaireDefinition questionnaireByType(String type) {
  switch (type) {
    case 'ISI':
      return QuestionnaireDefinition(
        type: 'ISI',
        title: 'Insomnia Severity',
        subtitle: 'A validated 7-item insomnia severity screen.',
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFFF59E0B),
        questions: isiQuestions,
      );

    case 'PSQI':
      return QuestionnaireDefinition(
        type: 'PSQI',
        title: 'Sleep Quality',
        subtitle: 'PSQI-style sleep-quality component screening.',
        icon: Icons.bedtime_rounded,
        color: const Color(0xFF22C55E),
        questions: psqiQuestions,
      );

    case 'ESS':
    default:
      return QuestionnaireDefinition(
        type: 'ESS',
        title: 'Daytime Sleepiness',
        subtitle: 'A validated 8-item daytime sleepiness scale.',
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFF8B5CF6),
        questions: essQuestions,
      );
  }
}

QuestionnaireResult scoreQuestionnaire({
  required String type,
  required List<int> answers,
}) {
  switch (type) {
    case 'ISI':
      return _scoreIsi(answers);
    case 'PSQI':
      return _scorePsqiStyle(answers);
    case 'ESS':
    default:
      return _scoreEss(answers);
  }
}

QuestionnaireResult _scoreEss(List<int> answers) {
  final score = answers.fold<int>(0, (sum, value) => sum + value);

  final components = <ScoreComponent>[
    for (int i = 0; i < answers.length; i++)
      ScoreComponent(
        label: essQuestions[i].text,
        score: answers[i],
        maxScore: 3,
        explanation: _essExplain(answers[i]),
      ),
  ];

  if (score <= 10) {
    return QuestionnaireResult(
      type: 'ESS',
      score: score,
      maxScore: 24,
      level: 'Normal daytime sleepiness',
      color: const Color(0xFF22C55E),
      message:
          'Your answers suggest daytime sleepiness is within a normal range.',
      actions: const [
        'Keep tracking your sleep regularly',
        'Maintain a consistent wake time',
        'Watch for changes in daytime energy',
      ],
      components: components,
    );
  }

  if (score <= 12) {
    return QuestionnaireResult(
      type: 'ESS',
      score: score,
      maxScore: 24,
      level: 'Mild excessive daytime sleepiness',
      color: const Color(0xFFF59E0B),
      message:
          'Your answers suggest mild excessive daytime sleepiness.',
      actions: const [
        'Review your weekly sleep duration',
        'Avoid late caffeine',
        'Keep a regular sleep schedule',
      ],
      components: components,
    );
  }

  if (score <= 15) {
    return QuestionnaireResult(
      type: 'ESS',
      score: score,
      maxScore: 24,
      level: 'Moderate excessive daytime sleepiness',
      color: const Color(0xFFF97316),
      message:
          'Your answers suggest noticeable daytime sleepiness that may affect focus and energy.',
      actions: const [
        'Prioritize sleep duration this week',
        'Avoid driving when very sleepy',
        'Consider professional advice if this persists',
      ],
      components: components,
    );
  }

  return QuestionnaireResult(
    type: 'ESS',
    score: score,
    maxScore: 24,
    level: 'Severe excessive daytime sleepiness',
    color: const Color(0xFFEF4444),
    message:
        'Your answers suggest high daytime sleepiness. This deserves attention if frequent.',
    actions: const [
      'Avoid driving when sleepy',
      'Track sleep for the next 7 nights',
      'Consider professional medical advice',
    ],
    components: components,
  );
}

QuestionnaireResult _scoreIsi(List<int> answers) {
  final score = answers.fold<int>(0, (sum, value) => sum + value);

  final labels = const [
    'Sleep onset',
    'Sleep maintenance',
    'Early awakening',
    'Sleep satisfaction',
    'Noticeability',
    'Worry / distress',
    'Daytime impact',
  ];

  final components = <ScoreComponent>[
    for (int i = 0; i < answers.length; i++)
      ScoreComponent(
        label: labels[i],
        score: answers[i],
        maxScore: 4,
        explanation: _severityExplain(answers[i]),
      ),
  ];

  if (score <= 7) {
    return QuestionnaireResult(
      type: 'ISI',
      score: score,
      maxScore: 28,
      level: 'No clinically significant insomnia',
      color: const Color(0xFF22C55E),
      message:
          'Your answers do not suggest clinically significant insomnia symptoms right now.',
      actions: const [
        'Keep your current routine stable',
        'Protect your bedtime schedule',
        'Continue monitoring changes',
      ],
      components: components,
    );
  }

  if (score <= 14) {
    return QuestionnaireResult(
      type: 'ISI',
      score: score,
      maxScore: 28,
      level: 'Subthreshold insomnia',
      color: const Color(0xFFF59E0B),
      message:
          'Your answers suggest some insomnia-like symptoms that may benefit from routine improvements.',
      actions: const [
        'Keep bedtime and wake time consistent',
        'Avoid lying awake in bed for long periods',
        'Use Sleep Coach habits section',
      ],
      components: components,
    );
  }

  if (score <= 21) {
    return QuestionnaireResult(
      type: 'ISI',
      score: score,
      maxScore: 28,
      level: 'Moderate insomnia symptoms',
      color: const Color(0xFFF97316),
      message:
          'Your answers suggest moderate insomnia symptoms. Persistent symptoms should be taken seriously.',
      actions: const [
        'Reduce late screens and caffeine',
        'Create a 30-minute wind-down routine',
        'Consider professional guidance if symptoms continue',
      ],
      components: components,
    );
  }

  return QuestionnaireResult(
    type: 'ISI',
    score: score,
    maxScore: 28,
    level: 'Severe insomnia symptoms',
    color: const Color(0xFFEF4444),
    message:
        'Your answers suggest severe insomnia symptoms. Consider discussing this with a qualified professional.',
    actions: const [
      'Do not rely only on self-tracking',
      'Seek professional medical guidance',
      'Use SleepWell to document your pattern clearly',
    ],
    components: components,
  );
}

QuestionnaireResult _scorePsqiStyle(List<int> answers) {
  final score = answers.fold<int>(0, (sum, value) => sum + value);

  const labels = [
    'Subjective sleep quality',
    'Sleep latency',
    'Night waking',
    'Early waking',
    'Sleep environment disturbance',
    'Daytime dysfunction',
    'Low enthusiasm',
  ];

  final components = <ScoreComponent>[
    for (int i = 0; i < answers.length; i++)
      ScoreComponent(
        label: labels[i],
        score: answers[i],
        maxScore: 3,
        explanation: _psqiExplain(answers[i]),
      ),
  ];

  if (score <= 5) {
    return QuestionnaireResult(
      type: 'PSQI',
      score: score,
      maxScore: 21,
      level: 'Good sleep quality',
      color: const Color(0xFF22C55E),
      message:
          'Your answers suggest your sleep quality is currently in a good range.',
      actions: const [
        'Keep your routine stable',
        'Continue tracking your nights',
        'Watch for sudden changes',
      ],
      components: components,
    );
  }

  if (score <= 10) {
    return QuestionnaireResult(
      type: 'PSQI',
      score: score,
      maxScore: 21,
      level: 'Sleep quality may need attention',
      color: const Color(0xFFF59E0B),
      message:
          'Your answers suggest some sleep-quality concerns. The breakdown below shows what contributed most.',
      actions: const [
        'Review your sleep schedule',
        'Improve your sleep environment',
        'Track sleep for at least 7 nights',
      ],
      components: components,
    );
  }

  return QuestionnaireResult(
    type: 'PSQI',
    score: score,
    maxScore: 21,
    level: 'Poor sleep quality indicators',
    color: const Color(0xFFF97316),
    message:
        'Your answers suggest several poor sleep-quality indicators. SleepWell can help identify what may be contributing.',
    actions: const [
      'Start with consistency and sleep duration',
      'Review habits and environment',
      'Consider professional advice if this persists',
    ],
    components: components,
  );
}

String _essExplain(int score) {
  switch (score) {
    case 0:
      return 'No chance of accidentally falling asleep in this situation.';
    case 1:
      return 'Slight chance of accidentally falling asleep.';
    case 2:
      return 'Moderate chance of accidentally falling asleep.';
    default:
      return 'High chance of accidentally falling asleep.';
  }
}

String _severityExplain(int score) {
  switch (score) {
    case 0:
      return 'No reported problem in this area.';
    case 1:
      return 'Mild difficulty reported.';
    case 2:
      return 'Moderate difficulty reported.';
    case 3:
      return 'Severe difficulty reported.';
    default:
      return 'Very severe difficulty reported.';
  }
}

String _psqiExplain(int score) {
  switch (score) {
    case 0:
      return 'No concern reported for this component.';
    case 1:
      return 'Low concern reported for this component.';
    case 2:
      return 'Moderate concern reported for this component.';
    default:
      return 'High concern reported for this component.';
  }
}