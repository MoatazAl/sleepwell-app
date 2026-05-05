import 'package:flutter/material.dart';

import '../../theme.dart';
import 'assessment_history_screen.dart';
import 'questionnaire_screen.dart';

class AssessmentHubScreen extends StatelessWidget {
  const AssessmentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Assessments'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _hero(),
              const SizedBox(height: 18),
              _whyCard(),
              const SizedBox(height: 18),
              isWide
                  ? Row(
                      children: [
                        Expanded(child: _assessmentCard(context, 'PSQI')),
                        const SizedBox(width: 14),
                        Expanded(child: _assessmentCard(context, 'ESS')),
                        const SizedBox(width: 14),
                        Expanded(child: _assessmentCard(context, 'ISI')),
                      ],
                    )
                  : Column(
                      children: [
                        _assessmentCard(context, 'PSQI'),
                        const SizedBox(height: 14),
                        _assessmentCard(context, 'ESS'),
                        const SizedBox(height: 14),
                        _assessmentCard(context, 'ISI'),
                      ],
                    ),
              const SizedBox(height: 18),
              _historyCard(context),
              const SizedBox(height: 18),
              _progressCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassCardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep Assessments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Understand your sleep quality, daytime sleepiness, and insomnia patterns through structured questionnaires.',
            style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _whyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kBrand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.insights_rounded, color: kBrand, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'These assessments help connect your subjective sleep experience with your tracked sleep data.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assessmentCard(BuildContext context, String type) {
    final data = _data(type);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuestionnaireScreen(type: type)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: glassCardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: data.color.withValues(alpha: 0.25)),
              ),
              child: Icon(data.icon, color: data.color, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              type,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.title,
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _meta(Icons.timer_rounded, 'Duration', data.duration),
            const SizedBox(height: 8),
            _meta(Icons.quiz_rounded, 'Questions', data.questions),
            const SizedBox(height: 8),
            _meta(Icons.center_focus_strong_rounded, 'Focus', data.focus),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: data.color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Start Assessment',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: data.color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 17),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _historyCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentHistoryScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: glassCardDecoration,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kAccentBlue.withValues(alpha: 0.22)),
              ),
              child: const Icon(
                Icons.history_edu_rounded,
                color: kAccentBlue,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View assessment history',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Compare your latest PSQI, ESS, and ISI scores with previous results.',
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kAccentBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: kAccentBlue,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Retake assessments over time to monitor changes and compare them with your sleep history.',
                  style: TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _AssessmentCardData _data(String type) {
    switch (type) {
      case 'PSQI':
        return const _AssessmentCardData(
          title: 'Pittsburgh Sleep Quality Index',
          duration: '5–10 min',
          questions: '7 items',
          focus: 'Sleep quality',
          icon: Icons.bedtime_rounded,
          color: Color(0xFF22C55E),
        );
      case 'ISI':
        return const _AssessmentCardData(
          title: 'Insomnia Severity Index',
          duration: '3–5 min',
          questions: '7 items',
          focus: 'Insomnia',
          icon: Icons.nights_stay_rounded,
          color: Color(0xFFF59E0B),
        );
      case 'ESS':
      default:
        return const _AssessmentCardData(
          title: 'Epworth Sleepiness Scale',
          duration: '3–5 min',
          questions: '8 items',
          focus: 'Daytime sleepiness',
          icon: Icons.wb_sunny_rounded,
          color: Color(0xFF8B5CF6),
        );
    }
  }
}

class _AssessmentCardData {
  final String title;
  final String duration;
  final String questions;
  final String focus;
  final IconData icon;
  final Color color;

  const _AssessmentCardData({
    required this.title,
    required this.duration,
    required this.questions,
    required this.focus,
    required this.icon,
    required this.color,
  });
}
