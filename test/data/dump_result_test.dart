import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/dump_result.dart';

void main() {
  test('reads the sorted dump and the time check', () {
    final r = DumpResult.fromJson({
      'groups': {
        'DATED': [
          {'id': 't1', 'title': 'Book exam date', 'due': '2026-11-20'},
        ],
        'THIS_WEEK': [
          {'id': 't2', 'title': 'Call mom kal', 'due': null},
        ],
        'LATER': [
          {'id': 't3', 'title': 'Start DSA', 'due': null},
          {'id': 't4', 'title': 'Fix the geyser', 'due': null},
        ],
      },
      'added': 4,
      'alreadyThere': 1,
      'fits': false,
      'line': 'All of this needs about 31 h a week. You have about 11 h free.',
      'hasSeason': false,
      'activityId': 'act-9',
    });
    expect(r.dated.single.due, DateTime(2026, 11, 20)); // a plain date, read as that local day
    expect(r.thisWeek.single.title, 'Call mom kal');
    expect(r.later, hasLength(2));
    expect((r.added, r.alreadyThere, r.fits, r.hasSeason, r.activityId), (4, 1, false, false, 'act-9'));
  });
}
