import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The four ways to start (doc 17): each is a short guided chat, one question
/// at a time, answered with a tap (typing always works too). The answers
/// become one plain message to Ally, so the server's normal chat does the work.
enum Starter { goal, reminder, habit, video, teach }

/// The four big ways to start, shown on an empty Now (teach lives in Notes).
const nowStarters = [Starter.goal, Starter.reminder, Starter.habit, Starter.video];

/// Another place (an empty Plan or Notes) asks to start one: the shell
/// switches to Now and the chat opens the guided questions.
final ValueNotifier<Starter?> starterRequest = ValueNotifier<Starter?>(null);

extension StarterInfo on Starter {
  String get label => switch (this) {
        Starter.goal => 'Plan a goal',
        Starter.reminder => 'Remind me of something',
        Starter.habit => 'Build a daily habit',
        Starter.video => 'Turn a video into action',
        Starter.teach => 'Teach Ally something',
      };

  String get short => switch (this) {
        Starter.goal => 'Plan a goal',
        Starter.reminder => 'Remind me',
        Starter.habit => 'Daily habit',
        Starter.video => 'Video to action',
        Starter.teach => 'Teach Ally',
      };

  String get example => switch (this) {
        Starter.goal => 'e.g. learn guitar, get a new job',
        Starter.reminder => 'e.g. call mom, pay rent',
        Starter.habit => 'e.g. drink water, read',
        Starter.video => 'a YouTube or Instagram link',
        Starter.teach => 'e.g. your breakfast options',
      };

  IconData get icon => switch (this) {
        Starter.goal => Icons.flag_outlined,
        Starter.reminder => Icons.alarm_rounded,
        Starter.habit => Icons.repeat_rounded,
        Starter.video => Icons.play_circle_outline_rounded,
        Starter.teach => Icons.edit_note_rounded,
      };
}

class StarterStep {
  final String key;
  final String question;
  final List<String> chips;
  final String hint; // placeholder in the text box while this question is open
  final bool canSkip;
  const StarterStep(this.key, this.question, this.chips, {this.hint = 'Or type it…', this.canSkip = false});
}

const freeChips = ['Mornings', 'Evenings', 'Morning and evening', 'Most of the day'];

const _habitMinimum = {
  'Drink water': 'one glass of water',
  'Walk': 'a 2-minute walk',
  'Read': 'read one page',
  'Exercise': '5 push-ups',
  'Meditate': 'one minute of breathing',
};

/// The next question for [s] given the answers so far, or null when done.
/// [askFree]: Ally doesn't know the person's day yet (goal plans need it).
StarterStep? nextStep(Starter s, Map<String, String> a, {required bool askFree, required DateTime now}) {
  for (final step in steps(s, a, askFree: askFree, now: now)) {
    if (!a.containsKey(step.key)) return step;
  }
  return null;
}

/// All questions for [s] (later ones can depend on earlier answers).
List<StarterStep> steps(Starter s, Map<String, String> a, {required bool askFree, required DateTime now}) {
  switch (s) {
    case Starter.goal:
      return [
        const StarterStep('what', "What's the goal?", ['Get fit', 'Learn a new skill', 'Find a new job', 'Read more books'],
            hint: 'Or type your own, e.g. learn guitar'),
        const StarterStep('when', 'By when?', ['1 month', '3 months', '6 months', 'No date']),
        if (askFree) const StarterStep('free', 'When are you usually free for it?', freeChips, canSkip: true),
      ];
    case Starter.reminder:
      return [
        const StarterStep('what', 'What should I remind you about?', ['Call mom', 'Pay a bill', 'Take medicine'],
            hint: 'Or type it, e.g. renew passport'),
        StarterStep('time', 'When?', reminderChips(now)),
      ];
    case Starter.habit:
      final habit = a['what'];
      final min = habit == null ? null : _habitMinimum[habit];
      return [
        const StarterStep('what', 'Which habit?', ['Drink water', 'Walk', 'Read', 'Exercise', 'Meditate'], hint: 'Or type your own…'),
        const StarterStep('part', 'When in your day?', ['Morning', 'After work', 'Before bed']),
        StarterStep(
          'min',
          'On a hard day, what is the smallest version that still counts?',
          [?min, '2 minutes of it'],
          hint: 'Or type it…',
          canSkip: true,
        ),
      ];
    case Starter.teach:
      return [
        const StarterStep('topic', 'What should I know about you?',
            ['My breakfast options', 'My gym routine', 'My work hours', 'Shows I want to watch'],
            hint: 'Or type a topic'),
        StarterStep('details', 'Tell me the details. I will answer from this later.', const [],
            hint: a['topic'] == 'My breakfast options' ? 'e.g. poha, oats, eggs, upma' : 'Type the details'),
      ];
    case Starter.video:
      return [
        const StarterStep(
          'link',
          'Paste a YouTube or Instagram link. I will turn it into something you can do.\n\n'
              'Tip: next time, tap Share in YouTube or Instagram and pick Ally.',
          ['Paste from clipboard'],
          hint: 'Paste the link here',
        ),
      ];
  }
}

/// Time choices that make sense right now ("This evening" disappears after 6 pm).
List<String> reminderChips(DateTime now) => [
      'In 1 hour',
      if (now.hour < 18) 'This evening',
      'Tomorrow morning',
      'Every day at 9 am',
    ];

// "Call mom" from a chip reads as "remind me to call mom".
String _lowerFirst(String s) =>
    s.length > 1 && s[1] == s[1].toLowerCase() ? s[0].toLowerCase() + s.substring(1) : s;

String _clock(DateTime t) => DateFormat('h:mm a').format(t).toLowerCase();

String _reminderTime(String answer, DateTime now) {
  switch (answer) {
    case 'In 1 hour':
      final t = now.add(const Duration(hours: 1));
      final day = t.day == now.day ? 'today' : 'tomorrow';
      return '$day at ${_clock(t)}';
    case 'This evening':
      return 'today at 7 pm';
    case 'Tomorrow morning':
      return 'tomorrow at 9 am';
    case 'Every day at 9 am':
      return 'every day at 9 am';
  }
  return answer; // typed: "friday 6pm", "kal subah"…
}

// An exact date, not just "in 3 months": the planner copies a date reliably.
String _deadline(String answer, DateTime now) {
  final months = switch (answer) { '1 month' => 1, '3 months' => 3, '6 months' => 6, _ => 0 };
  if (answer == 'No date') return 'No fixed date.';
  if (months == 0) return 'By when: $answer.';
  final by = DateTime(now.year, now.month + months, now.day);
  return 'I want it done in $answer, by ${DateFormat('d MMM yyyy').format(by)}.';
}

const _habitPart = {'Morning': 'in the morning', 'After work': 'after work', 'Before bed': 'before bed'};

/// The one message the guided answers turn into. Plain words the chat
/// already understands, so nothing new is needed on the server.
String composeMessage(Starter s, Map<String, String> a, DateTime now) {
  switch (s) {
    case Starter.goal:
      return 'Make me a plan for this goal: ${_lowerFirst(a['what'] ?? '')}. ${_deadline(a['when'] ?? 'No date', now)}';
    case Starter.reminder:
      return 'Remind me to ${_lowerFirst(a['what'] ?? '')} ${_reminderTime(a['time'] ?? '', now)}';
    case Starter.habit:
      final part = _habitPart[a['part']] ?? (a['part'] ?? '').toLowerCase();
      final min = a['min'];
      final small = min == null || min.isEmpty ? '' : ' Smallest version: ${min == '2 minutes of it' ? '2 minutes' : min}.';
      return 'Add a daily habit: ${a['what']}, $part.$small';
    case Starter.teach:
      return 'Save a note. ${a['topic']}: ${a['details']}';
    case Starter.video:
      return a['link'] ?? '';
  }
}

/// A rough day from "when are you free", so a first plan fits real time.
/// Exact times can be set later in You → Your day.
({String wake, String sleep, List<int> officeDays, String? start, String? end})? basicsForFree(String answer) {
  const weekdays = [1, 2, 3, 4, 5];
  return switch (answer) {
    'Mornings' => (wake: '06:00', sleep: '22:30', officeDays: weekdays, start: '10:00', end: '20:00'),
    'Evenings' => (wake: '07:30', sleep: '23:30', officeDays: weekdays, start: '09:30', end: '18:30'),
    'Morning and evening' => (wake: '06:30', sleep: '23:00', officeDays: weekdays, start: '10:00', end: '18:30'),
    'Most of the day' => (wake: '07:00', sleep: '23:00', officeDays: const <int>[], start: null, end: null),
    _ => null,
  };
}
