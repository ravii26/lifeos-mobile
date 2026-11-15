import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';

// One Explore area. [round] is the state of its tastes: null, going, or done.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  Map<String, dynamic>? round;
  String areaMode = 'EXPLORE';
  bool offline = false;

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': 'Pottery',
            'mode': areaMode,
            'value': 0,
            'status': 'Not started yet',
            'goals': [],
            'nextSteps': [],
            'routines': [],
            'tastes': round,
          },
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  @override
  Future<({List<({String title, int minutes})> tastes, bool byCode})> suggestTastes(String areaId, {String? note}) async {
    calls.add('suggest:$areaId');
    if (offline) throw const ApiException('No connection');
    return (
      tastes: [
        (title: 'Watch one wheel-throwing video', minutes: 20),
        (title: 'Shape a pinch pot from air-dry clay', minutes: 45),
        (title: 'Visit an open studio session', minutes: 90),
      ],
      byCode: false,
    );
  }

  @override
  Future<({String message, String? activityId})> startTastes(String areaId, List<({String title, int minutes})> tastes) async {
    calls.add('start:${tastes.map((t) => '${t.title}/${t.minutes}').join('|')}');
    round = {'done': 0, 'total': 3, 'decide': false};
    return (message: 'Three tastes of Pottery added. Each comes up in your free time.', activityId: 'act-start');
  }

  @override
  Future<({String message, String? activityId})> decideTastes(String areaId, String decision) async {
    calls.add('decide:$decision');
    round = null;
    if (decision == 'DROP') areaMode = 'REST';
    return (message: decision == 'DROP' ? 'Pottery is resting. Dropping it on purpose is a decision, not a failure.' : 'ok', activityId: 'act-$decision');
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_Repo> _open(WidgetTester t, _Repo repo, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final area = (await loadAreasOverview(repo)).areas.first;
  await t.pumpWidget(MaterialApp(home: AreaPage(area: area, colorIndex: 0, canSetTime: true, repo: repo)));
  await t.pump(const Duration(seconds: 2));
  return repo;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('an unsure area offers three tastes; editing one changes what starts', (t) async {
    final repo = await _open(t, _Repo());
    expect(find.text('NOT SURE YET?'), findsOneWidget);
    await _tap(t, find.text('Plan three tastes'));
    expect(repo.calls, contains('suggest:a1'));
    expect(find.text('Watch one wheel-throwing video'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Visit an open studio session'), 'Book one beginner class');
    await t.pump();
    await _tap(t, find.text('Start the tastes'));
    expect(repo.calls.last,
        'start:Watch one wheel-throwing video/20|Shape a pinch pot from air-dry clay/45|Book one beginner class/90');
    expect(find.text('TASTE 1 OF 3'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('offline: starts from simple tastes named after the area', (t) async {
    await _open(t, _Repo()..offline = true);
    await _tap(t, find.text('Plan three tastes'));
    expect(find.textContaining("Couldn't reach Ally"), findsOneWidget);
    expect(find.text('Try the simplest version of Pottery for half an hour'), findsOneWidget);
  });

  testWidgets('a taste can not be left empty', (t) async {
    await _open(t, _Repo());
    await _tap(t, find.text('Plan three tastes'));
    await t.enterText(find.widgetWithText(TextField, 'Watch one wheel-throwing video'), '  ');
    await t.pump();
    await _tap(t, find.text('Start the tastes'));
    expect(find.text('Three small tastes'), findsOneWidget); // still open
  });

  testWidgets('progress shows while tastes are going', (t) async {
    await _open(t, _Repo()..round = {'done': 1, 'total': 3, 'decide': false});
    expect(find.text('TASTE 2 OF 3'), findsOneWidget);
    expect(find.text('Plan three tastes'), findsNothing);
  });

  testWidgets('all done: drop it rests the area, with Undo', (t) async {
    final repo = await _open(t, _Repo()..round = {'done': 3, 'total': 3, 'decide': true});
    expect(find.text('What now for Pottery?'), findsOneWidget);
    await _tap(t, find.text('Drop it for now'));
    expect(repo.calls.last, 'decide:DROP');
    expect(find.textContaining('Dropping it on purpose is a decision'), findsOneWidget);
    expect(find.text('Paused on purpose. Nothing is asked here.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-DROP');
  });

  testWidgets('all done: keep going leads into making it concrete', (t) async {
    final repo = await _open(t, _Repo()..round = {'done': 3, 'total': 3, 'decide': true});
    await _tap(t, find.text('Keep going: make it concrete'));
    expect(repo.calls.last, 'decide:KEEP');
    expect(find.text('What do you want?'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('all done: another direction plans new tastes', (t) async {
    final repo = await _open(t, _Repo()..round = {'done': 3, 'total': 3, 'decide': true});
    await _tap(t, find.text('Try another direction'));
    expect(repo.calls, containsAllInOrder(['decide:CHANGE', 'suggest:a1']));
    expect(find.text('Three small tastes'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the decision fits a small phone at large text', (t) async {
    await _open(t, _Repo()..round = {'done': 3, 'total': 3, 'decide': true}, size: const Size(320, 640), textScale: 1.5);
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });
}
