import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/design/trend_line.dart';
import 'package:lifeos_mobile/features/areas/area_page.dart';
import 'package:lifeos_mobile/features/areas/areas_overview.dart';
import 'package:lifeos_mobile/features/areas/number_sheets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One area with one tracked number. Generic sample data.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool withNumber = true;
  bool oldServer = false;
  String areaMode = 'PUSH';

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [
          {
            'id': 'a1',
            'name': 'Health',
            'mode': areaMode,
            'value': 0.5,
            'status': 'Active 2 days this week',
            'goals': [],
            'nextSteps': [],
            'routines': [],
            'numbers': withNumber
                ? [
                    {
                      'projectId': 'p1',
                      'name': 'Weight',
                      'unit': 'kg',
                      'start': 82,
                      'latest': 79.5,
                      'target': 75,
                      'percent': 36,
                      'weeklyChange': -0.4,
                      'trend': 'TOWARD',
                      'points': [
                        {'value': 82, 'at': '2026-10-01T00:00:00Z'},
                        {'value': 80.8, 'at': '2026-10-15T00:00:00Z'},
                        {'value': 79.5, 'at': '2026-11-01T00:00:00Z'},
                      ],
                    },
                  ]
                : [],
          },
        ],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
      };

  @override
  Future<({String message, String? activityId})> trackNumber(String areaId,
      {required String name, String unit = '', required double start, required double target}) async {
    if (oldServer) throw const ApiException('Not found', statusCode: 404);
    calls.add('track:$areaId:$name:$unit:$start:$target');
    return (message: 'Tracking $name. Add a reading whenever you check it.', activityId: 'act-track');
  }

  @override
  Future<({String message, String? activityId})> logReading(String projectId, double value) async {
    calls.add('read:$projectId:$value');
    return (message: 'Weight $value kg', activityId: 'act-read');
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('words', () {
    test('numbers read plainly, decimals with a comma or a point', () {
      expect(TrackedNumber.show(72.0), '72');
      expect(TrackedNumber.show(72.44), '72.4');
      expect(parseNumber('72,4'), 72.4);
      expect(parseNumber(' 1500 '), 1500);
      expect(parseNumber('abc'), isNull);
    });

    test('the trend is said without blame', () {
      const n = TrackedNumber(projectId: 'p', name: 'Savings', unit: '₹', start: 0, latest: 4000, target: 10000);
      expect(n.line, '4000 ₹ now · goal 10000 ₹');
      expect(n.trendWords, 'A few more readings and the trend shows');
      expect(const TrackedNumber(projectId: 'p', name: 'x', start: 0, latest: 1, target: 2, trend: 'AWAY').trendWords,
          'Drifting the other way lately. That happens.');
      expect(const TrackedNumber(projectId: 'p', name: 'x', unit: 'kg', start: 82, latest: 80, target: 75, trend: 'TOWARD', weeklyChange: -0.4).trendWords,
          'Moving the right way, about 0.4 kg a week');
    });
  });

  testWidgets('a tracked number shows where it is, the line and the trend', (t) async {
    await _open(t, _Repo());
    await t.ensureVisible(find.text('Weight'));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('TRACKED NUMBER'), findsOneWidget);
    expect(find.text('79.5 kg now · goal 75 kg'), findsOneWidget);
    expect(find.text('36%'), findsOneWidget);
    expect(find.byType(TrendLine), findsOneWidget);
    expect(find.text('Moving the right way, about 0.4 kg a week'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a reading is saved with Undo', (t) async {
    final repo = await _open(t, _Repo());
    await _tap(t, find.text('Add a reading'));
    expect(find.text('Last: 79.5 kg'), findsOneWidget);
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Save reading')).onPressed, isNull);
    await t.enterText(find.byType(TextField).last, '79,1');
    await t.pump();
    await _tap(t, find.text('Save reading'));
    expect(repo.calls.single, 'read:p1:79.1');
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-read');
  });

  testWidgets('track a number: name and two different values are needed', (t) async {
    final repo = await _open(t, _Repo()..withNumber = false);
    await _tap(t, find.text('Track a number'));
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Savings');
    await t.enterText(fields.at(1), '₹');
    await t.enterText(fields.at(2), '5000');
    await t.enterText(fields.at(3), '5000');
    await t.pump();
    expect(find.textContaining('already is'), findsOneWidget);
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Start tracking')).onPressed, isNull);
    await t.enterText(fields.at(3), '50000');
    await t.pump();
    await _tap(t, find.text('Start tracking'));
    expect(repo.calls.single, 'track:a1:Savings:₹:5000.0:50000.0');
    expect(find.textContaining('Tracking Savings'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('on a server without numbers, tracking says what is needed', (t) async {
    await _open(t, _Repo()
      ..withNumber = false
      ..oldServer = true);
    await _tap(t, find.text('Track a number'));
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'Pages read');
    await t.enterText(fields.at(2), '0');
    await t.enterText(fields.at(3), '300');
    await t.pump();
    await _tap(t, find.text('Start tracking'));
    expect(find.textContaining('needs the latest server'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a resting area with no number shows no number section', (t) async {
    await _open(t, _Repo()
      ..withNumber = false
      ..areaMode = 'REST');
    expect(find.text('TRACKED NUMBER'), findsNothing);
    expect(find.text('Track a number'), findsNothing);
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _open(t, _Repo(), size: const Size(320, 640), textScale: 1.5);
    await t.drag(find.byType(ListView), const Offset(0, -1500));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await _tap(t, find.text('Add a reading'));
    expect(t.takeException(), isNull);
  });
}
