import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/places/done_screen.dart' show DoneChoice;
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/session/completion_screen.dart';
import 'package:lifeos_mobile/features/session/focus_session_screen.dart';
import 'package:lifeos_mobile/features/today/today_screen.dart';

Future<void> _size(WidgetTester t, {Size size = const Size(360, 760), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
}

/// Pushes [page] over an empty screen and hands back what it pops with.
Future<void Function()> _push<T>(WidgetTester t, Widget page, void Function(T?) result) async {
  final key = GlobalKey<NavigatorState>();
  await t.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
  key.currentState!.push<T>(MaterialPageRoute(builder: (_) => page)).then(result);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  return () => key.currentState!.pop();
}

// One suggestion with an area, for a server that says which area it is.
class _Repo implements LifeRepository {
  final List<String> answered = [];
  int overviewCalls = 0;

  @override
  bool get showingSaved => false;

  @override
  Future<Map<String, dynamic>?> nowSaved({bool smallest = false}) async => null;

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async => {
        'kind': 'PICK',
        'message': '',
        'options': [
          {
            'sourceType': 'PROJECT',
            'sourceId': 'p1',
            'title': 'Practise scales',
            'minutes': 25,
            'smaller': false,
            'minimum': 'Tune up',
            'why': 'Not touched this week.',
            'areaId': 'a2',
            'areaName': 'Hobby',
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> areasOverview() async {
    overviewCalls++;
    // The second read is after the session: the area has moved.
    final after = overviewCalls > 1;
    return {
      'areas': [
        {'id': 'a1', 'name': 'Work', 'mode': 'PUSH', 'value': 0.5, 'status': '2h of 4h this week'},
        {'id': 'a2', 'name': 'Hobby', 'mode': 'EXPLORE', 'value': after ? 0.6 : 0.2, 'status': after ? '1h of 2h this week' : '25 min of 2h this week'},
      ],
      'capacity': {'neededMinutes': 0, 'freeMinutes': 0, 'note': null},
    };
  }

  @override
  Future<List<Map<String, dynamic>>> daySchedule() async => const [];

  @override
  Future<Map<String, dynamic>> plan() async => const {'today': {'blocks': []}};

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    answered.add('$sourceType:$sourceId:$action:$minutes');
    return 'act1';
  }

  @override
  Future<void> undo(String activityId) async => answered.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('the clock counts up plainly', () {
    expect(elapsedText(Duration.zero), '0:00');
    expect(elapsedText(const Duration(seconds: 7)), '0:07');
    expect(elapsedText(const Duration(minutes: 12, seconds: 45)), '12:45');
    expect(elapsedText(const Duration(hours: 1, minutes: 2, seconds: 10)), '1:02:10');
    expect(elapsedText(const Duration(seconds: -4)), '0:00');
  });

  group('focus session', () {
    testWidgets('counts the time given and reports it on Done', (t) async {
      await _size(t);
      var now = DateTime(2026, 11, 16, 19);
      FocusOutcome? out;
      await _push<FocusOutcome>(
        t,
        FocusSessionScreen(title: 'Practise scales', minutes: 25, firstStep: 'Tune up', areaName: 'Hobby', clock: () => now),
        (r) => out = r,
      );
      expect(find.text('HOBBY · 25 MIN'), findsOneWidget);
      expect(find.text('First: Tune up'), findsOneWidget);
      now = now.add(const Duration(minutes: 12, seconds: 40));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('12:40'), findsOneWidget);
      await t.tap(find.text('Done'));
      await t.pump(const Duration(milliseconds: 600));
      expect(out!.end, FocusEnd.done);
      expect(out!.minutes, 13);
    });

    testWidgets('pause stops the clock; past the plan it says so, without pressure', (t) async {
      await _size(t);
      var now = DateTime(2026, 11, 16, 19);
      await _push<FocusOutcome>(t, FocusSessionScreen(title: 'Read', minutes: 1, clock: () => now), (_) {});
      await t.tap(find.text('Pause'));
      await t.pump();
      now = now.add(const Duration(minutes: 10));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      await t.tap(find.text('Resume'));
      await t.pump();
      now = now.add(const Duration(minutes: 1, seconds: 5));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('1:05'), findsOneWidget);
      expect(find.textContaining("That's the time you planned"), findsOneWidget);
    });

    testWidgets('a very short Done still counts as a minute; closing logs nothing', (t) async {
      await _size(t);
      FocusOutcome? out;
      await _push<FocusOutcome>(t, const FocusSessionScreen(title: 'Stretch', minutes: 5), (r) => out = r);
      await t.tap(find.text('Done'));
      await t.pump(const Duration(milliseconds: 600));
      expect(out!.minutes, 1);

      out = null;
      await _push<FocusOutcome>(t, const FocusSessionScreen(title: 'Stretch', minutes: 5), (r) => out = r);
      await t.tap(find.byTooltip('Stop without logging'));
      await t.pump(const Duration(milliseconds: 600));
      expect(out!.end, FocusEnd.stopped);
      expect(out!.minutes, 0);
    });

    testWidgets('fits a small phone at large text', (t) async {
      await _size(t, size: const Size(320, 640), textScale: 1.5);
      await _push<FocusOutcome>(
          t, const FocusSessionScreen(title: 'Finish the quarterly report draft and send it', minutes: 45, firstStep: 'Open the file'), (_) {});
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    });
  });

  group('completion moment', () {
    testWidgets('says what moved and offers Undo', (t) async {
      await _size(t);
      DoneChoice? choice;
      var popped = false;
      await _push<DoneChoice>(
        t,
        const CompletionScreen(
          title: 'Practise scales',
          minutes: 25,
          area: AreaMove(name: 'Hobby', color: Colors.cyan, from: 0.2, to: 0.6, status: '1h of 2h this week'),
          nextLine: "You're free until 23:00.",
          canUndo: true,
        ),
        (r) {
          popped = true;
          choice = r;
        },
      );
      await t.pump(const Duration(seconds: 2));
      expect(find.text('25 min into Hobby'), findsOneWidget);
      expect(find.text("Hobby: 1h of 2h this week.\nYou're free until 23:00."), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Hobby moved from 20 to 60 percent')), findsOneWidget);
      await t.tap(find.text('Undo'));
      await t.pump(const Duration(milliseconds: 600));
      expect(popped, isTrue);
      expect(choice, DoneChoice.undo);
    });

    testWidgets('without an area or Undo it stays simple, and settles with less motion', (t) async {
      await _size(t);
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(MaterialApp(
        navigatorKey: key,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const CompletionScreen(title: 'Call the bank', canUndo: false),
      ));
      await t.pump();
      expect(find.text('Done'), findsWidgets);
      expect(find.text('Undo'), findsNothing);
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fits a small phone at large text', (t) async {
      await _size(t, size: const Size(320, 640), textScale: 1.5);
      await _push<DoneChoice>(
        t,
        const CompletionScreen(
            title: 'Finish the quarterly report draft and send it to the team',
            minutes: 95,
            area: AreaMove(name: 'Work', color: Colors.orange, from: 0.4, to: 0.7, status: '3h of 5h this week'),
            nextLine: 'Next free time: 18:30.',
            canUndo: true),
        (_) {},
      );
      await t.pump(const Duration(seconds: 2));
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('Today: Start → focus → Done logs the time given and the area moves', (t) async {
    await _size(t);
    var now = DateTime(2026, 11, 16, 19);
    final repo = _Repo();
    final cubit = NowCubit(repo);
    addTearDown(cubit.close);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: BlocProvider.value(value: cubit, child: TodayScreen(firstName: 'Sam', repo: repo, clock: () => now))),
    ));
    await cubit.load();
    await t.pump(const Duration(seconds: 2));

    await t.tap(find.text('Start'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('HOBBY · 25 MIN'), findsOneWidget);

    // The focus screen reads the real clock; Done after a moment counts as one minute.
    await t.tap(find.text('Done'));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(repo.answered, contains('PROJECT:p1:DONE:1'));
    expect(find.text('1 min into Hobby'), findsOneWidget);
    expect(repo.overviewCalls, greaterThanOrEqualTo(2));

    await t.tap(find.text('Undo'));
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(repo.answered, contains('undo:act1'));
    expect(t.takeException(), isNull);
  });

  test('an area that cannot be read does not stop Done', () async {
    final repo = _NoOverview();
    final cubit = NowCubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    expect(await cubit.done(minutes: 7), isTrue);
    expect(repo.minutes, 7);
  });
}

class _NoOverview extends _Repo {
  int? minutes;

  @override
  Future<Map<String, dynamic>> areasOverview() async => throw const ApiException('Not found', statusCode: 404);

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    this.minutes = minutes;
    return 'act2';
  }
}
