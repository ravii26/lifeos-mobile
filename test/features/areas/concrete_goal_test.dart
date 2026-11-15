import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';
import 'package:lifeos_mobile/features/areas/concrete_goal_screen.dart';

// Generic sample goal; nothing personal.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool byCode = false;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> proposeGoalPlan(String text, {String? why, String? done, int? weeklyMinutes}) async {
    calls.add('propose:$text|$why|$done|$weeklyMinutes');
    if (fail) throw const ApiException('No connection');
    return {
      'plan': {
        'title': text,
        'why': why,
        'deadline': null,
        'targets': [
          {'title': 'Practice', 'unit': 'min', 'perWeek': 60, 'countUnit': null, 'sessionMinutes': 20},
        ],
        'milestones': ['First full song'],
        'steps': [
          {'title': 'Pick three songs you like', 'minutes': 15},
          {'title': 'Learn the first chords', 'minutes': 30},
        ],
        'question': null,
      },
      'fit': {'message': 'That would take about 2 h a week. You said about 1 h, so each part is scaled to that.'},
      'caution': null,
      'aiAvailable': !byCode,
      'draftedBy': byCode ? 'CODE' : 'AI',
    };
  }

  @override
  Future<Map<String, dynamic>> acceptGoalPlan(Map<String, dynamic> plan, {bool park = false, String? parkUntil, String? areaId}) async {
    calls.add('accept:${plan['title']}|$areaId');
    return {
      'goalId': 'g1',
      'activityId': 'act-keep',
      'firstStep': {'id': 't1', 'title': 'Pick three songs you like', 'minutes': 15},
    };
  }

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {'id': 'a1', 'name': 'Music', 'mode': 'EXPLORE', 'value': 0, 'status': 'Not started yet', 'goals': [], 'nextSteps': [], 'routines': []},
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    calls.add('respond:$sourceType:$sourceId:$action');
    return 'act-done';
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _size(WidgetTester t, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

/// The three questions, answered with the generic choices.
Future<void> _answer(WidgetTester t) async {
  await t.enterText(find.widgetWithText(TextField, 'In your own words'), 'Learn to play the guitar');
  await t.pump();
  await _tap(t, find.text('I enjoy it'));
  await _tap(t, find.text('Next'));
  await _tap(t, find.text('Just try it a few times'));
  await _tap(t, find.text('Next'));
  await _tap(t, find.text('1h'));
  await _tap(t, find.text('Draft my plan'));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('three answers → a draft with first steps, sent with the time given', (t) async {
    await _size(t);
    final repo = _Repo();
    KeptPlan? kept;
    final key = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
    key.currentState!
        .push<KeptPlan>(MaterialPageRoute(builder: (_) => ConcreteGoalScreen(areaId: 'a1', areaName: 'Music', repo: repo)))
        .then((r) => kept = r);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));

    expect(find.text('What do you want?'), findsOneWidget);
    await _answer(t);
    expect(repo.calls.single, 'propose:Learn to play the guitar|I enjoy it|Just try it a few times|60');
    expect(find.text('DRAFT 1 · GOOD ENOUGH TO START'), findsOneWidget);
    expect(find.text('Pick three songs you like'), findsOneWidget);
    expect(find.text('First full song'), findsOneWidget);
    expect(find.textContaining('You said about 1 h'), findsOneWidget);
    expect(find.text('Start step one · 15 min'), findsOneWidget);

    await _tap(t, find.text('Save, start later'));
    expect(repo.calls.last, 'accept:Learn to play the guitar|a1');
    expect(kept!.startNow, isFalse);
    expect(kept!.stepId, 't1');
  });

  testWidgets('the goal is needed before going on; Back goes one question back', (t) async {
    await _size(t);
    await t.pumpWidget(MaterialApp(home: ConcreteGoalScreen(areaId: 'a1', areaName: 'Music', repo: _Repo())));
    await t.pump(const Duration(milliseconds: 600));
    await _tap(t, find.text('Next'));
    expect(find.text('What do you want?'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'In your own words'), 'Run a 5k');
    await t.pump();
    await _tap(t, find.text('Next'));
    expect(find.textContaining('what would "done" look like'), findsOneWidget);
    await _tap(t, find.byTooltip('Back'));
    expect(find.text('What do you want?'), findsOneWidget);
  });

  testWidgets('a plan drafted without AI says so', (t) async {
    await _size(t);
    await t.pumpWidget(MaterialApp(home: ConcreteGoalScreen(areaId: 'a1', areaName: 'Music', repo: _Repo()..byCode = true)));
    await t.pump(const Duration(milliseconds: 600));
    await _answer(t);
    expect(find.textContaining('without AI'), findsOneWidget);
  });

  testWidgets('no connection: says so and keeps the answers to try again', (t) async {
    await _size(t);
    final repo = _Repo()..fail = true;
    await t.pumpWidget(MaterialApp(home: ConcreteGoalScreen(areaId: 'a1', areaName: 'Music', repo: repo)));
    await t.pump(const Duration(milliseconds: 600));
    await _answer(t);
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Draft my plan'), findsOneWidget);
    repo.fail = false;
    await _tap(t, find.text('Draft my plan'));
    expect(find.text('Pick three songs you like'), findsOneWidget);
  });

  testWidgets('from the area page: start step one, finish it, and it counts', (t) async {
    await _size(t);
    final repo = _Repo();
    final area = (await loadAreasOverview(repo)).areas.first;
    await t.pumpWidget(MaterialApp(home: AreaPage(area: area, colorIndex: 0, canSetTime: true, repo: repo)));
    await t.pump(const Duration(seconds: 2));

    await _tap(t, find.text('Make a goal concrete'));
    await _answer(t);
    await _tap(t, find.text('Start step one · 15 min'));
    expect(find.text('MUSIC · 15 MIN'), findsOneWidget);
    expect(find.text('Pick three songs you like'), findsOneWidget);

    await _tap(t, find.text('Done'));
    await t.pump(const Duration(seconds: 2));
    expect(repo.calls, contains('respond:TASK:t1:DONE'));
    expect(find.text('1 min given'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the draft fits a small phone at large text', (t) async {
    await _size(t, size: const Size(320, 640), textScale: 1.5);
    await t.pumpWidget(MaterialApp(home: ConcreteGoalScreen(areaId: 'a1', areaName: 'Music', repo: _Repo())));
    await t.pump(const Duration(milliseconds: 600));
    await _answer(t);
    await t.drag(find.byType(ListView), const Offset(0, -1200));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Change my answers'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
