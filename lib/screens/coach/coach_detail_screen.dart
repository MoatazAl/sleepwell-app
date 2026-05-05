import 'package:flutter/material.dart';

import '../../theme.dart';

class CoachTopic {
  final String title;
  final String subtitle;
  final String explanation;
  final String whyItMatters;
  final List<String> actions;
  final String dataPlaceholder;
  final String imageAsset;
  final String chipLabel;
  final IconData icon;
  final Color color;

  const CoachTopic({
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.whyItMatters,
    required this.actions,
    required this.dataPlaceholder,
    required this.imageAsset,
    required this.chipLabel,
    required this.icon,
    required this.color,
  });
}

class CoachDetailScreen extends StatelessWidget {
  final CoachTopic topic;

  const CoachDetailScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(topic.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _hero(isWide),
              const SizedBox(height: 16),
              _infoCard(
                icon: Icons.psychology_alt_rounded,
                title: 'Why it matters',
                body: topic.whyItMatters,
                color: kBrand,
              ),
              const SizedBox(height: 16),
              _actionsCard(),
              const SizedBox(height: 16),
              _dataCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(bool isWide) {
    return Container(
      decoration: glassCardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: isWide ? 16 / 5.4 : 16 / 8.8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    topic.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _ImageFallback(topic: topic),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    right: 22,
                    bottom: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Chip(label: topic.chipLabel, color: topic.color),
                        const SizedBox(height: 12),
                        Text(
                          topic.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          topic.explanation,
                          style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  body,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practical actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(topic.actions.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == topic.actions.length - 1 ? 0 : 10,
              ),
              child: _actionRow(index + 1, topic.actions[index]),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionRow(int number, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: topic.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: topic.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(Icons.query_stats_rounded, kAccentBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Related SleepWell data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  topic.dataPlaceholder,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final CoachTopic topic;

  const _ImageFallback({required this.topic});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            topic.color.withValues(alpha: 0.34),
            kSurfaceCard,
            kBackgroundBottom,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          topic.icon,
          color: Colors.white.withValues(alpha: 0.74),
          size: 56,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
