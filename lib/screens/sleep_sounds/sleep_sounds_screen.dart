import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../theme.dart';
import '../../widgets/app_navbar.dart';
import 'sound_tile.dart';

enum _TimerOption {
  off('Off'),
  min15('15 min'),
  min30('30 min'),
  min60('60 min');

  final String label;

  const _TimerOption(this.label);
}

extension on _TimerOption {
  Duration? get duration {
    switch (this) {
      case _TimerOption.off:
        return null;
      case _TimerOption.min15:
        return const Duration(minutes: 15);
      case _TimerOption.min30:
        return const Duration(minutes: 30);
      case _TimerOption.min60:
        return const Duration(minutes: 60);
    }
  }
}

class SleepSoundsScreen extends StatefulWidget {
  const SleepSoundsScreen({super.key});

  @override
  State<SleepSoundsScreen> createState() => _SleepSoundsScreenState();
}

class _SleepSoundsScreenState extends State<SleepSoundsScreen> {
  static const _sounds = [
    SleepSoundItem(
      title: 'Rain',
      category: 'Nature',
      description: 'Soft rainfall for a steady, quiet background.',
      icon: Icons.water_drop_rounded,
      color: kAccentBlue,
      assetPath: 'assets/audio/rain.mp3',
    ),
    SleepSoundItem(
      title: 'Forest Night',
      category: 'Nature',
      description: 'Gentle night ambience with a calm outdoor feel.',
      icon: Icons.forest_rounded,
      color: Color(0xFF22C55E),
      assetPath: 'assets/audio/forest.mp3',
    ),
    SleepSoundItem(
      title: 'Fireplace',
      category: 'Warm',
      description: 'Low crackle and warm room atmosphere.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFF97316),
      assetPath: 'assets/audio/fireplace.mp3',
    ),
    SleepSoundItem(
      title: 'White Noise',
      category: 'Noise',
      description: 'Even texture to mask small background sounds.',
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFFE5E7EB),
      assetPath: 'assets/audio/white_noise.mp3',
    ),
    SleepSoundItem(
      title: 'Wind',
      category: 'Nature',
      description: 'Soft moving air with a spacious nighttime tone.',
      icon: Icons.air_rounded,
      color: Color(0xFF93C5FD),
      assetPath: 'assets/audio/wind.mp3',
    ),
  ];

  SleepSoundItem? _selectedSound;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _sleepTimer;
  bool _playing = false;
  _TimerOption _timer = _TimerOption.off;
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _player.setLoopMode(LoopMode.one);
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing =
          state.playing && state.processingState != ProcessingState.completed;
      if (_playing != playing) {
        setState(() => _playing = playing);
      }
    });
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  List<String> get _categories {
    return [
      'All',
      ...{for (final sound in _sounds) sound.category},
    ];
  }

  List<SleepSoundItem> get _visibleSounds {
    if (_category == 'All') return _sounds;
    return _sounds.where((sound) => sound.category == _category).toList();
  }

  Future<void> _selectSound(SleepSoundItem sound) async {
    try {
      if (_selectedSound?.title == sound.title) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        return;
      }

      setState(() {
        _selectedSound = sound;
        _playing = true;
      });

      await _player.setAsset(sound.assetPath);
      await _player.play();
      _scheduleSleepTimer();
    } catch (e) {
      await _player.stop();
      _sleepTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _selectedSound = null;
        _playing = false;
        _timer = _TimerOption.off;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play ${sound.title}.')));
    }
  }

  Future<void> _togglePlayback() async {
    if (_player.playing) {
      await _player.pause();
    } else if (_selectedSound != null) {
      await _player.play();
    }
  }

  Future<void> _stop() async {
    _sleepTimer?.cancel();
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _selectedSound = null;
      _playing = false;
      _timer = _TimerOption.off;
    });
  }

  void _setTimer(_TimerOption option) {
    setState(() => _timer = option);
    _scheduleSleepTimer();
  }

  void _scheduleSleepTimer() {
    _sleepTimer?.cancel();
    final duration = _timer.duration;

    if (duration == null || _selectedSound == null) return;

    _sleepTimer = Timer(duration, () {
      if (mounted) _stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const AppNavBar(current: NavSection.sounds),
      body: Container(
        decoration: appBackgroundDecoration,
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  _selectedSound == null ? 32 : 124,
                ),
                children: [
                  _heroCard(),
                  const SizedBox(height: 18),
                  _categorySelector(),
                  const SizedBox(height: 18),
                  _soundGrid(isWide),
                ],
              ),
              if (_selectedSound != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _miniPlayer(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
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
              Icons.surround_sound_rounded,
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
                  'Sleep Sounds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Choose a calming sound for your evening routine.',
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

  Widget _categorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final selected = category == _category;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) => setState(() => _category = category),
              selectedColor: kBrand.withValues(alpha: 0.28),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              side: BorderSide(
                color: selected
                    ? kBrand.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.10),
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : kTextSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _soundGrid(bool isWide) {
    if (!isWide) {
      return Column(
        children: _visibleSounds
            .map(
              (sound) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SoundTile(
                  sound: sound,
                  selected: _selectedSound?.title == sound.title,
                  playing: _playing,
                  onTap: () => _selectSound(sound),
                ),
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final width = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: _visibleSounds
              .map(
                (sound) => SizedBox(
                  width: width,
                  child: SoundTile(
                    sound: sound,
                    selected: _selectedSound?.title == sound.title,
                    playing: _playing,
                    onTap: () => _selectSound(sound),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _miniPlayer() {
    final sound = _selectedSound!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF120018).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sound.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(sound.icon, color: sound.color),
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _playing ? 'Playing' : 'Paused',
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _togglePlayback,
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _stop,
                icon: const Icon(Icons.stop_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _TimerOption.values.map((option) {
                final selected = option == _timer;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: selected,
                    onSelected: (_) => _setTimer(option),
                    selectedColor: sound.color.withValues(alpha: 0.25),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(
                      color: selected
                          ? sound.color.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : kTextSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
