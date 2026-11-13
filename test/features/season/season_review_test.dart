import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/season.dart';
import 'package:lifeos_mobile/features/season/season_review_screen.dart';

SeasonReview _review() => SeasonReview.fromJson({
      'season': {'number': 1, 'name': 'Switch & Shape', 'startedAt': '2026-11-16T00:00:00Z', 'week': 10, 'weeks': 10, 'over': true, 'endEvent': 'when I switch jobs', 'line': 'x'},
      'lines': ['23 things done this season.', '4 things dropped on purpose. That counts too.'],
      'areas': [
        {'id': 'career', 'name': 'Career', 'place': 'FOCUS', 'done': 23},
      ],
      'parked': [
        {'id': 'business', 'name': 'Business', 'why': '7 things waiting', 'waiting': 7},
        {'id': 'music', 'name': 'Music', 'why': 'Nothing saved yet', 'waiting': 0},
      ],
      'next': {'number': 2, 'focusIds': ['fitness'], 'keepGoingIds': ['career', 'english', 'calm']},
      'canLightWeek': true,
    });

void main() {
  test('reads the review the server sends', () {
    final r = _review();
    expect(r.season.over, isTrue);
    expect(r.season.endEvent, 'when I switch jobs');
    expect(r.lines, hasLength(2));
    expect(r.areas.single.done, 23);
    expect(r.parked.first.why, '7 things waiting');
    expect(r.nextNumber, 2);
    expect(r.canLightWeek, isTrue);
  });

  test('a parked area brought back takes the free focus slot first', () {
    final n = nextWithBroughtBack(_review(), ['business']);
    expect(n.focusIds, ['fitness', 'business']);
    expect(n.keepGoingIds, ['career', 'english', 'calm']);
  });

  test('past the caps, brought-back areas wait instead of overfilling', () {
    final n = nextWithBroughtBack(_review(), ['business', 'music']);
    expect(n.focusIds, hasLength(2));
    expect(n.keepGoingIds, hasLength(3));
    expect([...n.focusIds, ...n.keepGoingIds], isNot(contains('music')));
  });
}
