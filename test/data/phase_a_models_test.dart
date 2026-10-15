import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/data/models/habit.dart';
import 'package:lifeos_mobile/data/models/task.dart';

void main() {
  group('Reminder', () {
    test('a repeating reminder carries its next times', () {
      final r = Reminder.fromJson({
        'id': 'r1',
        'text': 'Drink water',
        'remindAt': '2026-10-16T03:30:00.000Z',
        'repeatRule': 'FREQ=DAILY;TIMES=09:00,11:00',
        'occurrences': ['2026-10-16T03:30:00.000Z', '2026-10-16T05:30:00.000Z', '2026-10-17T03:30:00.000Z'],
      });
      expect(r.repeats, isTrue);
      expect(r.occurrences, hasLength(3));
      expect(r.occurrences[1].isUtc, isFalse); // shown in local time
    });

    test('an older server without occurrences still gives one time', () {
      final r = Reminder.fromJson({'id': 'r2', 'text': 'Call mom', 'remindAt': '2026-10-16T12:30:00.000Z'});
      expect(r.repeats, isFalse);
      expect(r.occurrences, [r.remindAt]);
    });
  });

  test('a to-do made from a save finds its link in the description', () {
    final t = Task.fromJson({
      'id': 't1',
      'title': '10 min walk',
      'status': 'TODO',
      'description': 'From your save: Morning walk\nhttps://www.instagram.com/reel/abc/',
    });
    expect(t.sourceUrl, 'https://www.instagram.com/reel/abc/');
    expect(Task.fromJson({'id': 't2', 'title': 'x', 'description': 'no link'}).sourceUrl, isNull);
  });

  test('a habit keeps its source link', () {
    final h = Habit.fromJson({'id': 'h1', 'title': 'Walk', 'sourceUrl': 'https://youtu.be/xyz'});
    expect(h.sourceUrl, 'https://youtu.be/xyz');
  });
}
