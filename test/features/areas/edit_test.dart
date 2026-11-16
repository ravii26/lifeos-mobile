import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/area.dart';
import 'package:lifeos_mobile/data/models/goal.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';

// One area with a goal and a step; renames are kept so a reload shows them.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  String areaName = 'Writing';
  String goalTitle = 'Finish the first draft';
  bool goalActive = true;
  bool offline = false;

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': areaName,
            'mode': 'PUSH',
            'value': 0.3,
            'status': '1h of 3h this week',
            'goals': [
              if (goalActive) {'id': 'g1', 'title': goalTitle},
            ],
            'nextSteps': [
              {'id': 's1', 'title': 'Draft the intro', 'minutes': 25},
            ],
            'routines': [],
          },
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  @override
  Future<Area> updateArea(String id,
      {String? name,
      String? type,
      String? color,
      String? icon,
      bool? isActive,
      String? tier,
      int? weeklyMinutes,
      bool clearWeeklyMinutes = false,
      String? nextTier,
      DateTime? nextTierOn,
      bool clearPlanned = false}) async {
    if (offline) throw const ApiException('No connection. Try again in a moment.');
    calls.add('area:$id:name=$name:active=$isActive');
    if (name != null) areaName = name;
    return Area.fromJson({'id': id, 'name': areaName});
  }

  @override
  Future<Goal> updateGoal(String id, {String? title, String? description, String? areaId, String? priority, String? status, DateTime? deadline}) async {
    calls.add('goal:$id:title=$title:status=$status');
    if (title != null) goalTitle = title;
    if (status != null) goalActive = status == 'ACTIVE';
    return Goal.fromJson({'id': id, 'title': goalTitle});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

AreaLetGo? _popped;

Future<_Repo> _open(WidgetTester t, {_Repo? repo, Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  _popped = null;
  final r = repo ?? _Repo();
  final area = (await loadAreasOverview(r)).areas.first;
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => _popped = await Navigator.of(context)
              .push(MaterialPageRoute<AreaLetGo>(builder: (_) => AreaPage(area: area, colorIndex: 0, canSetTime: true, repo: r))),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
  return r;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('the area, its goal and its step each show an edit button', (t) async {
    await _open(t);
    expect(find.byTooltip('Edit area'), findsOneWidget);
    expect(find.byTooltip('Edit goal: Finish the first draft'), findsOneWidget);
    expect(find.byTooltip('Edit step: Draft the intro'), findsOneWidget);
    await _tap(t, find.byTooltip('Edit step: Draft the intro'));
    expect(find.text('Edit step'), findsOneWidget);
  });

  testWidgets('renaming an area saves, shows the new name, and Undo puts the old one back', (t) async {
    final repo = await _open(t);
    await _tap(t, find.byTooltip('Edit area'));
    expect(find.text('Edit area'), findsOneWidget);
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Save')).onPressed, isNull);
    await t.enterText(find.widgetWithText(TextField, 'Writing'), 'Novel');
    await t.pump();
    await _tap(t, find.text('Save'));
    expect(repo.calls.single, 'area:a1:name=Novel:active=null');
    expect(find.text('Novel'), findsOneWidget);
    expect(find.text('Renamed to Novel.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'area:a1:name=Writing:active=null');
    expect(find.text('Writing'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('letting an area go closes the page and hands the list what it needs for Undo', (t) async {
    final repo = await _open(t);
    await _tap(t, find.byTooltip('Edit area'));
    await _tap(t, find.text('Let this area go'));
    expect(repo.calls.single, 'area:a1:name=null:active=false');
    expect(_popped?.id, 'a1');
    expect(_popped?.name, 'Writing');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a goal can be renamed and let go, each with Undo', (t) async {
    final repo = await _open(t);
    await _tap(t, find.byTooltip('Edit goal: Finish the first draft'));
    await t.enterText(find.widgetWithText(TextField, 'Finish the first draft'), 'Finish chapter one');
    await t.pump();
    await _tap(t, find.text('Save'));
    expect(repo.calls.single, 'goal:g1:title=Finish chapter one:status=null');
    expect(find.text('Finish chapter one'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));

    await _tap(t, find.byTooltip('Edit goal: Finish chapter one'));
    await _tap(t, find.text('Let this goal go'));
    expect(repo.calls.last, 'goal:g1:title=null:status=ABANDONED');
    expect(find.text('No goal here yet.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'goal:g1:title=null:status=ACTIVE');
    expect(find.text('Finish chapter one'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('with no connection a rename says so and keeps the old name', (t) async {
    final repo = _Repo()..offline = true;
    await _open(t, repo: repo);
    await _tap(t, find.byTooltip('Edit area'));
    await t.enterText(find.widgetWithText(TextField, 'Writing'), 'Novel');
    await t.pump();
    await _tap(t, find.text('Save'));
    expect(find.text('No connection. Try again in a moment.'), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the edit sheet fits a small phone at large text', (t) async {
    await _open(t, size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
    await _tap(t, find.byTooltip('Edit area'));
    expect(find.text('Let this area go'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
