import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/area.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';
import 'package:lifeos_mobile/features/week/review_rules.dart';
import 'package:lifeos_mobile/features/week/review_screen.dart';

// Generic sample: one Push, one Maintain, one Explore, one resting area.
Map<String, dynamic> _overview() => {
      'areas': [
        {
          'id': 'w', 'name': 'Work', 'mode': 'PUSH', 'weeklyMinutes': 240, 'minutes': 180, 'value': 0.75, 'status': '3 h of 4 h',
          'nextSteps': [
            {'id': 's1', 'title': 'Update the CV'},
            {'id': 's2', 'title': 'Two applications'},
          ],
        },
        {'id': 'h', 'name': 'Health', 'mode': 'MAINTAIN', 'minutes': 0, 'plannedMinutes': 0, 'value': 0, 'status': 'Quiet this week'},
        {
          'id': 'p', 'name': 'Painting', 'mode': 'EXPLORE', 'weeklyMinutes': 60, 'minutes': 30, 'value': 0.5, 'status': 'One taste done',
          'nextSteps': [
            {'id': 's3', 'title': 'Try watercolour'},
          ],
        },
        {'id': 'r', 'name': 'Music', 'mode': 'REST', 'minutes': 0, 'value': 0, 'status': 'Resting'},
      ],
      'capacity': {'neededMinutes': 360, 'freeMinutes': 420},
    };

class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool failMove = false;
  bool oldServer = false;
  bool noAreas = false;

  @override
  Future<Map<String, dynamic>> areasOverview() async {
    if (oldServer) throw const ApiException('Not found', statusCode: 404);
    return _overview();
  }

  @override
  Future<List<Area>> areas() async => noAreas ? [] : [Area.fromJson({'id': 'w', 'name': 'Work', 'tier': 'MAIN', 'tasksDone': 1, 'tasksTotal': 4})];

  @override
  Future<Area> updateArea(String id,
      {String? name, String? type, String? color, String? icon, bool? isActive, String? tier, int? weeklyMinutes, bool clearWeeklyMinutes = false, String? nextTier, DateTime? nextTierOn, bool clearPlanned = false}) async {
    calls.add('time:$id:${clearWeeklyMinutes ? 'none' : weeklyMinutes}');
    return Area.fromJson({'id': id, 'name': id});
  }

  @override
  Future<({String message, String? activityId})> moveStep(String id, String when) async {
    if (failMove) throw const ApiException('No connection');
    calls.add('move:$id:$when');
    return (message: 'Moved.', activityId: 'act-move');
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _open(WidgetTester t, _Repo repo, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final key = GlobalKey<NavigatorState>();
  await t.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
  key.currentState!.push(MaterialPageRoute<void>(builder: (_) => ReviewScreen(repo: repo)));
  await t.pump();
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

Future<void> _next(WidgetTester t) => _tap(t, find.text('Next'));

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('rules', () {
    AreaStanding area(AreaMode mode, {int? weekly, int planned = 0}) =>
        AreaStanding(id: 'a', name: 'A', mode: mode, weeklyMinutes: weekly, plannedMinutes: planned, value: 0, status: '');

    test('starts from the set time, else this week\'s plan, else a small default', () {
      expect(startingMinutes(area(AreaMode.push, weekly: 200)), 200);
      expect(startingMinutes(area(AreaMode.maintain, planned: 50)), 45);
      expect(startingMinutes(area(AreaMode.push)), 180);
      expect(startingMinutes(area(AreaMode.explore)), 60);
    });

    test('too much takes a quarter off, never to zero; a bit more adds a quarter', () {
      expect(adjusted(240, PlanFeel.light), 180);
      expect(adjusted(240, PlanFeel.more), 300);
      expect(adjusted(15, PlanFeel.light), 15);
      expect(adjusted(240, PlanFeel.same), 240);
    });

    test('due Saturday to Monday', () {
      expect(reviewIsDue(DateTime(2026, 11, 14)), isTrue); // Saturday
      expect(reviewIsDue(DateTime(2026, 11, 15)), isTrue); // Sunday
      expect(reviewIsDue(DateTime(2026, 11, 16)), isTrue); // Monday
      expect(reviewIsDue(DateTime(2026, 11, 19)), isFalse); // Thursday
    });

    test('only changed time is saved; over free time is said plainly', () {
      final areas = [area(AreaMode.push, weekly: 240)];
      expect(timeChanges(areas, {'a': 240}), isEmpty);
      expect(timeChanges(areas, {'a': 180}).single.before, 240);
      expect(overNote(400, 420), isNull);
      expect(overNote(450, 420), contains('30 min more'));
      expect(minutesLabel(90), '1 h 30');
    });
  });

  testWidgets('four steps: what moved, plans, time, weekend; saved together, undone together', (t) async {
    final repo = _Repo();
    await _open(t, repo);
    expect(find.text('What moved'), findsOneWidget);
    expect(find.text('Music'), findsNothing); // resting areas are not reviewed
    expect(find.text('Nothing · Quiet this week'), findsOneWidget);
    expect(find.textContaining('Counts, not grades'), findsOneWidget);

    await _next(t);
    expect(find.text('Plans for next week'), findsOneWidget);
    expect(find.text('Next: Update the CV · Two applications'), findsOneWidget);
    await _tap(t, find.text('Too much'));

    await _next(t);
    expect(find.text('Time for next week'), findsOneWidget);
    expect(find.text('3 h'), findsOneWidget); // Work: 4 h, a quarter less
    await _tap(t, find.byTooltip('More for Health'));
    expect(find.text('1 h 15'), findsOneWidget);

    await _next(t);
    expect(find.text('Next weekend'), findsOneWidget);
    await _tap(t, find.text('Painting'));
    expect(find.text('Moves "Try watercolour" to the weekend.'), findsOneWidget);
    await _tap(t, find.text('Set next week'));
    expect(repo.calls, ['time:w:180', 'time:h:75', 'move:s3:WEEKEND']);
    expect(find.text('Next week is set.'), findsOneWidget);

    await _tap(t, find.text('Undo'));
    expect(repo.calls.skip(3), ['time:w:240', 'time:h:none', 'undo:act-move']);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('only time that differs from what is stored is saved', (t) async {
    final repo = _Repo();
    await _open(t, repo);
    // Health has no stored time, so its starting hour is saved; the rest is unchanged.
    for (var i = 0; i < 3; i++) {
      await _next(t);
    }
    await _tap(t, find.text('Set next week'));
    expect(repo.calls, ['time:h:60']);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a failure part way puts back what was saved', (t) async {
    final repo = _Repo()..failMove = true;
    await _open(t, repo);
    await _next(t);
    await _tap(t, find.text('A bit more'));
    await _next(t);
    await _next(t);
    await _tap(t, find.text('Painting'));
    await _tap(t, find.text('Set next week'));
    expect(repo.calls, ['time:w:300', 'time:h:60', 'time:w:240', 'time:h:none']);
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Next weekend'), findsOneWidget); // still open, to try again
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('an older server: weekly time is not offered, the weekend still saves', (t) async {
    final repo = _Repo()..oldServer = true;
    await _open(t, repo);
    expect(find.textContaining('1 of 4 to-dos done'), findsOneWidget);
    await _next(t);
    await _next(t);
    expect(find.textContaining('needs the latest server'), findsOneWidget);
    await _next(t);
    await _tap(t, find.text('Set next week'));
    expect(repo.calls, isEmpty);
    expect(find.text('Next week stays as it is.'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('no active areas: one plain sentence', (t) async {
    final repo = _Repo()
      ..oldServer = true
      ..noAreas = true;
    await _open(t, repo);
    expect(find.text('Nothing to review yet'), findsOneWidget);
  });

  testWidgets('fits a small phone at large text on every step', (t) async {
    await _open(t, _Repo(), size: const Size(320, 640), textScale: 1.5);
    for (var i = 0; i < 4; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -1200));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull, reason: 'step ${i + 1}');
      if (i < 3) await _next(t);
    }
  });
}
