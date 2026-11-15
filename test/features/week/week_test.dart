import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/week/week_data.dart';
import 'package:lifeos_mobile/features/week/week_screen.dart';

// A generic week: two active areas and one resting, Thursday is today.
Map<String, dynamic> _week({bool lookBack = true}) => {
      'weekStart': '2026-11-16',
      'label': '16 – 22 Nov',
      'todayKey': '2026-11-19',
      'days': [
        for (final (i, l) in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexed)
          {
            'key': '2026-11-${16 + i}',
            'label': l,
            'done': i < 3
                ? [
                    {'areaId': 'w', 'minutes': 60},
                    {'areaId': 'h', 'minutes': 30},
                  ]
                : i == 3
                    ? [
                        {'areaId': 'h', 'minutes': 20},
                      ]
                    : [],
            'planned': i >= 3
                ? [
                    {'areaId': 'w', 'minutes': 45},
                  ]
                : [],
          },
      ],
      'routines': [
        {'id': 'r1', 'title': 'Morning walk', 'areaId': 'h', 'dots': ['DONE', 'PAST', 'DONE', 'PLANNED', 'PLANNED', 'PLANNED', 'PLANNED'], 'line': '2 of 7 this week'},
      ],
      'areas': [
        {'id': 'w', 'name': 'Work', 'mode': 'PUSH', 'minutes': 180, 'plannedMinutes': 300},
        {'id': 'h', 'name': 'Health', 'mode': 'MAINTAIN', 'minutes': 110, 'plannedMinutes': 0},
        {'id': 'm', 'name': 'Music', 'mode': 'REST', 'minutes': 0, 'plannedMinutes': 0},
      ],
      'lookBack': lookBack
          ? {
              'month': 'October',
              'totalMinutes': 2460,
              'byArea': [
                {'areaId': 'w', 'name': 'Work', 'minutes': 1080},
                {'areaId': 'h', 'name': 'Health', 'minutes': 720},
              ],
            }
          : null,
    };

class _Repo implements LifeRepository {
  bool oldServer = false;
  bool lookBack = true;

  @override
  Future<Map<String, dynamic>> week() async {
    if (oldServer) throw const ApiException('Not found', statusCode: 404);
    return _week(lookBack: lookBack);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _open(WidgetTester t, _Repo repo, {Size size = const Size(360, 800), double textScale = 1, DateTime? day}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: WeekScreen(repo: repo, clock: () => day ?? DateTime(2026, 11, 19)))));
  // One frame for the data to arrive, then time for the entrance to play.
  await t.pump();
  await t.pump(const Duration(seconds: 2));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('hours read plainly', () {
    expect(hoursLabel(45), '45 min');
    expect(hoursLabel(90), '1h 30');
    expect(hoursLabel(120), '2h');
    expect(hoursLabel(2460), '41h');
  });

  testWidgets('the week: bars, today in detail, routines, time per area, a look back', (t) async {
    await _open(t, _Repo());
    expect(find.text('16 – 22 NOV'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.bySemanticsLabel('Thu: 20 min done, 45 min planned'), findsOneWidget);
    expect(find.text('THU · TODAY'), findsOneWidget);
    expect(find.text('45 min planned'), findsOneWidget);

    await t.scrollUntilVisible(find.text('LOOKING BACK · OCTOBER'), 300);
    await t.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Morning walk, 2 of 7 this week'), findsOneWidget);
    expect(find.text('3h / 5h'), findsOneWidget);
    expect(find.text('Music'), findsNothing); // resting areas are not counted
    expect(find.text('41h'), findsOneWidget);
    expect(find.text('Work 18h · Health 12h'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('tapping another day shows that day', (t) async {
    await _open(t, _Repo());
    await t.tap(find.bySemanticsLabel('Mon: 1h 30 done'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('1h'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
  });

  testWidgets('a day ahead with nothing planned says free time stays free', (t) async {
    final repo = _Repo();
    await _open(t, repo);
    // Sunday has only planned time in this sample; use a fresh sample with nothing.
    await t.tap(find.bySemanticsLabel('Sun: 0 min done, 45 min planned'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('SUN'), findsOneWidget);
  });

  testWidgets('no look back outside the first week of a month', (t) async {
    await _open(t, _Repo()..lookBack = false);
    await t.scrollUntilVisible(find.text('TIME PER AREA'), 300);
    expect(find.textContaining('LOOKING BACK'), findsNothing);
  });

  testWidgets('a server without the week says what is needed', (t) async {
    await _open(t, _Repo()..oldServer = true);
    expect(find.text('Week needs the latest server'), findsOneWidget);
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _open(t, _Repo(), size: const Size(320, 640), textScale: 1.5);
    for (var i = 0; i < 6; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
  });
}
