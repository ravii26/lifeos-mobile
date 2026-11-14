import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';

// One area with one step that has a length, energy and a smaller version.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool oldServer = false;

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': 'Writing',
            'mode': 'PUSH',
            'value': 0.3,
            'status': '1h of 3h this week',
            'goals': [],
            'nextSteps': [
              {'id': 's1', 'title': 'Draft the intro', 'minutes': 25, 'energy': 'HIGH', 'smaller': 'Write one line'},
            ],
            'routines': [],
          },
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  ({String message, String? activityId}) _ok(String what, String message) {
    calls.add(what);
    return (message: message, activityId: 'act-$what');
  }

  @override
  Future<({String message, String? activityId})> addStep(String areaId, String title,
      {int? minutes, String? energy, String? smaller}) async {
    if (oldServer) throw const ApiException('Not found', statusCode: 404);
    return _ok('add:$areaId:$title:$minutes:$energy:$smaller', '$title added.');
  }

  @override
  Future<({String message, String? activityId})> editStep(String id,
          {String? title, int? minutes, bool clearMinutes = false, String? energy, String? smaller}) async =>
      _ok('edit:$id:$title:$minutes:$clearMinutes:$energy:$smaller', 'Saved.');

  @override
  Future<({String message, String? activityId})> moveStep(String id, String when) async =>
      _ok('move:$id:$when', 'Draft the intro moved to tomorrow.');

  @override
  Future<({String message, String? activityId})> letGoStep(String id) async => _ok('letgo:$id', 'Let go of Draft the intro.');

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

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

  testWidgets('a step shows its energy and smaller version, and opens prefilled', (t) async {
    await _open(t);
    expect(find.text('Demanding · Smaller: Write one line'), findsOneWidget);
    await _tap(t, find.text('Draft the intro'));
    expect(find.text('Edit step'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Draft the intro'), findsOneWidget);
    expect(t.widget<AllyChip>(find.widgetWithText(AllyChip, '25 min')).selected, isTrue);
    expect(find.text('Kept for good-energy times. On a low day only its smaller version is offered.'), findsOneWidget);
  });

  testWidgets('changing the length saves only through Save, then offers Undo', (t) async {
    final repo = await _open(t);
    await _tap(t, find.text('Draft the intro'));
    await _tap(t, find.widgetWithText(AllyChip, '15 min'));
    expect(repo.calls, isEmpty);
    await _tap(t, find.text('Save'));
    expect(repo.calls.single, 'edit:s1:Draft the intro:15:false:HIGH:Write one line');
    expect(find.text('Saved.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-edit:s1:Draft the intro:15:false:HIGH:Write one line');
  });

  testWidgets('tapping the chosen length again clears it', (t) async {
    final repo = await _open(t);
    await _tap(t, find.text('Draft the intro'));
    await _tap(t, find.widgetWithText(AllyChip, '25 min'));
    await _tap(t, find.text('Save'));
    expect(repo.calls.single, 'edit:s1:Draft the intro:null:true:HIGH:Write one line');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('move and let go each take one tap', (t) async {
    final repo = await _open(t);
    await _tap(t, find.text('Draft the intro'));
    await _tap(t, find.text('Tomorrow'));
    expect(repo.calls.last, 'move:s1:TOMORROW');
    expect(find.text('Draft the intro moved to tomorrow.'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));

    await _tap(t, find.text('Draft the intro'));
    await _tap(t, find.text('Let this go'));
    expect(repo.calls.last, 'letgo:s1');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('adding a step needs a name, then sends it with its settings', (t) async {
    final repo = await _open(t);
    await _tap(t, find.text('Add a step'));
    expect(find.text('New step'), findsOneWidget);
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Add step')).onPressed, isNull);
    await t.enterText(find.widgetWithText(TextField, 'What to do'), 'Outline chapter two');
    await t.pump();
    await _tap(t, find.widgetWithText(AllyChip, '30 min'));
    await _tap(t, find.text('Light'));
    await _tap(t, find.text('Add step'));
    expect(repo.calls.single, 'add:a1:Outline chapter two:30:LOW:');
    expect(find.text('Outline chapter two added.'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('on a server without steps, adding says what is needed', (t) async {
    await _open(t, repo: _Repo()..oldServer = true);
    await _tap(t, find.text('Add a step'));
    await t.enterText(find.widgetWithText(TextField, 'What to do'), 'Anything');
    await t.pump();
    await _tap(t, find.text('Add step'));
    expect(find.textContaining('needs the latest server'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the sheet fits a small phone at large text', (t) async {
    await _open(t, size: const Size(320, 640), textScale: 1.5);
    await _tap(t, find.text('Draft the intro'));
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -800));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Let this go'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
