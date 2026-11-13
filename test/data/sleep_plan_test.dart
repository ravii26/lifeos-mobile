import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/sleep_plan.dart';

// The preview must match the server's ladder (sleep.rules.test.ts), or setup
// would show one plan and save another.
void main() {
  test('the agreed plan: wake 8 → 7, 6:30, 6:00 with 7 hours', () {
    expect(previewLadder('08:00', '06:00', 420), const [
      SleepStep(1, '07:00', '24:00'),
      SleepStep(2, '06:30', '23:30'),
      SleepStep(3, '06:00', '23:00'),
    ]);
  });

  test('already close to the target, or earlier than it', () {
    expect(previewLadder('06:30', '06:00', 420), const [SleepStep(1, '06:30', '23:30'), SleepStep(2, '06:00', '23:00')]);
    expect(previewLadder('05:30', '06:00', 420), const [SleepStep(1, '06:00', '23:00')]);
  });

  test('a late riser gets their own plan, with bedtimes after midnight', () {
    expect(previewLadder('10:30', '09:00', 480), const [
      SleepStep(1, '10:00', '02:00'),
      SleepStep(2, '09:30', '01:30'),
      SleepStep(3, '09:00', '01:00'),
    ]);
  });

  test('clock labels read naturally', () {
    expect(clockLabel('24:00'), '12:00 midnight');
    expect(clockLabel('06:30'), '6:30 am');
    expect(clockLabel('23:00'), '11:00 pm');
  });

  test('a plan from the server', () {
    final p = SleepPlan.fromJson({
      'targetWake': '06:00',
      'hours': 420,
      'step': 2,
      'done': false,
      'steps': [
        {'week': 1, 'wake': '07:00', 'sleep': '24:00'},
        {'week': 2, 'wake': '06:30', 'sleep': '23:30'},
        {'week': 3, 'wake': '06:00', 'sleep': '23:00'},
      ],
    })!;
    expect(p.current, const SleepStep(2, '06:30', '23:30'));
    expect(SleepPlan.fromJson(null), isNull);
  });
}
