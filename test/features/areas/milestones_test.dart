import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/goal.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';

// One area, one goal. With [split] false the goal has no milestones yet.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool split = true;
  bool ready = false;
  int reached = 1; // how many are reached
  bool offline = false;
  final titles = ['Run 2 km', 'Run 5 km without stopping', 'Run a 10 km race'];

  Map<String, dynamic> _goal() => {
        'id': 'g1',
        'title': 'Get fit',
        'milestones': split
            ? [
                for (var i = 0; i < titles.length; i++)
                  {
                    'id': 'm$i',
                    'title': titles[i],
                    'state': i < reached ? 'REACHED' : (i == reached ? 'CURRENT' : 'NEXT'),
                    'stepsDone': i == reached ? (ready ? 2 : 1) : 0,
                    'stepsTotal': i == reached ? 2 : 0,
                  },
              ]
            : null,
        'progress': split
            ? {
                'index': reached + 1,
                'total': 3,
                'reached': reached,
                'ready': ready,
                'currentId': 'm$reached',
                'line': 'Milestone ${reached + 1} of 3: ${titles[reached]} · ${ready ? 2 : 1} of 2 steps done',
              }
            : null,
      };

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': 'Health',
            'mode': 'PUSH',
            'value': 0.3,
            'status': '1h of 3h this week',
            'goals': [_goal()],
            'progressLine': split ? _goal()['progress']['line'] : null,
            'nextSteps': [
              {'id': 's1', 'title': 'Run 3 km easy', 'minutes': 25},
            ],
            'routines': [],
          },
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  @override
  Future<({List<String> milestones, bool byCode})> proposeMilestones(String goalId) async {
    if (offline) throw const ApiException('No connection. Try again in a moment.');
    return (milestones: ['First steps done', 'Halfway to: get fit', 'Get fit'], byCode: true);
  }

  @override
  Future<String?> setMilestones(String goalId, List<String> milestones) async {
    calls.add('set:$goalId:${milestones.join('|')}');
    split = true;
    reached = 0;
    return 'act-split';
  }

  @override
  Future<({String message, String? next, String? firstStep, String? activityId})> reachMilestone(String id) async {
    calls.add('reach:$id');
    reached++;
    ready = false;
    return (message: 'Reached.', next: titles[reached], firstStep: 'Write down the first three things to do', activityId: 'act-reach');
  }

  @override
  Future<({String message, String? activityId})> letGoMilestone(String id) async {
    calls.add('letgo:$id');
    return (message: 'Run a 10 km race: let go.', activityId: 'act-letgo');
  }

  @override
  Future<Goal> updateGoal(String id, {String? title, String? description, String? areaId, String? priority, String? status, DateTime? deadline}) async {
    calls.add('goal:$id:title=$title');
    return Goal.fromJson({'id': id, 'title': title ?? ''});
  }

  @override
  Future<({String message, String? activityId})> addStep(String areaId, String title,
      {int? minutes, String? energy, String? smaller, Map<String, dynamic>? when, String? goalId}) async {
    calls.add('step:$title:goal=$goalId');
    return (message: '$title added.', activityId: 'act-step');
  }

  @override
  Future<void> undo(String activityId) async {
    calls.add('undo:$activityId');
    if (activityId == 'act-reach') {
      reached--;
      ready = true;
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_Repo> _open(WidgetTester t, {_Repo? repo, Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final r = repo ?? _Repo();
  final area = (await loadAreasOverview(r)).areas.first;
  await t.pumpWidget(MaterialApp(home: AreaPage(area: area, colorIndex: 0, canSetTime: true, repo: r)));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
  return r;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 1200));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('the overview reads milestones and the line, and an older server reads as none', () {
    final a = AreaStanding.fromJson({
      'id': 'a',
      'name': 'Health',
      'mode': 'PUSH',
      'value': 0,
      'status': '',
      'progressLine': 'Milestone 2 of 3: Run 5 km · 1 of 2 steps done',
      'goals': [
        {
          'id': 'g',
          'title': 'Get fit',
          'milestones': [
            {'id': 'm0', 'title': 'Run 2 km', 'state': 'REACHED'},
            {'id': 'm1', 'title': 'Run 5 km', 'state': 'CURRENT', 'stepsDone': 1, 'stepsTotal': 2},
          ],
          'progress': {'line': 'x', 'ready': true},
        },
      ],
    });
    expect(a.progressLine, startsWith('Milestone 2 of 3'));
    expect(a.goalDetails.single.current!.title, 'Run 5 km');
    expect(a.goalDetails.single.reached, 1);
    expect(a.goalDetails.single.ready, isTrue);
    final old = AreaStanding.fromJson({'id': 'a', 'name': 'x', 'value': 0, 'status': '', 'goals': [{'id': 'g', 'title': 'Get fit'}]});
    expect(old.goalDetails.single.milestones, isEmpty);
    expect(old.progressLine, isNull);
  });

  testWidgets('the area shows its milestone line and each milestone with its state', (t) async {
    await _open(t);
    expect(find.text('Milestone 2 of 3: Run 5 km without stopping · 1 of 2 steps done'), findsWidgets);
    expect(find.text('Run 2 km'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Run 2 km, reached'), findsOneWidget);
    expect(find.bySemanticsLabel('Run a 10 km race, still to come'), findsOneWidget);
    expect(find.byTooltip('Edit milestone: Run 5 km without stopping'), findsOneWidget);
    expect(find.text('Yes, reached'), findsNothing);
  });

  testWidgets('a goal without milestones can be split: draft, edit, save, with Undo', (t) async {
    final repo = _Repo()..split = false;
    await _open(t, repo: repo);
    await _tap(t, find.text('Split into milestones'));
    expect(find.text('Ally drafted these simply, without AI. Change them to fit.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('milestone-0')), 'Walk 30 minutes a day');
    await t.pump();
    await _tap(t, find.byTooltip('Remove milestone 2'));
    await _tap(t, find.text('Save milestones'));
    expect(repo.calls.single, 'set:g1:Walk 30 minutes a day|Get fit');
    expect(find.text('Split into milestones. Steps show for the first one.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-split');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('splitting offline says so and offers Try again', (t) async {
    final repo = _Repo()
      ..split = false
      ..offline = true;
    await _open(t, repo: repo);
    await _tap(t, find.text('Split into milestones'));
    expect(find.text('No connection. Try again in a moment.'), findsOneWidget);
    repo.offline = false;
    await _tap(t, find.text('Try again'));
    expect(find.text('Save milestones'), findsOneWidget);
  });

  testWidgets('when every step is done, "Reached it?" leads to the done moment, and Undo puts it back', (t) async {
    final repo = _Repo()..ready = true;
    await _open(t, repo: repo);
    expect(find.text('Every step of "Run 5 km without stopping" is done. Reached it?'), findsOneWidget);
    await _tap(t, find.text('Yes, reached'));
    expect(repo.calls.single, 'reach:m1');
    expect(find.text('MILESTONE REACHED · 2 OF 3'), findsOneWidget);
    expect(find.text('Next: Run a 10 km race'), findsOneWidget);
    await _tap(t, find.text('Undo').last);
    expect(repo.calls.last, 'undo:act-reach');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a new step goes under the current milestone', (t) async {
    final repo = await _open(t);
    await _tap(t, find.text('Add a step'));
    await t.enterText(find.byType(TextField).first, 'Run 4 km');
    await t.pump();
    await _tap(t, find.text('Add step'));
    expect(repo.calls.single, 'step:Run 4 km:goal=m1');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a milestone can be renamed or let go from its edit button', (t) async {
    final repo = await _open(t);
    await _tap(t, find.byTooltip('Edit milestone: Run a 10 km race'));
    expect(find.text('Mark it reached'), findsNothing);
    await _tap(t, find.text('Let this milestone go'));
    expect(repo.calls.single, 'letgo:m2');
    await t.pump(const Duration(seconds: 5));
    await _tap(t, find.byTooltip('Edit milestone: Run 2 km'));
    expect(find.text('Reached. It stays reached.'), findsOneWidget);
    expect(find.text('Let this milestone go'), findsNothing);
  });

  testWidgets('fits a small phone with large text', (t) async {
    await _open(t, repo: _Repo()..ready = true, size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Yes, reached'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
