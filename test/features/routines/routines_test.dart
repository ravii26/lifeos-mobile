import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/models/habit.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/routines/new_routine_screen.dart';
import 'package:lifeos_mobile/features/routines/routine_page.dart';
import 'package:lifeos_mobile/features/routines/routine_words.dart';

// One generic routine.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool done = false;
  bool active = true;
  String frequency = 'CUSTOM';
  List<String> days = const ['MON', 'WED', 'FRI'];
  String? part = 'EVENING';
  String? smaller = 'One page';
  String? reminder = '21:00';

  @override
  Future<List<Habit>> habits({bool? activeOnly}) async => [
        Habit.fromJson({
          'id': 'h1',
          'title': 'Read 10 pages',
          'habitType': 'BOOLEAN',
          'frequency': frequency,
          'specificDays': days,
          'timeBlock': part,
          'minimumVersion': smaller,
          'reminderTime': reminder,
          'isActive': active,
          'todayDone': done,
          'history': [for (var i = 0; i < 28; i++) i % 3 == 0],
        }),
      ];

  @override
  Future<void> logHabit(String id, {bool completed = true, int? count, int? minutes, DateTime? date}) async {
    calls.add('log:$id:$completed');
    done = completed;
  }

  @override
  Future<Habit> updateHabit(String id,
      {String? title,
      String? areaId,
      String? habitType,
      int? targetCount,
      int? targetMinutes,
      String? frequency,
      String? reminderTime,
      bool? isActive,
      String? minimumVersion,
      List<String>? specificDays,
      int? weeklyTarget,
      String? timeBlock,
      bool anytime = false}) async {
    calls.add('update:${[
      if (frequency != null) 'f=$frequency',
      if (specificDays != null) 'd=${specificDays.join(",")}',
      if (weeklyTarget != null) 'w=$weeklyTarget',
      if (timeBlock != null) 't=$timeBlock',
      if (anytime) 'anytime',
      if (minimumVersion != null) 'min=$minimumVersion',
      if (reminderTime != null) 'rem=$reminderTime',
      if (isActive != null) 'active=$isActive',
    ].join(' ')}');
    if (frequency != null) this.frequency = frequency;
    if (specificDays != null) days = specificDays;
    if (anytime) part = null;
    if (timeBlock != null) part = timeBlock;
    if (minimumVersion != null) smaller = minimumVersion.isEmpty ? null : minimumVersion;
    if (reminderTime != null) reminder = reminderTime.isEmpty ? null : reminderTime;
    if (isActive != null) active = isActive;
    return (await habits()).first;
  }

  @override
  Future<Habit> createHabit({
    required String title,
    required String areaId,
    String habitType = 'BOOLEAN',
    int? targetCount,
    int? targetMinutes,
    String frequency = 'DAILY',
    String? reminderTime,
    String? description,
    String? minimumVersion,
    List<String>? specificDays,
    int? weeklyTarget,
    String? timeBlock,
  }) async {
    calls.add('create:$title:$areaId:$frequency:${specificDays?.join(",")}:$weeklyTarget:$timeBlock:$minimumVersion:$reminderTime');
    return (await habits()).first;
  }

  @override
  Future<void> undo(String activityId) async {}

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

Future<void> _openPage(WidgetTester t, _Repo repo) async {
  await t.pumpWidget(MaterialApp(home: RoutinePage(habitId: 'h1', repo: repo, areaName: 'Learning', color: Colors.teal)));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('words', () {
    test('when it happens, plainly', () {
      expect(whenWords(frequency: 'DAILY'), 'Every day');
      expect(whenWords(frequency: 'CUSTOM', days: ['FRI', 'MON', 'WED']), 'Mon, Wed, Fri');
      expect(whenWords(frequency: 'CUSTOM', days: ['MON', 'TUE', 'WED', 'THU', 'FRI']), 'Weekdays');
      expect(whenWords(frequency: 'CUSTOM', days: ['SAT', 'SUN']), 'Weekends');
      expect(whenWords(frequency: 'WEEKLY', weeklyTarget: 3), '3 times a week');
      expect(whenWords(frequency: 'WEEKLY', weeklyTarget: 1), 'Once a week');
    });
    test('the last weeks as a count, never a streak', () {
      expect(lastDaysWords([true, false, true]), '2 of the last 3 days');
      expect(lastDaysWords([]), 'Nothing logged yet');
    });
  });

  testWidgets('the routine page: today, the last weeks, when, smaller version, reminder', (t) async {
    await _size(t);
    await _openPage(t, _Repo());
    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('Mon, Wed, Fri · evening'), findsWidgets);
    expect(find.text('Not yet'), findsOneWidget);
    expect(find.bySemanticsLabel('10 of the last 28 days'), findsOneWidget);
    expect(find.text('One page'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
  });

  testWidgets('done today, with Undo', (t) async {
    await _size(t);
    final repo = _Repo();
    await _openPage(t, repo);
    await _tap(t, find.bySemanticsLabel('Read 10 pages today'));
    expect(repo.calls.last, 'log:h1:true');
    expect(find.text('Done'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'log:h1:false');
  });

  testWidgets('change when: a few times a week, anytime; Undo puts it back', (t) async {
    await _size(t);
    final repo = _Repo();
    await _openPage(t, repo);
    await _tap(t, find.text('Change').first);
    await _tap(t, find.text('A few times'));
    await _tap(t, find.text('Anytime'));
    await _tap(t, find.textContaining('Save: '));
    expect(repo.calls.last, 'update:f=WEEKLY d= w=3 anytime');
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'update:f=CUSTOM d=MON,WED,FRI t=EVENING');
  });

  testWidgets('some days needs at least one day', (t) async {
    await _size(t);
    await _openPage(t, _Repo()
      ..frequency = 'DAILY'
      ..days = const []);
    await _tap(t, find.text('Change').first);
    await _tap(t, find.text('Some days'));
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Pick at least one day')).onPressed, isNull);
  });

  testWidgets('stop is not delete, and comes back', (t) async {
    await _size(t);
    final repo = _Repo();
    await _openPage(t, repo);
    await _tap(t, find.text('Stop this routine'));
    expect(repo.calls.last, 'update:active=false');
    expect(find.text('Start it again'), findsOneWidget);
    await _tap(t, find.text('Start it again'));
    expect(repo.calls.last, 'update:active=true');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a new routine: name, area, days, part of day, smaller version', (t) async {
    await _size(t);
    final repo = _Repo();
    bool? added;
    final key = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
    key.currentState!
        .push<bool>(MaterialPageRoute(builder: (_) => NewRoutineScreen(repo: repo, areas: const [('a1', 'Health'), ('a2', 'Learning')])))
        .then((r) => added = r);
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Add routine')).onPressed, isNull);
    await t.enterText(find.widgetWithText(TextField, 'For example: Read 10 pages'), 'Stretch');
    await t.pump();
    await _tap(t, find.text('Learning'));
    await _tap(t, find.text('Some days'));
    await _tap(t, find.text('Tue'));
    await _tap(t, find.text('Thu'));
    await _tap(t, find.text('Morning'));
    await t.enterText(find.widgetWithText(TextField, 'For a hard day, e.g. "read one page"'), 'Two stretches');
    await t.pump();
    await _tap(t, find.text('Add routine'));
    expect(repo.calls.single, 'create:Stretch:a2:CUSTOM:TUE,THU:null:MORNING:Two stretches:null');
    expect(added, isTrue);
  });

  testWidgets('the routine page fits a small phone at large text', (t) async {
    await _size(t, size: const Size(320, 640), textScale: 1.5);
    await _openPage(t, _Repo());
    await t.drag(find.byType(ListView), const Offset(0, -1500));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });
}
