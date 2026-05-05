import 'package:flutter/material.dart';

import '../../models/questionnaire.dart';
import '../../theme.dart';

class ResultScreen extends StatelessWidget {
  final QuestionnaireResult result;

  const ResultScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final info = _infoFor(result.type);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Assessment Result'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              _heroCard(),
              const SizedBox(height: 16),
              _scoreCard(),
              const SizedBox(height: 16),
              _meaningCard(info),
              const SizedBox(height: 16),
              _breakdownCard(),
              const SizedBox(height: 16),
              _scienceCard(info),
              const SizedBox(height: 16),
              _actionsCard(),
              const SizedBox(height: 22),
              _buttons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: result.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: result.color.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              color: result.color,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  result.level,
                  style: TextStyle(
                    color: result.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Educational screening result — not a medical diagnosis.',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCard() {
    final pct = result.maxScore == 0 ? 0.0 : result.score / result.maxScore;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassCardDecoration,
      child: Column(
        children: [
          Text(
            '${result.score}',
            style: TextStyle(
              color: result.color,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Score out of ${result.maxScore}',
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(result.color),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meaningCard(_AssessmentInfo info) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What this score means',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.meaning,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...info.ranges.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: r.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard() {
    if (result.components.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How your score was calculated',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total score = ${result.components.map((c) => c.score).join(' + ')} = ${result.score} / ${result.maxScore}',
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          ...result.components.map((c) {
            final pct = c.maxScore == 0 ? 0.0 : c.score / c.maxScore;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${c.score}/${c.maxScore}',
                        style: TextStyle(
                          color: result.color,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(result.color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.explanation,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _scienceCard(_AssessmentInfo info) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Science behind this assessment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.science,
            style: const TextStyle(
              color: kTextSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              info.source,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended next steps',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...result.actions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: result.color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: result.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text(
              'Back to Home',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: result.color.withValues(alpha: 0.45)),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Retake Assessment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  _AssessmentInfo _infoFor(String type) {
    switch (type) {
      case 'ESS':
        return const _AssessmentInfo(
          meaning:
              'The ESS estimates daytime sleepiness by asking how likely you are to accidentally fall asleep in common daily situations. Higher scores suggest greater daytime sleepiness.',
          science:
              'The Epworth Sleepiness Scale is a self-administered questionnaire developed by Murray Johns. It uses 8 situations scored from 0 to 3, giving a total score from 0 to 24.',
          source:
              'Source: Johns MW. A new method for measuring daytime sleepiness: the Epworth Sleepiness Scale. Sleep. 1991;14(6):540–545.',
          ranges: [
            _ScoreRange('0–10: Normal range', Color(0xFF22C55E)),
            _ScoreRange('11–14: Mild excessive sleepiness', Color(0xFFF59E0B)),
            _ScoreRange('15–17: Moderate excessive sleepiness', Color(0xFFF97316)),
            _ScoreRange('18–24: Severe excessive sleepiness', Color(0xFFEF4444)),
          ],
        );

      case 'ISI':
        return const _AssessmentInfo(
          meaning:
              'The ISI estimates insomnia severity and its impact on daily life. Higher scores suggest more severe insomnia symptoms.',
          science:
              'The Insomnia Severity Index uses 7 items scored from 0 to 4, giving a total score from 0 to 28. It is widely used in insomnia research and clinical outcome assessment.',
          source:
              'Source: Bastien CH, Vallières A, Morin CM. Validation of the Insomnia Severity Index as an outcome measure for insomnia research. Sleep Medicine. 2001;2(4):297–307.',
          ranges: [
            _ScoreRange('0–7: No clinically significant insomnia', Color(0xFF22C55E)),
            _ScoreRange('8–14: Subthreshold insomnia', Color(0xFFF59E0B)),
            _ScoreRange('15–21: Moderate insomnia symptoms', Color(0xFFF97316)),
            _ScoreRange('22–28: Severe insomnia symptoms', Color(0xFFEF4444)),
          ],
        );

      case 'PSQI':
      default:
        return const _AssessmentInfo(
          meaning:
              'This PSQI-style result estimates sleep quality. Higher scores suggest more sleep-quality concerns. In the official PSQI, a global score above 5 is commonly used to indicate poor sleep quality.',
          science:
              'The Pittsburgh Sleep Quality Index assesses sleep quality and disturbances over a 1-month interval. The official PSQI uses 19 self-rated items to generate 7 component scores, summed to a global score from 0 to 21. SleepWell currently uses a simplified PSQI-style component screen for product usability.',
          source:
              'Source: Buysse DJ, Reynolds CF, Monk TH, Berman SR, Kupfer DJ. The Pittsburgh Sleep Quality Index: A new instrument for psychiatric practice and research. Psychiatry Research. 1989;28(2):193–213.',
          ranges: [
            _ScoreRange('0–5: Good sleep quality range', Color(0xFF22C55E)),
            _ScoreRange('6–10: Sleep quality may need attention', Color(0xFFF59E0B)),
            _ScoreRange('11–21: Poor sleep-quality indicators', Color(0xFFF97316)),
          ],
        );
    }
  }
}

class _AssessmentInfo {
  final String meaning;
  final String science;
  final String source;
  final List<_ScoreRange> ranges;

  const _AssessmentInfo({
    required this.meaning,
    required this.science,
    required this.source,
    required this.ranges,
  });
}

class _ScoreRange {
  final String label;
  final Color color;

  const _ScoreRange(this.label, this.color);
}