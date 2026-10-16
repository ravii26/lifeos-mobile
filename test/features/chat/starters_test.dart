import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/features/chat/starters.dart';

void main() {
  final noon = DateTime(2026, 10, 16, 12, 0);
  final night = DateTime(2026, 10, 16, 23, 30);

  test('goal asks what, by when, and free time only when the day is unknown', () {
    expect(steps(Starter.goal, {}, askFree: true, now: noon).map((s) => s.key), ['what', 'when', 'free']);
    expect(steps(Starter.goal, {}, askFree: false, now: noon).map((s) => s.key), ['what', 'when']);
    expect(nextStep(Starter.goal, {'what': 'learn guitar'}, askFree: true, now: noon)!.key, 'when');
    expect(nextStep(Starter.goal, {'what': 'x', 'when': '3 months'}, askFree: false, now: noon), isNull);
  });

  test('a goal becomes a plan request the chat already understands', () {
    final m = composeMessage(Starter.goal, {'what': 'learn guitar', 'when': '3 months'}, noon);
    expect(m, 'Make me a plan for this goal: learn guitar. I want it done in 3 months, by 16 Jan 2027.');
    expect(RegExp(r'\bmake\s+me\s+a\s+plan\b', caseSensitive: false).hasMatch(m), isTrue);
    expect(composeMessage(Starter.goal, {'what': 'read more', 'when': 'No date'}, noon), endsWith('No fixed date.'));
  });

  test('reminder times become clock times', () {
    expect(composeMessage(Starter.reminder, {'what': 'call mom', 'time': 'In 1 hour'}, noon), 'Remind me to call mom today at 1:00 pm');
    expect(composeMessage(Starter.reminder, {'what': 'call mom', 'time': 'In 1 hour'}, night), 'Remind me to call mom tomorrow at 12:30 am');
    expect(composeMessage(Starter.reminder, {'what': 'pay rent', 'time': 'Tomorrow morning'}, noon), 'Remind me to pay rent tomorrow at 9 am');
    expect(composeMessage(Starter.reminder, {'what': 'pay rent', 'time': 'friday 6pm'}, noon), 'Remind me to pay rent friday 6pm');
    expect(composeMessage(Starter.reminder, {'what': 'Call mom', 'time': 'Tomorrow morning'}, noon), 'Remind me to call mom tomorrow at 9 am');
    expect(composeMessage(Starter.reminder, {'what': 'GST filing', 'time': 'Tomorrow morning'}, noon), startsWith('Remind me to GST filing'));
  });

  test('"This evening" is not offered once the evening has started', () {
    expect(reminderChips(noon), contains('This evening'));
    expect(reminderChips(DateTime(2026, 10, 16, 19)), isNot(contains('This evening')));
  });

  test('habit offers a smallest version that fits the habit, and it can be skipped', () {
    final min = nextStep(Starter.habit, {'what': 'Drink water', 'part': 'Morning'}, askFree: false, now: noon)!;
    expect(min.chips.first, 'one glass of water');
    expect(min.canSkip, isTrue);
    expect(composeMessage(Starter.habit, {'what': 'Drink water', 'part': 'Morning', 'min': 'one glass of water'}, noon),
        'Add a daily habit: Drink water, in the morning. Smallest version: one glass of water.');
    expect(composeMessage(Starter.habit, {'what': 'Journal', 'part': 'Before bed', 'min': ''}, noon), 'Add a daily habit: Journal, before bed.');
  });

  test('free-time answers give a rough day; skipping gives none', () {
    expect(basicsForFree('Evenings')!.end, '18:30');
    expect(basicsForFree('Most of the day')!.officeDays, isEmpty);
    expect(basicsForFree(''), isNull);
  });

  test('teach asks a topic then the details, and becomes a note', () {
    expect(steps(Starter.teach, {}, askFree: false, now: noon).map((s) => s.key), ['topic', 'details']);
    expect(composeMessage(Starter.teach, {'topic': 'My breakfast options', 'details': 'poha, oats, eggs'}, noon),
        'Save a note. My breakfast options: poha, oats, eggs');
    expect(nowStarters, isNot(contains(Starter.teach)));
  });
}
