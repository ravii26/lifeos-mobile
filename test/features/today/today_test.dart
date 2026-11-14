import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/rings.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/today/day_shape.dart';
import 'package:lifeos_mobile/features/today/today_screen.dart';

// A weekday for someone with an office job: nothing here is specific to one person.
const _blocks = [
  DayBlockInfo('MORNING', 390, 570, 60), // 06:30–09:30, an hour free
  DayBlockInfo('OFFICE', 570, 1080, 0), // 09:30–18:00
  DayBlockInfo('EVENING', 1110, 1380, 120), // 18:30–23:00, two hours free
];

Map<String, dynamic> _scheduleDay(int weekday) => {
      'weekday': weekday,
      'custom': true,
      'blocks': [
        {'block': 'MORNING', 'start': '06:30', 'end': '09:30', 'freeMinutes': 60},
        {'block': 'OFFICE', 'start': '09:30', 'end': '18:00', 'freeMinutes': 0},
        {'block': 'EVENING', 'start': '18:30', 'end': '23:00', 'freeMinutes': 120},
      ],
    };

class _Repo implements LifeRepository {
  bool offline = false;
  final List<String> answered = [];
  int? askedMinutes;
  bool? askedSmallest;

  @override
  bool get showingSaved => false;

  @override
  Future<Map<String, dynamic>?> nowSaved({bool smallest = false}) async => null;

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async {
    if (offline) throw ApiException('No connection');
    askedMinutes = minutes;
    askedSmallest = smallest;
    return {
      'kind': 'PICK',
      'message': '',
      'options': [
        {'sourceType': 'TASK', 'sourceId': 't1', 'title': 'Draft the proposal outline', 'minutes': 25, 'smaller': false, 'minimum': 'Write three headings', 'why': 'Due Friday.'},
        {'sourceType': 'HABIT', 'sourceId': 'h1', 'title': 'Stretch', 'minutes': 10, 'smaller': false, 'minimum': '', 'why': 'Keeps the streak of care going.'},
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> daySchedule() async => [for (var d = 0; d < 7; d++) _scheduleDay(d)];

  @override
  Future<Map<String, dynamic>> plan() async => {
        'today': {
          'blocks': [
            {
              'block': 'EVENING',
              'items': [
                {'id': 't2', 'type': 'TASK', 'title': 'Call the bank', 'block': 'EVENING', 'minutes': 10, 'done': false, 'at': null},
                {'id': 'h2', 'type': 'HABIT', 'title': 'Read 10 pages', 'block': 'EVENING', 'minutes': 20, 'done': true, 'at': null},
              ],
            },
          ],
        },
      };

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    answered.add('$sourceType:$sourceId:$action');
    return 'act1';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_Repo> _open(WidgetTester t, {required DateTime at, Size size = const Size(360, 760), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final repo = _Repo();
  final cubit = NowCubit(repo);
  addTearDown(cubit.close);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: TodayScreen(firstName: 'Sam', repo: repo, clock: () => at),
      ),
    ),
  ));
  await cubit.load();
  await t.pump(const Duration(seconds: 2));
  return repo;
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('free time', () {
    test('inside a free part: what is left, capped by what that part allows', () {
      final w = freeWindow(_blocks, 19 * 60)!; // 19:00, evening runs to 23:00
      expect(w.now, isTrue);
      expect(w.minutes, 120);
      final late = freeWindow(_blocks, 22 * 60 + 15)!; // 45 min left
      expect(late.minutes, 45);
    });

    test('at work: the next free part is offered, not the one that has passed', () {
      final w = freeWindow(_blocks, 14 * 60)!;
      expect(w.now, isFalse);
      expect(w.start, 1110);
      expect(w.minutes, 120);
    });

    test('a sliver of time is not offered, and after the last part there is none', () {
      expect(freeWindow(_blocks, 22 * 60 + 55), isNull);
      expect(freeWindow(_blocks, 23 * 60 + 30), isNull);
    });

    test('a day with no free part has no free window', () {
      expect(freeWindow(const [DayBlockInfo('OFFICE', 540, 1080, 0)], 600), isNull);
    });
  });

  group('dial', () {
    test('sleep wraps midnight, work is fixed, own time is free, timed things sit on top', () {
      final items = [
        TodayItem(id: 'a', type: 'REMINDER', title: 'Dentist', block: 'EVENING', minutes: 30, at: 19 * 60),
        TodayItem(id: 'b', type: 'TASK', title: 'No time set', block: 'EVENING'),
        TodayItem(id: 'c', type: 'TASK', title: 'Already done', block: 'MORNING', at: 420, done: true),
      ];
      final parts = dialParts(_blocks, items, planned: const Color(0xFF888888));
      expect(parts.first.kind, DayPartKind.fixed);
      expect(parts.first.start, 1380); // 23:00
      expect(parts.first.end, 390); // 06:30
      expect(parts.first.minutes, 450);
      expect(parts.where((p) => p.kind == DayPartKind.free).length, 2);
      final planned = parts.where((p) => p.kind == DayPartKind.planned).toList();
      expect(planned.length, 1);
      expect(planned.single.start, 19 * 60);
      expect(parts.last.kind, DayPartKind.planned);
    });
  });

  test("today's list: set times first and in order", () {
    final items = todayItems({
      'today': {
        'blocks': [
          {
            'block': 'MORNING',
            'items': [
              {'id': '1', 'type': 'HABIT', 'title': 'Walk', 'block': 'MORNING', 'done': false},
            ],
          },
          {
            'block': 'EVENING',
            'items': [
              {'id': '2', 'type': 'REMINDER', 'title': 'Later', 'block': 'EVENING', 'at': DateTime(2026, 11, 14, 20).toIso8601String()},
              {'id': '3', 'type': 'REMINDER', 'title': 'Sooner', 'block': 'EVENING', 'at': DateTime(2026, 11, 14, 18, 45).toIso8601String()},
            ],
          },
        ],
      },
    });
    expect(items.map((i) => i.title), ['Sooner', 'Later', 'Walk']);
    expect(items.first.at, 18 * 60 + 45);
    expect(items[0].sourceType, 'TASK');
    expect(items[2].sourceType, 'HABIT');
  });

  test('offline fallback picks the first open thing that fits', () {
    final items = [
      TodayItem(id: 'a', type: 'TASK', title: 'Long', block: 'EVENING', minutes: 60),
      TodayItem(id: 'b', type: 'TASK', title: 'Done already', block: 'EVENING', minutes: 5, done: true),
      TodayItem(id: 'c', type: 'TASK', title: 'Short', block: 'EVENING', minutes: 15),
    ];
    expect(fitFromList(items, 30)!.title, 'Short');
    expect(fitFromList(items, 10), isNull);
  });

  test('times and lengths read plainly', () {
    expect(clock(1110), '18:30');
    expect(clock(5), '00:05');
    expect(duration(40), '40 min');
    expect(duration(95), '1h 35');
    expect(duration(120), '2h');
  });

  testWidgets('in free time: says so, and Start is the free-time button', (t) async {
    await _open(t, at: DateTime(2026, 11, 16, 19));
    expect(find.text('Good evening, Sam'), findsOneWidget);
    expect(find.text('FREE NOW'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('Draft the proposal outline'), findsOneWidget);
    expect(find.text('Call the bank'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('at work: shows when free time starts', (t) async {
    await _open(t, at: DateTime(2026, 11, 16, 14));
    expect(find.text('FREE AT 18:30'), findsOneWidget);
    expect(find.text('FREE NOW'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('ticking something on the list saves it and offers Undo', (t) async {
    final repo = await _open(t, at: DateTime(2026, 11, 16, 19));
    await t.ensureVisible(find.bySemanticsLabel('Call the bank'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.bySemanticsLabel('Call the bank'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.answered, contains('TASK:t2:DONE'));
    expect(find.text('Undo'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets("I've got time: asks for what fits the length, and cycles to something else", (t) async {
    final repo = await _open(t, at: DateTime(2026, 11, 16, 14));
    await t.ensureVisible(find.text("I've got time"));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text("I've got time"));
    // Not pumpAndSettle: the dial glow never stops. One frame to start the sheet, one to finish it.
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.tap(find.text('15 min'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Show me what fits'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.askedMinutes, 15);
    expect(repo.askedSmallest, isFalse);
    expect(find.text('25 min · Due Friday.'), findsOneWidget);
    await t.tap(find.text('Something else'));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Ask again'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets("I've got time works offline from today's list", (t) async {
    final repo = await _open(t, at: DateTime(2026, 11, 16, 14));
    repo.offline = true;
    await t.ensureVisible(find.text("I've got time"));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text("I've got time"));
    // Not pumpAndSettle: the dial glow never stops. One frame to start the sheet, one to finish it.
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    await t.tap(find.text('Show me what fits'));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining("You're offline"), findsOneWidget);
    // "Call the bank" is on the page behind and in the sheet's card.
    expect(find.text('Call the bank'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('fits a small phone at large text, top to bottom', (t) async {
    await _open(t, at: DateTime(2026, 11, 16, 19), size: const Size(320, 640), textScale: 1.5);
    for (var i = 0; i < 8; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
  });
}
