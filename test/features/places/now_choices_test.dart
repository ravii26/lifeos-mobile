import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/places/done_screen.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/places/you_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements LifeRepository {
  final calls = <String>[];

  @override
  bool get showingSaved => false;

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async => {
        'kind': 'PICK',
        'message': '',
        'options': [
          {'sourceType': 'TASK', 'sourceId': 't1', 'title': 'One DSA problem', 'minutes': 30, 'minimum': 'Read it', 'why': 'x'},
        ],
      };

  @override
  Future<Map<String, dynamic>> nowAdvice(String sourceType, String sourceId, String choice) async {
    calls.add('$sourceType/$sourceId/$choice');
    return {'message': 'Moved to tomorrow.', 'activityId': 'a1'};
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Not now and finishing for today', () {
    test('moving a task asks the server, says so, and can be undone', () async {
      final repo = _Repo();
      final cubit = NowCubit(repo);
      await cubit.load();
      await cubit.moveCurrent('TOMORROW');
      expect(repo.calls, ['TASK/t1/TOMORROW']);
      expect(cubit.state.note, 'Moved to tomorrow.');
      expect(cubit.state.undoId, 'a1');
      await cubit.close();
    });

    test('finished for today stops suggestions until asked for more', () async {
      final cubit = NowCubit(_Repo());
      await cubit.load();
      expect(cubit.state.current, isNotNull);

      await cubit.finishForToday();
      expect(cubit.state.restedToday, isTrue);
      expect(cubit.state.current, isNull);

      await cubit.load();
      expect(cubit.state.restedToday, isTrue, reason: 'a refresh must not bring tasks back');

      await cubit.resumeToday();
      expect(cubit.state.restedToday, isFalse);
      expect(cubit.state.current, isNotNull);
      await cubit.close();
    });
  });

  group('My life goals', () {
    test('only active goals are in focus, three at most', () {
      final focus = focusGoals([
        {'title': 'a', 'status': 'PAUSED'},
        {'title': 'b', 'status': 'ACTIVE'},
        {'title': 'c', 'status': 'ACTIVE'},
        {'title': 'd', 'status': 'ACTIVE'},
        {'title': 'e', 'status': 'ACTIVE'},
      ]);
      expect(focus.map((p) => p['title']), ['b', 'c', 'd']);
    });

    test('progress is read safely', () {
      expect(goalProgress({'detail': {'percent': 25}}), 0.25);
      expect(goalProgress({'detail': {'percent': 140}}), 1);
      expect(goalProgress({'detail': {}}), isNull);
      expect(goalProgress({}), isNull);
    });
  });

  testWidgets('Done screen offers next, rest and undo, and fits a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<NavigatorState>();
    DoneChoice? got;
    await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
    key.currentState!
        .push<DoneChoice>(MaterialPageRoute(builder: (_) => const DoneScreen(title: 'One DSA problem', canUndo: true)))
        .then((c) => got = c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('That counts.'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(got, DoneChoice.undo);
  });
}
