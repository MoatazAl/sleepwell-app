import 'package:flutter/material.dart';

import '../../theme.dart';

class SleepSoundItem {
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final Color color;
  final String assetPath;

  const SleepSoundItem({
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.color,
    required this.assetPath,
  });
}

class SoundTile extends StatelessWidget {
  final SleepSoundItem sound;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;

  const SoundTile({
    super.key,
    required this.sound,
    required this.selected,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: selected
              ? sound.color.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? sound.color.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    sound.color.withValues(alpha: 0.95),
                    kAccentBlue.withValues(alpha: 0.42),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(sound.icon, color: Colors.white, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sound.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sound.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? sound.color.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                selected && playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: selected ? sound.color : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
