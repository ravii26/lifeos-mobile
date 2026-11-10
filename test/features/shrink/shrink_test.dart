import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/shrink/shrink_cubit.dart';
import 'package:lifeos_mobile/features/shrink/shrink_screen.dart';

class _Repo implements LifeRepository {
  final decisions = <String>[];
  final undone = <String>[];
  bool canLetGo = true;

  @override
  Future<Map<String, dynamic>> pile() async => {
        'items': [
          {'sourceType': 'PROJECT', 'sourceId': 'p', 'title': 'Job switch', 'weeklyMinutes': 300, 'ageLine': 'On your list for 8 months', 'needs': 'Needs about 5 hours a week.'},
          {'sourceType': 'HABIT', 'sourceId': 'h', 'title': 'Learn guitar', 'weeklyMinutes': 180, 'needs': 'Needs about 3 hours a week.'},
          {'sourceType': 'TASK', 'sourceId': 't', 'title': 'Clean the desk', 'weeklyMinutes': 60, 'needs': 'Needs about 1 hour.'},
        ],
        'count': 3,
        'weeklyMinutes': 540,
        'freeMinutes': 360,
        'parkLabel': 'January',
        'canLetGo': canLetGo,
      };

  @override
  Future<Map<String, dynamic>> decidePile(String sourceType, String sourceId, String decision) async {
    decisions.add('$sourceId/$decision');
    return {'message': 'ok', 'activityId': 'a-$sourceId'};
  }

  @override
  Future<void> undo(String activityId) async => undone.add(activityId);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('hours read the way a person says them', () {
    expect(hoursText(45), '45 minutes');
    expect(hoursText(60), '1 hour');
    expect(hoursText(100), '1.5 hours');
    expect(hoursText(3600), '60 hours');
  });

  group('a pass through the list', () {
    test('counts what is left after parking and letting go', () async {
      final repo = _Repo();
      final c = ShrinkCubit(repo);
      await c.load();
      expect(c.state.stage, ShrinkStage.summary);
      expect(c.state.fits, isFalse);

      c.begin();
      c.keep();
      await c.park();
      await c.letGo();

      expect(repo.decisions, ['h/PARK', 't/LET_GO']);
      expect(c.state.stage, ShrinkStage.result);
      expect(c.state.remainingMinutes, 300);
      expect(c.state.fits, isTrue);
      await c.close();
    });

    test('going back takes the decision back', () async {
      final repo = _Repo();
      final c = ShrinkCubit(repo);
      await c.load();
      c.begin();
      await c.park();
      await c.back();
      expect(repo.undone, ['a-p']);
      expect(c.state.decided, isEmpty);
      expect(c.state.current?.sourceId, 'p');
      await c.back();
      expect(c.state.stage, ShrinkStage.summary);
      await c.close();
    });

    test('stopping early keeps what was decided', () async {
      final c = ShrinkCubit(_Repo());
      await c.load();
      c.begin();
      await c.park();
      c.finishEarly();
      expect(c.state.stage, ShrinkStage.result);
      expect(c.state.parked.length, 1);
      await c.close();
    });

    test('letting go is not offered on a low-energy day', () async {
      final c = ShrinkCubit(_Repo(), lowEnergy: true);
      await c.load();
      expect(c.state.canLetGo, isFalse);
      await c.close();
    });
  });

  group('screens fit a small phone', () {
    Future<ShrinkCubit> show(WidgetTester tester, _Repo repo) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ShrinkCubit(repo);
      await c.load();
      await tester.pumpWidget(MaterialApp(home: BlocProvider.value(value: c, child: const ShrinkScreen())));
      await tester.pump();
      return c;
    }

    testWidgets('all the way through', (tester) async {
      final c = await show(tester, _Repo());
      expect(find.text('No wonder it feels heavy.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text("Let's choose together"));
      await tester.pump();
      expect(find.text('Job switch'), findsOneWidget);
      expect(find.text('Park until January'), findsOneWidget);
      expect(find.text('Let it go'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Keep in focus'));
      await tester.pump();
      await tester.tap(find.text('Park until January'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Let it go'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Much lighter now.'), findsOneWidget);
      expect(find.text('Parked safely'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await c.close();
    });

    testWidgets('no Let it go when the server says not today', (tester) async {
      final repo = _Repo()..canLetGo = false;
      final c = await show(tester, repo);
      await tester.tap(find.text("Let's choose together"));
      await tester.pump();
      expect(find.text('Let it go'), findsNothing);
      await c.close();
    });
  });
}
