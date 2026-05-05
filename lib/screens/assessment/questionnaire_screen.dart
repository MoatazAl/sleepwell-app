import 'package:flutter/material.dart';

import '../../models/questionnaire.dart';
import '../../services/questionnaire_service.dart';
import '../../theme.dart';
import 'result_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final String type;

  const QuestionnaireScreen({
    super.key,
    required this.type,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late final QuestionnaireDefinition _definition;
  late final List<int?> _answers;

  int _index = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _definition = questionnaireByType(widget.type);
    _answers = List<int?>.filled(_definition.questions.length, null);
  }

  @override
  Widget build(BuildContext context) {
    final question = _definition.questions[_index];
    final progress = (_index + 1) / _definition.questions.length;
    final selected = _answers[_index];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_definition.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _header(progress),
              const SizedBox(height: 18),
              _questionCard(question, selected),
              const SizedBox(height: 22),
              _bottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(double progress) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _definition.type,
                      style: TextStyle(
                        color: _definition.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _definition.subtitle,
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_index + 1}/${_definition.questions.length}',
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(_definition.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _definition.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _definition.color.withValues(alpha: 0.24),
        ),
      ),
      child: Icon(
        _definition.icon,
        color: _definition.color,
        size: 24,
      ),
    );
  }

  Widget _questionCard(QuestionnaireQuestion question, int? selected) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              question.text,
              key: ValueKey(question.text),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(question.options.length, (i) {
            final option = question.options[i];
            final isSelected = selected == option.score;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _optionTile(
                option: option,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _answers[_index] = option.score;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _optionTile({
    required QuestionnaireOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? _definition.color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? _definition.color.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _definition.color : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _definition.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  color: isSelected ? Colors.white : kTextSecondary,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${option.score}',
              style: TextStyle(
                color: isSelected ? _definition.color : kTextMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomButtons() {
    final hasAnswer = _answers[_index] != null;
    final isLast = _index == _definition.questions.length - 1;

    return Row(
      children: [
        if (_index > 0)
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving
                  ? null
                  : () {
                      setState(() => _index--);
                    },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ),
        if (_index > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  hasAnswer ? _definition.color : Colors.white24,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: !hasAnswer || _saving
                ? null
                : isLast
                    ? _finish
                    : () {
                        setState(() => _index++);
                      },
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isLast
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(isLast ? 'See Result' : 'Next'),
          ),
        ),
      ],
    );
  }

  Future<void> _finish() async {
    final completedAnswers = _answers.whereType<int>().toList();

    if (completedAnswers.length != _definition.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions first.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final result = scoreQuestionnaire(
        type: _definition.type,
        answers: completedAnswers,
      );

      await QuestionnaireService.saveResult(
        result: result,
        answers: completedAnswers,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save result: $e')),
      );
    }
  }
}