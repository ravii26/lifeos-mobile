import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';

void main() {
  test('a weekly-target session carries its count', () {
    final o = NowOption.fromJson({
      'sourceType': 'PROJECT',
      'sourceId': 'p1',
      'title': 'Job applications: 2 applications',
      'minutes': 20,
      'smaller': false,
      'minimum': 'Two minutes on it counts.',
      'why': "You're 3 applications behind this week.",
      'count': 2,
    });
    expect(o.sourceType, 'PROJECT');
    expect(o.count, 2);
  });

  test('advice comes with its choices', () {
    final a = NowAdvice.fromJson({
      'kind': 'KEEPS_SLIPPING',
      'message': 'Clean the desk keeps slipping.',
      'sourceType': 'TASK',
      'sourceId': 't1',
      'actions': [
        {'label': 'Make it smaller', 'choice': 'SMALLER'},
        {'label': 'Weekend', 'choice': 'WEEKEND'},
        {'label': 'Let it go', 'choice': 'LET_GO'},
      ],
    })!;
    expect(a.actions.map((x) => x.$2), ['SMALLER', 'WEEKEND', 'LET_GO']);
    expect(NowAdvice.fromJson(null), isNull);
  });
}
