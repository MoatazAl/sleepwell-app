import 'package:flutter/material.dart';

import '../../theme.dart';
import 'coach_detail_screen.dart';

class SleepCoachScreen extends StatelessWidget {
  const SleepCoachScreen({super.key});

  static const List<CoachTopic> topics = [
    CoachTopic(
      title: 'Sleep Schedule',
      subtitle: 'Build a steadier rhythm across the week.',
      explanation:
          'A consistent bedtime and wake time help your body predict when to sleep and when to feel alert.',
      whyItMatters:
          'Your circadian rhythm responds strongly to timing. Large swings can add sleep debt and make it harder to fall asleep on schedule.',
      actions: [
        'Keep wake time consistent',
        'Move bedtime gradually by 15-30 minutes',
        'Avoid large weekend schedule swings',
      ],
      dataPlaceholder:
          'Use your sleep history to compare bedtime, wake time, and short-sleep patterns across recent weeks.',
      imageAsset: 'assets/images/coach/sleep_schedule.png',
      chipLabel: 'Rhythm',
      icon: Icons.schedule_rounded,
      color: kBrand,
    ),
    CoachTopic(
      title: 'Sleep Environment',
      subtitle: 'Tune light, temperature, noise, and comfort.',
      explanation:
          'Your room setup can make sleep easier by reducing signals that keep the brain alert.',
      whyItMatters:
          'Light, temperature, noise, and air quality can affect sleep continuity. Small changes often make the sleep window feel calmer.',
      actions: [
        'Dim lights 60 minutes before bed',
        'Keep room cool and comfortable',
        'Reduce noise and bright screens',
      ],
      dataPlaceholder:
          'Compare nights with more wake time or lower duration against changes in your room, screen use, and noise.',
      imageAsset: 'assets/images/coach/sleep_environment.png',
      chipLabel: 'Room',
      icon: Icons.dark_mode_rounded,
      color: kAccentBlue,
    ),
    CoachTopic(
      title: 'Sleep Stages',
      subtitle: 'Understand Light, Deep, REM, and Awake trends.',
      explanation:
          'Watch data can estimate sleep stages, but trends over time are more useful than judging a single night.',
      whyItMatters:
          'Light, Deep, REM, and Awake periods naturally vary. Total sleep and consistency are usually the first signals to stabilize.',
      actions: [
        'Focus on total sleep first',
        'Avoid judging one night only',
        'Compare stage trends over weeks',
      ],
      dataPlaceholder:
          'Use stage summaries in History to compare Deep, REM, Light, and Awake percentages over multiple recorded nights.',
      imageAsset: 'assets/images/coach/sleep_stages.png',
      chipLabel: 'Watch data',
      icon: Icons.stacked_bar_chart_rounded,
      color: Color(0xFFC026D3),
    ),
    CoachTopic(
      title: 'Sleep Habits',
      subtitle: 'Shape the evening choices that influence sleep.',
      explanation:
          'Caffeine, screens, late meals, and wind-down routines can all affect how quickly your body settles.',
      whyItMatters:
          'Repeated evening cues teach your body what comes next. A predictable wind-down can reduce friction at bedtime.',
      actions: [
        'Avoid caffeine late in the day',
        'Build a 20-30 minute wind-down routine',
        'Keep phone away before sleep',
      ],
      dataPlaceholder:
          'Compare sleep duration and timing after different evening routines to see which habits support better nights.',
      imageAsset: 'assets/images/coach/sleep_habits.png',
      chipLabel: 'Routine',
      icon: Icons.self_improvement_rounded,
      color: Color(0xFF22C55E),
    ),
    CoachTopic(
      title: 'Recovery',
      subtitle: 'Respond thoughtfully after short or stressful nights.',
      explanation:
          'Recovery is about protecting sleep after strain, not relying only on occasional catch-up sleep.',
      whyItMatters:
          'Stress, short sleep, and irregular routines can accumulate. Repeated low-duration weeks are worth noticing early.',
      actions: [
        'Protect sleep after short nights',
        'Avoid using weekends as the only recovery plan',
        'Watch for repeated low-duration weeks',
      ],
      dataPlaceholder:
          'Use 7-day and 30-day averages in Insights to spot repeated low-duration stretches and recovery patterns.',
      imageAsset: 'assets/images/coach/sleep_recovery.png',
      chipLabel: 'Balance',
      icon: Icons.favorite_rounded,
      color: Color(0xFFF59E0B),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sleep Coach'),
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
              _aiCoachEntry(context),
              const SizedBox(height: 18),
              _topicGrid(context, isWide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiCoachEntry(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => Navigator.pushNamed(context, '/ai-coach'),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              kBrand.withValues(alpha: 0.24),
              const Color(0xFF0F172A).withValues(alpha: 0.52),
              kAccentBlue.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: kBrand.withValues(alpha: 0.22),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kAccentBlue, kBrand],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kAccentBlue.withValues(alpha: 0.20),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI INTELLIGENCE',
                    style: TextStyle(
                      color: kAccentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'AI Sleep Coach',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Personalized weekly guidance from your data.',
                    style: TextStyle(
                      color: kTextSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: glassCardDecoration,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kBrand, kAccentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kBrand.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sleep Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Concise guidance for schedule, environment, stages, habits, and recovery.',
                  style: TextStyle(
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
    );
  }

  Widget _topicGrid(BuildContext context, bool isWide) {
    if (!isWide) {
      return Column(
        children: topics
            .map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  height: 410,
                  child: _CoachImageCard(topic: topic, imageHeight: 188),
                ),
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final cardWidth = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: topics
              .map(
                (topic) => SizedBox(
                  width: cardWidth,
                  height: 440,
                  child: _CoachImageCard(topic: topic, imageHeight: 212),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CoachImageCard extends StatefulWidget {
  final CoachTopic topic;
  final double imageHeight;

  const _CoachImageCard({required this.topic, required this.imageHeight});

  @override
  State<_CoachImageCard> createState() => _CoachImageCardState();
}

class _CoachImageCardState extends State<_CoachImageCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovering ? 1.012 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoachDetailScreen(topic: topic),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: _hovering ? 0.08 : 0.06),
              border: Border.all(
                color: topic.color.withValues(alpha: _hovering ? 0.32 : 0.14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: _hovering ? 34 : 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImageBanner(topic: topic, height: widget.imageHeight),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _Chip(label: topic.chipLabel, color: topic.color),
                              const Spacer(),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: topic.color.withValues(
                                    alpha: _hovering ? 0.22 : 0.14,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: topic.color,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            topic.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Flexible(
                            child: Text(
                              topic.subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Open guide',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: topic.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageBanner extends StatelessWidget {
  final CoachTopic topic;
  final double height;

  const _ImageBanner({required this.topic, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
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
                  Colors.black.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Icon(topic.icon, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
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
          size: 48,
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
