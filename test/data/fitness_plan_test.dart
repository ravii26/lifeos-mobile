import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/fitness_plan.dart';

void main() {
  test('answers leave out what was skipped', () {
    final a = FitnessAnswers()
      ..weightKg = 83
      ..health = 'JOINT'
      ..outsideOften = true;
    final j = a.toJson();
    expect(j['weightKg'], 83);
    expect(j.containsKey('diet'), isFalse); // skipped, not sent as null
    expect(j.containsKey('heightCm'), isFalse);
    expect(j['health'], 'JOINT');
    expect(j['outsideOften'], isTrue);
  });

  test('a Sunday check-in preview', () {
    final c = CheckinPreview.fromJson({
      'week': 1,
      'weeks': 8,
      'done': 3,
      'planned': 4,
      'verdict': 'SAME',
      'message': "You're doing fine. Same plan next week.",
      'sessions': [
        {'title': 'Brisk walk', 'minutes': 30, 'days': ['TUE', 'THU', 'SAT'], 'changed': 'now Tue, Thu, Sat'},
        {'title': 'Gym', 'minutes': 40, 'days': ['MON', 'WED', 'FRI'], 'changed': null},
      ],
      'askWeight': true,
      'lastWeight': 83,
      'alreadyDone': false,
    })!;
    expect(c.done, 3);
    expect(c.sessions.first.changed, 'now Tue, Thu, Sat');
    expect(c.sessions.last.changed, isNull);
    expect(c.lastWeight, 83);
    expect(CheckinPreview.fromJson(null), isNull);
  });

  test('a plan from the server, with and without a weight target', () {
    final p = FitnessPlan.fromJson({
      'title': '83 → 79 kg, belly first',
      'phaseWeeks': 8,
      'weight': {'start': 83, 'target': 79},
      'sessions': [
        {'key': 'STRENGTH', 'title': 'Gym: knee-friendly strength + cycling', 'minutes': 40, 'smallest': 'A 15-minute walk counts', 'days': ['MON', 'WED', 'FRI'], 'week1Days': ['MON', 'WED', 'FRI'], 'detail': 'Day A: …'},
      ],
      'foodRules': ['Protein in every meal'],
      'lifeRules': ['Party: protein first'],
      'cautions': ['General guidance, not medical advice.'],
    });
    expect(p.startKg, 83);
    expect(p.targetKg, 79);
    expect(p.sessions.single.days, ['MON', 'WED', 'FRI']);
    expect(FitnessPlan.fromJson({'title': 'Build muscle', 'weight': null}).startKg, isNull);
    expect(RunningPlan.fromJson(null), isNull);
    expect(RunningPlan.fromJson({'title': 'x', 'week': 2, 'weeks': 8})!.week, 2);
  });
}
