import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/models/area.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One Push area with a step that has been reworked, and optionally a planned change.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  Map<String, dynamic>? planned;
  bool reworked = false;

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': 'Study',
            'mode': 'PUSH',
            'value': 0.4,
            'status': '2h of 5h this week',
            'goals': [],
            'nextSteps': [
              {'id': 's1', 'title': 'Outline chapter one', 'minutes': 40},
            ],
            'routines': [],
            'planned': planned,
            'reworking': reworked,
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
    final day = nextTierOn == null ? null : '${nextTierOn.year}-${nextTierOn.month}-${nextTierOn.day}';
    calls.add(clearPlanned ? 'clear' : 'plan:$nextTier:$day');
    planned = clearPlanned || nextTier == null ? null : {'mode': nextTier == 'LATER' ? 'REST' : 'MAINTAIN', 'on': '2026-12-01'};
    return const Area(id: 'a1', name: 'Study', type: 'PRIMARY', colorHex: '#fff', icon: 'x', order: 0, isActive: true, score: 0, tasksDone: 0, tasksTotal: 0, streak: 0, focusMins: 0);
  }

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    calls.add('respond:$sourceType:$sourceId:$action');
    return 'act-done';
  }

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('plan a change: the current mode is not offered, and a day is needed', (t) async {
    final repo = await _open(t, _Repo());
    await _tap(t, find.text('Plan a change for later'));
    expect(find.text('Plan a change'), findsOneWidget);
    // Push is the current mode, so the choices are the other three.
    final seg = find.byType(AllySegmented<AreaMode>).last;
    expect(find.descendant(of: seg, matching: find.text('Push')), findsNothing);
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Choose a day')).onPressed, isNull);

    await _tap(t, find.descendant(of: seg, matching: find.text('Rest')));
    await _tap(t, find.text('In 2 weeks'));
    final d = DateTime.now().add(const Duration(days: 14));
    await _tap(t, find.textContaining('Rest from '));
    expect(repo.calls.single, 'plan:LATER:${d.year}-${d.month}-${d.day}');
    expect(find.text('Becomes Rest on 1 Dec'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a planned change can be cancelled, and the cancel undone', (t) async {
    final repo = await _open(t, _Repo()..planned = {'mode': 'MAINTAIN', 'on': '2026-12-01'});
    expect(find.text('Becomes Maintain on 1 Dec'), findsOneWidget);
    await _tap(t, find.text('Cancel'));
    expect(repo.calls.last, 'clear');
    expect(find.text('Plan a change for later'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'plan:MAINTAIN:2026-12-1');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('reworking without doing: one gentle line, hidden for a week by Not now', (t) async {
    await _open(t, _Repo()..reworked = true);
    expect(find.textContaining('changed a few times'), findsOneWidget);
    expect(find.text('15 minutes is enough to learn what to change.'), findsOneWidget);
    await _tap(t, find.text('Not now'));
    expect(find.textContaining('changed a few times'), findsNothing);

    // Opened again later: still hidden this week.
    await _open(t, _Repo()..reworked = true);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('changed a few times'), findsNothing);
  });

  testWidgets('Try it: the first step, at most 15 minutes, and done counts', (t) async {
    final repo = await _open(t, _Repo()..reworked = true);
    await _tap(t, find.text('Try it'));
    expect(find.text('STUDY · 15 MIN'), findsOneWidget);
    await _tap(t, find.text('Done'));
    expect(repo.calls, contains('respond:TASK:s1:DONE'));
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the sheet fits a small phone at large text', (t) async {
    await _open(t, _Repo(), size: const Size(320, 640), textScale: 1.5);
    await _tap(t, find.text('Plan a change for later'));
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });
}
