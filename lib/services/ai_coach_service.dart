import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// Configure Gemini without committing a key:
// flutter run -d chrome --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
//
// Keep real keys out of source control. For production, prefer calling Gemini
// through a backend proxy so the key is never shipped inside the app bundle.
const String kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String kGeminiModel = 'gemini-2.5-flash';
const String kLocalFallbackModel = 'local-fallback';

class AiCoachService {
  AiCoachService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? client,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _client = client ?? http.Client();

  static const _model = kGeminiModel;
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static const _maxGeminiAttempts = 3;
  static const _retryableStatuses = {429, 500, 503, 504};
  static const _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _client;

  void dispose() => _client.close();

  Future<AiCoachInputSummary> loadInputSummary() async {
    final user = _auth.currentUser;
    if (user == null) throw const AiCoachException('User not signed in.');
    return _buildInputSummary(user.uid);
  }

  Stream<List<AiSleepReport>> watchReportHistory({int limit = 8}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const []);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('ai_reports')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => AiSleepReport.fromFirestore(doc)).toList(),
        );
  }

  Future<AiSleepReport> generateWeeklyReport() async {
    final user = _auth.currentUser;
    if (user == null) throw const AiCoachException('User not signed in.');

    final input = await _buildInputSummary(user.uid);
    if (!input.hasSleepData) {
      throw const AiCoachNoDataException(
        'Track a few more nights and complete at least one assessment to unlock richer AI guidance.',
      );
    }

    if (!_hasGeminiKey) {
      throw const AiCoachMissingApiKeyException(
        'Gemini API key not configured yet.',
      );
    }

    AiSleepReport report;
    try {
      report = await _requestGeminiReport(input);
    } on AiCoachGeminiUnavailableException {
      report = _buildLocalFallbackReport(input);
    }

    final saved = report.copyWith(inputSummary: input);
    await _saveReport(user.uid, saved);
    return saved;
  }

  bool get _hasGeminiKey => kGeminiApiKey.isNotEmpty;

  Future<AiCoachInputSummary> _buildInputSummary(String uid) async {
    final now = DateTime.now();
    final since30 = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));

    final sleepSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('sleep_records')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(since30))
        .orderBy('start', descending: true)
        .get();

    final dailyTotals = <String, _DailySleep>{};

    for (final doc in sleepSnap.docs) {
      final data = doc.data();
      final start = _readDate(data['start']);
      final end = _readDate(data['end']);
      if (start == null || end == null || !end.isAfter(start)) continue;

      final hours =
          (data['durationHours'] as num?)?.toDouble() ??
          end.difference(start).inMinutes / 60.0;
      if (hours <= 0) continue;

      final day = DateTime(start.year, start.month, start.day);
      final key = DateFormat('yyyy-MM-dd').format(day);
      dailyTotals.update(
        key,
        (existing) => existing.copyWith(hours: existing.hours + hours),
        ifAbsent: () => _DailySleep(date: day, hours: hours),
      );
    }

    final days = dailyTotals.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final assessments = await _latestAssessments(uid);
    final average7 = _averageForWindow(days, now, 7);
    final average30 = _average(days.map((day) => day.hours));
    final weekdayAverage = _average(
      days.where((day) => !_isWeekend(day.date)).map((day) => day.hours),
    );
    final weekendAverage = _average(
      days.where((day) => _isWeekend(day.date)).map((day) => day.hours),
    );
    final bestNight = _extremeNight(days, best: true);
    final worstNight = _extremeNight(days, best: false);

    return AiCoachInputSummary(
      avg7: average7,
      avg30: average30,
      trackedDays30: days.length,
      weekdayAvg: weekdayAverage,
      weekendAvg: weekendAverage,
      trendDirection: _trendDirection(average7, average30),
      bestNight: bestNight,
      worstNight: worstNight,
      latestPsqi: assessments['PSQI'],
      latestEss: assessments['ESS'],
      latestIsi: assessments['ISI'],
    );
  }

  DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<Map<String, AssessmentSummary?>> _latestAssessments(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('assessments')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    final latest = <String, AssessmentSummary?>{
      'PSQI': null,
      'ESS': null,
      'ISI': null,
    };

    for (final doc in snap.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toUpperCase();
      if (!latest.containsKey(type) || latest[type] != null) continue;

      latest[type] = AssessmentSummary(
        type: type,
        score: (data['score'] as num?)?.toInt(),
        level: data['level']?.toString(),
        createdAt: _readDate(data['createdAt']),
      );
    }

    return latest;
  }

  double? _averageForWindow(List<_DailySleep> days, DateTime now, int window) {
    final today = DateTime(now.year, now.month, now.day);
    final since = today.subtract(Duration(days: window - 1));
    return _average(
      days
          .where((day) => !day.date.isBefore(since) && !day.date.isAfter(today))
          .map((day) => day.hours),
    );
  }

  double? _average(Iterable<double> values) {
    final list = values.where((value) => value > 0).toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  bool _isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  NightSummary? _extremeNight(List<_DailySleep> days, {required bool best}) {
    if (days.isEmpty) return null;
    final sorted = [...days]
      ..sort(
        (a, b) =>
            best ? b.hours.compareTo(a.hours) : a.hours.compareTo(b.hours),
      );
    return NightSummary(date: sorted.first.date, hours: sorted.first.hours);
  }

  String _trendDirection(double? avg7, double? avg30) {
    if (avg7 == null || avg30 == null) return 'not_enough_data';
    final diff = avg7 - avg30;
    if (diff >= 0.5) return 'improving';
    if (diff <= -0.5) return 'declining';
    return 'stable';
  }

  Future<AiSleepReport> _requestGeminiReport(AiCoachInputSummary input) async {
    for (var attempt = 0; attempt < _maxGeminiAttempts; attempt++) {
      late final http.Response response;

      try {
        response = await _client.post(
          Uri.parse(_endpoint),
          headers: const {
            'Content-Type': 'application/json',
            'x-goog-api-key': kGeminiApiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': _buildPrompt(input)},
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.32,
              'responseMimeType': 'application/json',
              'responseJsonSchema': _reportSchema,
            },
          }),
        );
      } on http.ClientException {
        throw const AiCoachGeminiUnavailableException();
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseGeminiReport(response);
      }

      if (!_shouldRetry(response.statusCode)) {
        throw AiCoachException(
          'Gemini request failed (${response.statusCode}).',
        );
      }

      await Future<void>.delayed(_retryDelays[attempt]);
    }

    throw const AiCoachGeminiUnavailableException();
  }

  AiSleepReport _parseGeminiReport(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = _extractText(decoded);
      final jsonMap = jsonDecode(_stripCodeFence(text)) as Map<String, dynamic>;
      return AiSleepReport.fromJson(jsonMap, model: _model);
    } on FormatException {
      throw const AiCoachException(
        'AI report could not be parsed. Please try again.',
      );
    } on TypeError {
      throw const AiCoachException(
        'AI report had an unexpected format. Please try again.',
      );
    }
  }

  bool _shouldRetry(int statusCode) => _retryableStatuses.contains(statusCode);

  Map<String, dynamic> get _reportSchema => const {
    'type': 'object',
    'properties': {
      'planTitle': {'type': 'string'},
      'corePattern': {'type': 'string'},
      'whyItMatters': {'type': 'string'},
      'thisWeeksFocus': {'type': 'string'},
      'sevenDayPlan': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'day': {'type': 'string'},
            'action': {'type': 'string'},
          },
          'required': ['day', 'action'],
        },
      },
      'experiment': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'description': {'type': 'string'},
          'successMetric': {'type': 'string'},
        },
        'required': ['title', 'description', 'successMetric'],
      },
      'dataEvidence': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'avoidThisWeek': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'encouragement': {'type': 'string'},
      'disclaimer': {'type': 'string'},
    },
    'required': [
      'planTitle',
      'corePattern',
      'whyItMatters',
      'thisWeeksFocus',
      'sevenDayPlan',
      'experiment',
      'dataEvidence',
      'avoidThisWeek',
      'encouragement',
      'disclaimer',
    ],
  };

  String _extractText(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const AiCoachException('Gemini returned no report.');
    }

    final content = candidates.first['content'] as Map?;
    final parts = content?['parts'] as List?;
    final text = parts
        ?.map((part) => (part as Map?)?['text']?.toString() ?? '')
        .join()
        .trim();

    if (text == null || text.isEmpty) {
      throw const AiCoachException('Gemini returned an empty report.');
    }

    return text;
  }

  String _stripCodeFence(String text) {
    return text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();
  }

  String _buildPrompt(AiCoachInputSummary input) {
    return '''
Create a practical 7-day personalized sleep coaching plan for SleepWell using this compact summary only. Do not merely summarize the data.

Coaching rules:
- If avg7 is low, focus on increasing sleep duration.
- If duration is okay but ESS is high, focus on quality, recovery, and consistency.
- If PSQI is high, focus on sleep quality, environment, and habits.
- If ISI is high, focus on schedule and wind-down; suggest professional support only if symptoms persist or feel severe.
- If weekday/weekend gap is high, focus on consistency.
- If data is sparse, create a starter plan and ask the user to track more nights.

Safety:
- No diagnosis, disorder claims, medication advice, or extreme health claims.
- Keep actions concrete, low-risk, calm, and doable.
- Return strict JSON only using this shape:
{
  "planTitle": "...",
  "corePattern": "...",
  "whyItMatters": "...",
  "thisWeeksFocus": "...",
  "sevenDayPlan": [
    {"day": "Day 1", "action": "..."},
    {"day": "Day 2", "action": "..."},
    {"day": "Day 3", "action": "..."},
    {"day": "Day 4", "action": "..."},
    {"day": "Day 5", "action": "..."},
    {"day": "Day 6", "action": "..."},
    {"day": "Day 7", "action": "..."}
  ],
  "experiment": {
    "title": "...",
    "description": "...",
    "successMetric": "..."
  },
  "dataEvidence": ["...", "...", "..."],
  "avoidThisWeek": ["...", "..."],
  "encouragement": "...",
  "disclaimer": "Educational guidance only, not medical advice."
}
Summary: ${jsonEncode(input.toJson())}
''';
  }

  AiSleepReport _buildLocalFallbackReport(AiCoachInputSummary input) {
    final focus = _localFocus(input);
    final weekendDiff = input.weekdayAvg != null && input.weekendAvg != null
        ? (input.weekendAvg! - input.weekdayAvg!).abs()
        : null;

    return AiSleepReport(
      planTitle: _localPlanTitle(focus),
      corePattern: _localCorePattern(input, weekendDiff),
      whyItMatters: _localWhyItMatters(focus),
      thisWeeksFocus: _localThisWeeksFocus(focus),
      sevenDayPlan: _localSevenDayPlan(focus),
      experiment: _localExperiment(focus),
      dataEvidence: _localEvidence(input, weekendDiff),
      avoidThisWeek: _localAvoidList(focus),
      encouragement: _localEncouragement(input),
      disclaimer: 'Educational guidance only, not medical advice.',
      inputSummary: input,
      model: kLocalFallbackModel,
    );
  }

  _CoachingFocus _localFocus(AiCoachInputSummary input) {
    final weekendDiff = input.weekdayAvg != null && input.weekendAvg != null
        ? (input.weekendAvg! - input.weekdayAvg!).abs()
        : null;
    if (input.trackedDays30 < 4) {
      return _CoachingFocus.starter;
    }
    if (input.avg7 != null && input.avg7! < 6.5) {
      return _CoachingFocus.duration;
    }
    if (_scoreAtLeast(input.latestIsi, 15)) {
      return _CoachingFocus.windDown;
    }
    if (_scoreAtLeast(input.latestEss, 10)) {
      return _CoachingFocus.quality;
    }
    if (_scoreAtLeast(input.latestPsqi, 5)) {
      return _CoachingFocus.environment;
    }
    if (weekendDiff != null && weekendDiff >= 1.25) {
      return _CoachingFocus.consistency;
    }
    if (input.trendDirection == 'declining') {
      return _CoachingFocus.recovery;
    }
    return _CoachingFocus.steady;
  }

  bool _scoreAtLeast(AssessmentSummary? assessment, int threshold) {
    final score = assessment?.score;
    return score != null && score >= threshold;
  }

  String _localPlanTitle(_CoachingFocus focus) {
    return switch (focus) {
      _CoachingFocus.duration => '7-day sleep duration reset',
      _CoachingFocus.quality => '7-day recovery quality plan',
      _CoachingFocus.environment => '7-day sleep quality upgrade',
      _CoachingFocus.windDown => '7-day wind-down stability plan',
      _CoachingFocus.consistency => '7-day consistency plan',
      _CoachingFocus.recovery => '7-day recovery rebound',
      _CoachingFocus.starter => '7-day starter sleep plan',
      _CoachingFocus.steady => '7-day sleep rhythm plan',
    };
  }

  String _localCorePattern(AiCoachInputSummary input, double? weekendDiff) {
    final avg7 = input.avg7 == null
        ? 'your recent average is still forming'
        : 'your recent average is ${input.avg7!.toStringAsFixed(1)}h';
    final avg30 = input.avg30 == null
        ? ''
        : ', compared with a 30-day baseline of ${input.avg30!.toStringAsFixed(1)}h';
    final gap = weekendDiff == null
        ? ''
        : ' Your weekday/weekend gap is about ${weekendDiff.toStringAsFixed(1)}h.';
    return 'The main pattern is that $avg7$avg30 across ${input.trackedDays30} tracked day${input.trackedDays30 == 1 ? '' : 's'}.$gap';
  }

  String _localWhyItMatters(_CoachingFocus focus) {
    return switch (focus) {
      _CoachingFocus.duration =>
        'More consistent sleep opportunity gives your body a better chance to recover before optimizing smaller habits.',
      _CoachingFocus.quality =>
        'When duration is not the only issue, the next lever is reducing friction that makes sleep feel less restorative.',
      _CoachingFocus.environment =>
        'Sleep quality often improves when the room, light, noise, and evening cues consistently tell your body it is safe to settle.',
      _CoachingFocus.windDown =>
        'A predictable wind-down reduces the amount of decision-making and stimulation close to bedtime.',
      _CoachingFocus.consistency =>
        'A steadier sleep window helps your body predict when to feel sleepy and when to feel alert.',
      _CoachingFocus.recovery =>
        'A lower recent trend is a useful signal to protect recovery before short nights become the new normal.',
      _CoachingFocus.starter =>
        'The first win is building enough reliable data to personalize the next plan with more confidence.',
      _CoachingFocus.steady =>
        'Small routines are easier to keep when your baseline is already reasonably stable.',
    };
  }

  String _localThisWeeksFocus(_CoachingFocus focus) {
    return switch (focus) {
      _CoachingFocus.duration =>
        'Create a larger sleep opportunity by moving the evening earlier in small, realistic steps.',
      _CoachingFocus.quality =>
        'Protect recovery quality with a calmer final hour and a steadier wake time.',
      _CoachingFocus.environment =>
        'Upgrade the sleep environment and remove the biggest late-night disruptors.',
      _CoachingFocus.windDown =>
        'Build a repeatable wind-down routine that starts before you feel exhausted.',
      _CoachingFocus.consistency =>
        'Narrow the weekday/weekend gap without making the plan feel rigid.',
      _CoachingFocus.recovery =>
        'Use the next 7 days to recover your baseline gently and consistently.',
      _CoachingFocus.starter =>
        'Track every night and repeat one simple bedtime cue so SleepWell can learn your pattern.',
      _CoachingFocus.steady =>
        'Maintain the rhythm and test one small habit that could make sleep feel smoother.',
    };
  }

  List<DailyPlanAction> _localSevenDayPlan(_CoachingFocus focus) {
    final actions = switch (focus) {
      _CoachingFocus.duration => const [
        'Choose a realistic target bedtime 20 minutes earlier than usual.',
        'Set a wind-down alarm and stop non-essential tasks when it rings.',
        'Move screens out of bed and dim lights for the final 30 minutes.',
        'Keep wake time steady, even if bedtime was imperfect.',
        'Protect a 7.5-8 hour sleep window tonight if your schedule allows.',
        'Review what delayed bedtime most often and remove one blocker.',
        'Repeat the best night setup from this week.',
      ],
      _CoachingFocus.quality => const [
        'Keep wake time steady and get light exposure after waking.',
        'Make the final hour quieter: fewer screens, lower lights, less multitasking.',
        'Avoid late caffeine and note whether sleep feels more restorative.',
        'Use a short relaxation cue before bed, such as breathing or stretching.',
        'Keep the room cool, dark, and quiet tonight.',
        'Compare energy tomorrow with the calmest evening routine.',
        'Repeat the routine that made waking feel easiest.',
      ],
      _CoachingFocus.environment => const [
        'Pick one room upgrade: cooler temperature, darker room, or less noise.',
        'Dim lights 60 minutes before bed.',
        'Keep the phone away from the bed tonight.',
        'Avoid heavy late meals or intense work close to bedtime.',
        'Use the same pre-sleep cue for 10 minutes.',
        'Check whether the room change improved sleep continuity.',
        'Keep the best environment change and make it default.',
      ],
      _CoachingFocus.windDown => const [
        'Set a fixed start time for a 20-minute wind-down.',
        'Write tomorrow’s first task down before getting into bed.',
        'Use a low-stimulation activity during wind-down.',
        'Keep wake time steady even if sleep onset was slower.',
        'Avoid judging the night while in bed; return to the routine calmly.',
        'If difficulty persists or feels severe, consider professional support.',
        'Repeat the wind-down sequence that felt easiest to follow.',
      ],
      _CoachingFocus.consistency => const [
        'Choose one wake time target for the next 7 days.',
        'Keep bedtime within a 45-minute window tonight.',
        'Plan the weekend sleep window before the weekend arrives.',
        'Avoid sleeping in dramatically after a short night.',
        'Use morning light to reinforce the wake schedule.',
        'Keep naps short and earlier if you use them.',
        'Review the weekday/weekend gap and keep the smaller swing.',
      ],
      _CoachingFocus.recovery => const [
        'Protect tonight from late tasks by choosing a hard stop time.',
        'Reduce evening stimulation for the final 45 minutes.',
        'Keep wake time steady and avoid chasing catch-up too aggressively.',
        'Add a short daytime reset, such as a walk or quiet break.',
        'Repeat the routine from your strongest recent night.',
        'Avoid stacking another late night if possible.',
        'Compare your 7-day average after the recovery week.',
      ],
      _CoachingFocus.starter => const [
        'Track tonight, even if the sleep window is imperfect.',
        'Add one manual note about caffeine, screens, or stress.',
        'Keep wake time as consistent as possible.',
        'Try a 10-minute wind-down cue before bed.',
        'Complete one sleep assessment if you have not yet.',
        'Track the weekend night too so patterns are not missing.',
        'Review your first pattern and generate the next plan.',
      ],
      _CoachingFocus.steady => const [
        'Keep your current sleep window steady tonight.',
        'Protect the final 30 minutes from screens or work.',
        'Repeat the conditions from your best recent night.',
        'Avoid large weekend timing swings.',
        'Use a calm cue before bed, even if you are not stressed.',
        'Check energy and mood after waking.',
        'Keep the one habit that felt easiest to repeat.',
      ],
    };

    return List.generate(
      actions.length,
      (index) =>
          DailyPlanAction(day: 'Day ${index + 1}', action: actions[index]),
    );
  }

  PlanExperiment _localExperiment(_CoachingFocus focus) {
    return switch (focus) {
      _CoachingFocus.duration => const PlanExperiment(
        title: '20-minute earlier window',
        description:
            'Move the start of your wind-down 20 minutes earlier for three nights and protect that time like an appointment.',
        successMetric:
            'Your sleep duration increases by at least 20 minutes on two nights.',
      ),
      _CoachingFocus.quality ||
      _CoachingFocus.environment => const PlanExperiment(
        title: 'Calmer final hour',
        description:
            'For three nights, dim lights, reduce screens, and keep the room cool before bed.',
        successMetric:
            'You report easier sleep onset or better morning energy.',
      ),
      _CoachingFocus.windDown => const PlanExperiment(
        title: 'Repeatable wind-down cue',
        description:
            'Use the same 15-minute pre-sleep routine every night this week.',
        successMetric: 'You complete the routine on at least five nights.',
      ),
      _CoachingFocus.consistency => const PlanExperiment(
        title: 'Wake-time anchor',
        description:
            'Keep wake time within the same 45-minute range for seven days.',
        successMetric: 'Weekday and weekend averages move closer together.',
      ),
      _CoachingFocus.recovery => const PlanExperiment(
        title: 'Recovery guardrail',
        description:
            'Choose two nights this week where bedtime is protected from late tasks.',
        successMetric: 'Your 7-day average stabilizes or improves.',
      ),
      _ => const PlanExperiment(
        title: 'Tracking streak',
        description:
            'Track every night this week and keep one simple bedtime cue consistent.',
        successMetric:
            'You record seven nights and identify one repeatable pattern.',
      ),
    };
  }

  List<String> _localEvidence(AiCoachInputSummary input, double? weekendDiff) {
    final evidence = <String>[
      'Tracked ${input.trackedDays30} day${input.trackedDays30 == 1 ? '' : 's'} in the last 30 days.',
    ];
    if (input.avg7 != null) {
      evidence.add('7-day average: ${input.avg7!.toStringAsFixed(1)}h.');
    }
    if (input.avg30 != null) {
      evidence.add('30-day average: ${input.avg30!.toStringAsFixed(1)}h.');
    }
    if (weekendDiff != null) {
      evidence.add(
        'Weekday/weekend gap: about ${weekendDiff.toStringAsFixed(1)}h.',
      );
    }
    if (input.bestNight != null && input.worstNight != null) {
      evidence.add(
        'Best night ${input.bestNight!.hours.toStringAsFixed(1)}h vs worst night ${input.worstNight!.hours.toStringAsFixed(1)}h.',
      );
    }
    final assessment = input.latestIsi ?? input.latestEss ?? input.latestPsqi;
    if (assessment != null) {
      evidence.add(
        'Latest ${assessment.type}: ${assessment.score ?? '--'}${assessment.level == null ? '' : ' (${assessment.level})'}.',
      );
    }
    return evidence.take(4).toList();
  }

  List<String> _localAvoidList(_CoachingFocus focus) {
    return switch (focus) {
      _CoachingFocus.duration => const [
        'Starting demanding tasks close to bedtime.',
        'Using weekends as the only recovery plan.',
      ],
      _CoachingFocus.quality || _CoachingFocus.environment => const [
        'Bright screens or intense work in the final hour.',
        'Changing several sleep habits at once.',
      ],
      _CoachingFocus.windDown => const [
        'Waiting until you are exhausted to start winding down.',
        'Judging a difficult night as a failure.',
      ],
      _CoachingFocus.consistency => const [
        'Large sleep-ins that shift your body clock.',
        'Letting weekend plans erase your wake-time anchor.',
      ],
      _ => const [
        'Skipping tracking after an imperfect night.',
        'Making the plan too strict to repeat.',
      ],
    };
  }

  String _localEncouragement(AiCoachInputSummary input) {
    if (input.bestNight != null) {
      return 'You already have evidence that stronger nights are possible. This week is about making the repeatable parts easier to find.';
    }
    return 'Start simple. A plan you can repeat beats a perfect routine you abandon after one night.';
  }

  Future<void> _saveReport(String uid, AiSleepReport report) async {
    await _firestore.collection('users').doc(uid).collection('ai_reports').add({
      'createdAt': FieldValue.serverTimestamp(),
      'planTitle': report.planTitle,
      'corePattern': report.corePattern,
      'whyItMatters': report.whyItMatters,
      'thisWeeksFocus': report.thisWeeksFocus,
      'sevenDayPlan': report.sevenDayPlan
          .map((action) => action.toJson())
          .toList(),
      'experiment': report.experiment.toJson(),
      'dataEvidence': report.dataEvidence,
      'avoidThisWeek': report.avoidThisWeek,
      'encouragement': report.encouragement,
      'disclaimer': report.disclaimer,
      'inputSummary': report.inputSummary?.toJson(),
      'model': report.model,
    });
  }
}

class AiCoachInputSummary {
  final double? avg7;
  final double? avg30;
  final int trackedDays30;
  final double? weekdayAvg;
  final double? weekendAvg;
  final String trendDirection;
  final NightSummary? bestNight;
  final NightSummary? worstNight;
  final AssessmentSummary? latestPsqi;
  final AssessmentSummary? latestEss;
  final AssessmentSummary? latestIsi;

  const AiCoachInputSummary({
    required this.avg7,
    required this.avg30,
    required this.trackedDays30,
    required this.weekdayAvg,
    required this.weekendAvg,
    required this.trendDirection,
    required this.bestNight,
    required this.worstNight,
    required this.latestPsqi,
    required this.latestEss,
    required this.latestIsi,
  });

  bool get hasSleepData => trackedDays30 > 0;

  factory AiCoachInputSummary.fromJson(Map<String, dynamic> json) {
    return AiCoachInputSummary(
      avg7: _readDouble(json['avg7']),
      avg30: _readDouble(json['avg30']),
      trackedDays30: (json['trackedDays30'] as num?)?.toInt() ?? 0,
      weekdayAvg: _readDouble(json['weekdayAvg']),
      weekendAvg: _readDouble(json['weekendAvg']),
      trendDirection: json['trendDirection']?.toString() ?? 'not_enough_data',
      bestNight: NightSummary.fromJson(json['bestNight']),
      worstNight: NightSummary.fromJson(json['worstNight']),
      latestPsqi: AssessmentSummary.fromJson(json['latestPSQI']),
      latestEss: AssessmentSummary.fromJson(json['latestESS']),
      latestIsi: AssessmentSummary.fromJson(json['latestISI']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avg7': _round(avg7),
      'avg30': _round(avg30),
      'trackedDays30': trackedDays30,
      'weekdayAvg': _round(weekdayAvg),
      'weekendAvg': _round(weekendAvg),
      'trendDirection': trendDirection,
      'bestNight': bestNight?.toJson(),
      'worstNight': worstNight?.toJson(),
      'latestPSQI': latestPsqi?.toJson(),
      'latestESS': latestEss?.toJson(),
      'latestISI': latestIsi?.toJson(),
    };
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double? _round(double? value) {
    if (value == null) return null;
    return double.parse(value.toStringAsFixed(2));
  }
}

class NightSummary {
  final DateTime date;
  final double hours;

  const NightSummary({required this.date, required this.hours});

  static NightSummary? fromJson(Object? value) {
    if (value is! Map) return null;
    final date = DateTime.tryParse(value['date']?.toString() ?? '');
    final hours = AiCoachInputSummary._readDouble(value['hours']);
    if (date == null || hours == null) return null;
    return NightSummary(date: date, hours: hours);
  }

  Map<String, dynamic> toJson() {
    return {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'hours': AiCoachInputSummary._round(hours),
    };
  }
}

class AssessmentSummary {
  final String type;
  final int? score;
  final String? level;
  final DateTime? createdAt;

  const AssessmentSummary({
    required this.type,
    required this.score,
    required this.level,
    required this.createdAt,
  });

  static AssessmentSummary? fromJson(Object? value) {
    if (value is! Map) return null;
    final type = value['type']?.toString();
    if (type == null || type.isEmpty) return null;
    return AssessmentSummary(
      type: type,
      score: (value['score'] as num?)?.toInt(),
      level: value['level']?.toString(),
      createdAt: DateTime.tryParse(value['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'score': score,
      'level': level,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class DailyPlanAction {
  final String day;
  final String action;

  const DailyPlanAction({required this.day, required this.action});

  static DailyPlanAction? fromJson(Object? value, {int? index}) {
    if (value is Map) {
      final day = value['day']?.toString().trim();
      final action = value['action']?.toString().trim();
      if (action == null || action.isEmpty) return null;
      return DailyPlanAction(
        day: day == null || day.isEmpty ? 'Day ${index ?? 1}' : day,
        action: action,
      );
    }

    final action = value?.toString().trim();
    if (action == null || action.isEmpty) return null;
    return DailyPlanAction(day: 'Day ${index ?? 1}', action: action);
  }

  Map<String, dynamic> toJson() {
    return {'day': day, 'action': action};
  }
}

class PlanExperiment {
  final String title;
  final String description;
  final String successMetric;

  const PlanExperiment({
    required this.title,
    required this.description,
    required this.successMetric,
  });

  static PlanExperiment fromJson(Object? value) {
    if (value is Map) {
      return PlanExperiment(
        title: _read(value, 'title', 'This week experiment'),
        description: _read(
          value,
          'description',
          'Try one repeatable sleep habit for the next few nights.',
        ),
        successMetric: _read(
          value,
          'successMetric',
          'You can repeat the habit on at least four nights.',
        ),
      );
    }

    return const PlanExperiment(
      title: 'This week experiment',
      description: 'Try one repeatable sleep habit for the next few nights.',
      successMetric: 'You can repeat the habit on at least four nights.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'successMetric': successMetric,
    };
  }

  static String _read(Map value, String key, String fallback) {
    final text = value[key]?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }
}

class AiSleepReport {
  final String? id;
  final DateTime? createdAt;
  final String planTitle;
  final String corePattern;
  final String whyItMatters;
  final String thisWeeksFocus;
  final List<DailyPlanAction> sevenDayPlan;
  final PlanExperiment experiment;
  final List<String> dataEvidence;
  final List<String> avoidThisWeek;
  final String encouragement;
  final String disclaimer;
  final AiCoachInputSummary? inputSummary;
  final String model;

  const AiSleepReport({
    this.id,
    this.createdAt,
    required this.planTitle,
    required this.corePattern,
    required this.whyItMatters,
    required this.thisWeeksFocus,
    required this.sevenDayPlan,
    required this.experiment,
    required this.dataEvidence,
    required this.avoidThisWeek,
    required this.encouragement,
    required this.disclaimer,
    required this.inputSummary,
    required this.model,
  });

  factory AiSleepReport.fromJson(
    Map<String, dynamic> json, {
    required String model,
  }) {
    return _fromMap(json, model: model, inputSummary: null);
  }

  factory AiSleepReport.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final inputSummary = data['inputSummary'];
    return _fromMap(
      data,
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      inputSummary: inputSummary is Map
          ? AiCoachInputSummary.fromJson(
              Map<String, dynamic>.from(inputSummary),
            )
          : null,
      model: _readText(data, 'model', fallback: kGeminiModel),
    );
  }

  AiSleepReport copyWith({AiCoachInputSummary? inputSummary}) {
    return AiSleepReport(
      id: id,
      createdAt: createdAt,
      planTitle: planTitle,
      corePattern: corePattern,
      whyItMatters: whyItMatters,
      thisWeeksFocus: thisWeeksFocus,
      sevenDayPlan: sevenDayPlan,
      experiment: experiment,
      dataEvidence: dataEvidence,
      avoidThisWeek: avoidThisWeek,
      encouragement: encouragement,
      disclaimer: disclaimer,
      inputSummary: inputSummary ?? this.inputSummary,
      model: model,
    );
  }

  bool get isLocalFallback => model == kLocalFallbackModel;

  String get summaryTitle => planTitle;

  static AiSleepReport _fromMap(
    Map<String, dynamic> json, {
    String? id,
    DateTime? createdAt,
    required AiCoachInputSummary? inputSummary,
    required String model,
  }) {
    final legacyRecommendations = _readStringList(json['recommendations']);
    final plan = _readPlan(json['sevenDayPlan']);
    final fallbackPlan = legacyRecommendations
        .asMap()
        .entries
        .map(
          (entry) =>
              DailyPlanAction(day: 'Day ${entry.key + 1}', action: entry.value),
        )
        .toList();

    return AiSleepReport(
      id: id,
      createdAt: createdAt,
      planTitle: _firstText(json, const [
        'planTitle',
        'summaryTitle',
      ], 'Personalized sleep plan'),
      corePattern: _firstText(json, const [
        'corePattern',
        'mainInsight',
      ], 'SleepWell found a pattern worth turning into a focused plan.'),
      whyItMatters: _firstText(
        json,
        const ['whyItMatters', 'positiveTrend'],
        'Small repeatable sleep habits can make the next week easier to interpret and improve.',
      ),
      thisWeeksFocus: _firstText(
        json,
        const ['thisWeeksFocus', 'watchArea'],
        'Build one consistent sleep habit and track how it affects your next seven nights.',
      ),
      sevenDayPlan: plan.isNotEmpty
          ? plan
          : fallbackPlan.isNotEmpty
          ? fallbackPlan
          : _defaultSevenDayPlan(),
      experiment: PlanExperiment.fromJson(json['experiment']),
      dataEvidence: _readStringList(json['dataEvidence']).isEmpty
          ? _legacyEvidence(json)
          : _readStringList(json['dataEvidence']).take(4).toList(),
      avoidThisWeek: _readStringList(json['avoidThisWeek']).isEmpty
          ? const [
              'Making several sleep changes at once.',
              'Treating one imperfect night as failure.',
            ]
          : _readStringList(json['avoidThisWeek']).take(3).toList(),
      encouragement: _readText(
        json,
        'encouragement',
        fallback:
            'A focused plan is useful because it makes the next week easier to repeat and measure.',
      ),
      disclaimer: _readText(
        json,
        'disclaimer',
        fallback: 'Educational guidance only, not medical advice.',
      ),
      inputSummary: inputSummary,
      model: model,
    );
  }

  static List<DailyPlanAction> _readPlan(Object? value) {
    final list = value is List ? value : const [];
    return list
        .asMap()
        .entries
        .map(
          (entry) =>
              DailyPlanAction.fromJson(entry.value, index: entry.key + 1),
        )
        .whereType<DailyPlanAction>()
        .take(7)
        .toList();
  }

  static List<DailyPlanAction> _defaultSevenDayPlan() {
    return List.generate(
      7,
      (index) => DailyPlanAction(
        day: 'Day ${index + 1}',
        action: 'Track sleep and repeat one calm bedtime cue.',
      ),
    );
  }

  static List<String> _legacyEvidence(Map<String, dynamic> json) {
    return [
      _readText(json, 'mainInsight'),
      _readText(json, 'positiveTrend'),
      _readText(json, 'watchArea'),
    ].where((item) => item.isNotEmpty).take(3).toList();
  }

  static String _firstText(
    Map<String, dynamic> json,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = _readText(json, key);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static List<String> _readStringList(Object? value) {
    final list = value is List ? value : const [];
    return list
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _readText(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = (json[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }
}

class AiCoachException implements Exception {
  final String message;

  const AiCoachException(this.message);

  @override
  String toString() => message;
}

class AiCoachMissingApiKeyException extends AiCoachException {
  const AiCoachMissingApiKeyException(super.message);
}

class AiCoachNoDataException extends AiCoachException {
  const AiCoachNoDataException(super.message);
}

class AiCoachGeminiUnavailableException extends AiCoachException {
  const AiCoachGeminiUnavailableException()
    : super('Gemini is temporarily overloaded. Please try again in a minute.');
}

enum _CoachingFocus {
  duration,
  quality,
  environment,
  windDown,
  consistency,
  recovery,
  starter,
  steady,
}

class _DailySleep {
  final DateTime date;
  final double hours;

  const _DailySleep({required this.date, required this.hours});

  _DailySleep copyWith({double? hours}) {
    return _DailySleep(date: date, hours: hours ?? this.hours);
  }
}
