import '../models/questionnaire.dart';

const essQuestions = <QuestionnaireQuestion>[
  QuestionnaireQuestion(
    text: 'Sitting and reading',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Watching TV',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Sitting inactive in a public place',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Passenger in a car for one hour without a break',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Lying down to rest in the afternoon',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Sitting and talking to someone',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Sitting quietly after lunch (no alcohol)',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'In a car stopped in traffic for a few minutes',
    options: [
      QuestionnaireOption(text: 'Would never doze', score: 0),
      QuestionnaireOption(text: 'Slight chance of dozing', score: 1),
      QuestionnaireOption(text: 'Moderate chance of dozing', score: 2),
      QuestionnaireOption(text: 'High chance of dozing', score: 3),
    ],
  ),
];

const isiQuestions = <QuestionnaireQuestion>[
  QuestionnaireQuestion(
    text: 'Difficulty falling asleep',
    options: [
      QuestionnaireOption(text: 'None', score: 0),
      QuestionnaireOption(text: 'Mild', score: 1),
      QuestionnaireOption(text: 'Moderate', score: 2),
      QuestionnaireOption(text: 'Severe', score: 3),
      QuestionnaireOption(text: 'Very severe', score: 4),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Difficulty staying asleep',
    options: [
      QuestionnaireOption(text: 'None', score: 0),
      QuestionnaireOption(text: 'Mild', score: 1),
      QuestionnaireOption(text: 'Moderate', score: 2),
      QuestionnaireOption(text: 'Severe', score: 3),
      QuestionnaireOption(text: 'Very severe', score: 4),
    ],
  ),
  QuestionnaireQuestion(
    text: 'Waking too early',
    options: [
      QuestionnaireOption(text: 'None', score: 0),
      QuestionnaireOption(text: 'Mild', score: 1),
      QuestionnaireOption(text: 'Moderate', score: 2),
      QuestionnaireOption(text: 'Severe', score: 3),
      QuestionnaireOption(text: 'Very severe', score: 4),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How satisfied are you with your current sleep?',
    options: [
      QuestionnaireOption(text: 'Very satisfied', score: 0),
      QuestionnaireOption(text: 'Satisfied', score: 1),
      QuestionnaireOption(text: 'Somewhat dissatisfied', score: 2),
      QuestionnaireOption(text: 'Dissatisfied', score: 3),
      QuestionnaireOption(text: 'Very dissatisfied', score: 4),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How noticeable is your sleep problem to others?',
    options: [
      QuestionnaireOption(text: 'Not noticeable', score: 0),
      QuestionnaireOption(text: 'A little', score: 1),
      QuestionnaireOption(text: 'Somewhat', score: 2),
      QuestionnaireOption(text: 'Much', score: 3),
      QuestionnaireOption(text: 'Very much', score: 4),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How worried/distressed are you about sleep problems?',
    options: [
      QuestionnaireOption(text: 'Not at all', score: 0),
      QuestionnaireOption(text: 'A little', score: 1),
      QuestionnaireOption(text: 'Somewhat', score: 2),
      QuestionnaireOption(text: 'Much', score: 3),
      QuestionnaireOption(text: 'Very much', score: 4),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How much do sleep problems interfere with daily functioning?',
    options: [
      QuestionnaireOption(text: 'Not at all', score: 0),
      QuestionnaireOption(text: 'A little', score: 1),
      QuestionnaireOption(text: 'Somewhat', score: 2),
      QuestionnaireOption(text: 'Much', score: 3),
      QuestionnaireOption(text: 'Very much', score: 4),
    ],
  ),
];

const psqiQuestions = <QuestionnaireQuestion>[
  QuestionnaireQuestion(
    text: 'How would you rate your sleep quality overall?',
    options: [
      QuestionnaireOption(text: 'Very good', score: 0),
      QuestionnaireOption(text: 'Fairly good', score: 1),
      QuestionnaireOption(text: 'Fairly bad', score: 2),
      QuestionnaireOption(text: 'Very bad', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How often did it take more than 30 minutes to fall asleep?',
    options: [
      QuestionnaireOption(text: 'Not during the past month', score: 0),
      QuestionnaireOption(text: 'Less than once a week', score: 1),
      QuestionnaireOption(text: 'Once or twice a week', score: 2),
      QuestionnaireOption(text: 'Three or more times a week', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How often did you wake during the night?',
    options: [
      QuestionnaireOption(text: 'Not during the past month', score: 0),
      QuestionnaireOption(text: 'Less than once a week', score: 1),
      QuestionnaireOption(text: 'Once or twice a week', score: 2),
      QuestionnaireOption(text: 'Three or more times a week', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How often did you wake too early and could not return to sleep?',
    options: [
      QuestionnaireOption(text: 'Not during the past month', score: 0),
      QuestionnaireOption(text: 'Less than once a week', score: 1),
      QuestionnaireOption(text: 'Once or twice a week', score: 2),
      QuestionnaireOption(text: 'Three or more times a week', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How often was sleep disturbed by noise, heat, light, or discomfort?',
    options: [
      QuestionnaireOption(text: 'Not during the past month', score: 0),
      QuestionnaireOption(text: 'Less than once a week', score: 1),
      QuestionnaireOption(text: 'Once or twice a week', score: 2),
      QuestionnaireOption(text: 'Three or more times a week', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How often did you struggle to stay awake during daily activities?',
    options: [
      QuestionnaireOption(text: 'Not during the past month', score: 0),
      QuestionnaireOption(text: 'Less than once a week', score: 1),
      QuestionnaireOption(text: 'Once or twice a week', score: 2),
      QuestionnaireOption(text: 'Three or more times a week', score: 3),
    ],
  ),
  QuestionnaireQuestion(
    text: 'How much of a problem was low enthusiasm to get things done?',
    options: [
      QuestionnaireOption(text: 'No problem at all', score: 0),
      QuestionnaireOption(text: 'Only a slight problem', score: 1),
      QuestionnaireOption(text: 'Somewhat of a problem', score: 2),
      QuestionnaireOption(text: 'A very big problem', score: 3),
    ],
  ),
];