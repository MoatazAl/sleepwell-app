import '../models/sleep_stage_info.dart';

const Map<SleepStageType, SleepStageInfo> sleepStageContent = {
  SleepStageType.deep: SleepStageInfo(
    type: SleepStageType.deep,
    title: 'Deep Sleep',
    subtitle: 'Physical restoration and body recovery',
    description:
        'Deep sleep is the most restorative stage of non-REM sleep. '
        'During this phase, brain waves slow down significantly, the body relaxes deeply, '
        'and important physical recovery processes take place. Deep sleep is strongly linked '
        'to muscle repair, immune support, and feeling refreshed the next day. '
        'It usually appears more in the first half of the night.',
    benefits: [
      'Supports physical recovery and tissue repair',
      'Helps strengthen the immune system',
      'Contributes to feeling rested the next morning',
    ],
    factors: [
      'Sleep deprivation can reduce healthy sleep structure',
      'Alcohol may disturb normal deep sleep patterns',
      'Irregular sleep timing may reduce sleep quality',
    ],
    tip:
        'Protect deep sleep by keeping a consistent bedtime and avoiding late-night disruption.',
  ),

  SleepStageType.light: SleepStageInfo(
    type: SleepStageType.light,
    title: 'Light Sleep',
    subtitle: 'Transition and stabilization across the night',
    description:
        'Light sleep makes up a large portion of total sleep time and acts as the bridge '
        'between wakefulness, deep sleep, and REM sleep. Although it is lighter than deep sleep, '
        'it is still an important part of a healthy sleep cycle. During this stage, the body begins '
        'to relax, heart rate slows, and the brain prepares to move into deeper restorative stages.',
    benefits: [
      'Supports normal sleep cycling',
      'Helps the body transition between stages',
      'Contributes to overall sleep continuity',
    ],
    factors: [
      'Frequent interruptions can fragment light sleep',
      'Noise and stress may increase awakenings',
      'Poor sleep habits can reduce stable sleep cycles',
    ],
    tip:
        'Improving sleep continuity can make light sleep more stable and reduce night-time disruptions.',
  ),

  SleepStageType.rem: SleepStageInfo(
    type: SleepStageType.rem,
    title: 'REM Sleep',
    subtitle: 'Dream-rich sleep linked to memory and emotion',
    description:
        'REM sleep is the stage most associated with vivid dreaming, emotional processing, '
        'and memory consolidation. Brain activity becomes more active during REM, while the body '
        'remains deeply relaxed. REM periods often become longer later in the night, which is why '
        'cutting sleep short can reduce REM opportunity.',
    benefits: [
      'Supports memory consolidation and learning',
      'Helps emotional processing and mental recovery',
      'Plays an important role in cognitive performance',
    ],
    factors: [
      'Short sleep duration can reduce REM time',
      'Stress may disturb REM balance',
      'Alcohol and poor sleep routines can interfere with healthy REM cycles',
    ],
    tip:
        'Getting enough total sleep is one of the best ways to preserve healthy REM sleep.',
  ),

  SleepStageType.awake: SleepStageInfo(
    type: SleepStageType.awake,
    title: 'Awake Time',
    subtitle: 'Brief awakenings and sleep interruptions',
    description:
        'Awake periods during the night are common and do not always mean poor sleep. '
        'However, frequent or prolonged awakenings can reduce sleep continuity and make sleep '
        'feel less restorative. Looking at awake periods can help identify sleep fragmentation '
        'and overall sleep quality trends.',
    benefits: [
      'Helps reveal sleep interruptions',
      'Can indicate fragmented or unstable sleep',
      'Useful for understanding overall sleep quality',
    ],
    factors: [
      'Stress and anxiety may increase awakenings',
      'Noise, light, or temperature changes can interrupt sleep',
      'Caffeine late in the day may affect sleep continuity',
    ],
    tip:
        'Reducing interruptions in your sleep environment can help lower awake time during the night.',
  ),
};