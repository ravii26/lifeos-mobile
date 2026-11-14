import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/area.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_home_screen.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';

Map<String, dynamic> _area(String id, String name, String mode, double value, String status, {int? weekly, int planned = 0}) => {
      'id': id,
      'name': name,
      'mode': mode,
      'weeklyMinutes': weekly,
      'plannedMinutes': planned,
      'minutes': 0,
      'value': value,
      'status': status,
      'goals': [
        {'id': 'g$id', 'title': 'A goal in $name'},
      ],
      'nextSteps': [
        {'id': 's$id', 'title': 'First step in $name', 'minutes': 20, 'dueKey': null},
      ],
      'routines': [
        {'id': 'r$id', 'title': 'A routine', 'doneThisWeek': 2},
      ],
    };

class _Repo implements LifeRepository {
  /// True = a server from before the overview existed.
  bool oldServer = false;
  bool over = false;
  final List<String> saved = [];

  @override
  Future<Map<String, dynamic>> areasOverview() async {
    if (oldServer) throw const ApiException('Area not found', statusCode: 404);
    return {
      'weekStart': '2026-11-09',
      'areas': [
        _area('1', 'Work', 'PUSH', 0.6, '3h of 5h this week', weekly: 300, planned: 300),
        _area('2', 'Health', 'MAINTAIN', 1, 'Active 2 days this week'),
        _area('3', 'Learning', 'EXPLORE', 0, 'Last touched 9 days ago'),
        _area('4', 'Side project', 'REST', 0, 'Resting'),
      ],
      'capacity': {
        'neededMinutes': 720,
        'freeMinutes': over ? 600 : 900,
        'over': over,
        'note': over ? 'This week asks for 12h and you have about 10h free. Moving one area to Maintain would make it fit.' : null,
      },
    };
  }

  @override
  Future<List<Area>> areas() async => [
        const Area(id: '1', name: 'Work', type: 'PRIMARY', tier: 'MAIN', colorHex: '#fff', icon: 'x', order: 0, isActive: true, score: 0, tasksDone: 2, tasksTotal: 8, streak: 0, focusMins: 0),
        const Area(id: '2', name: 'Hidden', type: 'PRIMARY', tier: 'MAIN', colorHex: '#fff', icon: 'x', order: 1, isActive: false, score: 0, tasksDone: 0, tasksTotal: 0, streak: 0, focusMins: 0),
        const Area(id: '3', name: 'Later thing', type: 'PRIMARY', tier: 'LATER', colorHex: '#fff', icon: 'x', order: 2, isActive: true, score: 0, tasksDone: 1, tasksTotal: 2, streak: 0, focusMins: 0),
      ];

  @override
  Future<Area> updateArea(String id,
      {String? name, String? type, String? color, String? icon, bool? isActive, String? tier, int? weeklyMinutes, bool clearWeeklyMinutes = false}) async {
    saved.add('$id tier=$tier weekly=$weeklyMinutes clear=$clearWeeklyMinutes');
    return (await areas()).first;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _size(WidgetTester t, {Size size = const Size(360, 760), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('every mode has a tier and maps back', () {
    for (final m in AreaMode.values) {
      expect(AreaMode.fromTier(m.tier), m);
      expect(AreaMode.fromName(m.name.toUpperCase()), m);
    }
    expect(AreaMode.fromTier('MAIN'), AreaMode.push);
    expect(AreaMode.fromTier('unknown'), AreaMode.maintain);
  });

  test('a server without the overview still gives a picture, from the older list', () async {
    final o = await loadAreasOverview(_Repo()..oldServer = true);
    expect(o.full, isFalse);
    expect(o.areas.map((a) => a.name), ['Work', 'Later thing']); // hidden areas stay hidden
    expect(o.areas[0].mode, AreaMode.push);
    expect(o.areas[0].status, '2 of 8 to-dos done');
    expect(o.areas[0].value, 0.25);
    expect(o.areas[1].mode, AreaMode.rest);
    expect(o.areas[1].value, 0);
    expect(o.areas[1].status, 'Resting');
  });

  test('other failures are not hidden as "old server"', () async {
    final repo = _FailingRepo();
    expect(() => loadAreasOverview(repo), throwsA(isA<ApiException>()));
  });

  testWidgets('shows every area with its mode and where it stands', (t) async {
    await _size(t);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AreasHomeScreen(repo: _Repo()))));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Your areas'), findsOneWidget);
    for (final s in ['Work', 'Health', 'Learning', 'Side project', 'Push', 'Maintain', 'Explore', 'Rest']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('3h of 5h this week'), findsOneWidget);
    expect(find.text('Last touched 9 days ago'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // areas not resting, in the wheel
    expect(find.textContaining('This week asks for 12h. You have about 15h free.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('too much for the week is a suggestion, not a block', (t) async {
    await _size(t);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AreasHomeScreen(repo: _Repo()..over = true))));
    await t.pump(const Duration(seconds: 2));
    expect(find.textContaining('Moving one area to Maintain'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('changing the mode saves it as a tier and can be undone', (t) async {
    await _size(t);
    final repo = _Repo();
    final o = await loadAreasOverview(repo);
    await t.pumpWidget(MaterialApp(home: AreaPage(area: o.areas[0], colorIndex: 0, canSetTime: true, repo: repo)));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('Getting most of your effort right now.'), findsOneWidget);
    await t.tap(find.text('Explore'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.saved.last, '1 tier=SECONDARY weekly=null clear=false');
    expect(find.text('Trying it out, with no pressure to commit.'), findsOneWidget);
    expect(find.text('Work is now Explore.'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.saved.last, '1 tier=MAIN weekly=null clear=false');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('weekly time moves in half hours and can be cleared', (t) async {
    await _size(t);
    final repo = _Repo();
    final o = await loadAreasOverview(repo);
    await t.pumpWidget(MaterialApp(home: AreaPage(area: o.areas[0], colorIndex: 0, canSetTime: true, repo: repo)));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('5h'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('More time'));
    await t.pump(const Duration(milliseconds: 500));
    expect(repo.saved.last, '1 tier=null weekly=330 clear=false');
    expect(find.text('5h 30'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a resting area asks for nothing, and an old server hides weekly time', (t) async {
    await _size(t);
    final repo = _Repo();
    final o = await loadAreasOverview(repo);
    await t.pumpWidget(MaterialApp(home: AreaPage(area: o.areas[3], colorIndex: 3, canSetTime: true, repo: repo)));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('TIME EACH WEEK'), findsNothing);
    expect(find.text('Paused on purpose. Nothing is asked here.'), findsOneWidget);

    await t.pumpWidget(MaterialApp(home: AreaPage(key: const ValueKey('b'), area: o.areas[0], colorIndex: 0, canSetTime: false, repo: repo)));
    await t.pump(const Duration(seconds: 2));
    expect(find.text('TIME EACH WEEK'), findsNothing);
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _size(t, size: const Size(320, 640), textScale: 1.5);
    final repo = _Repo()..over = true;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AreasHomeScreen(repo: repo))));
    await t.pump(const Duration(seconds: 2));
    for (var i = 0; i < 5; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);

    final o = await loadAreasOverview(repo);
    await t.pumpWidget(MaterialApp(home: AreaPage(area: o.areas[0], colorIndex: 0, canSetTime: true, repo: repo)));
    await t.pump(const Duration(seconds: 2));
    for (var i = 0; i < 5; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(AllySegmented<AreaMode>), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

class _FailingRepo implements LifeRepository {
  @override
  Future<Map<String, dynamic>> areasOverview() async => throw const ApiException('No connection');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
