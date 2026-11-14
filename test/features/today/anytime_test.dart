import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/today/today_screen.dart';

// A day with every "anytime" line at once. Generic sample data.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool withExtras = true;
  bool empty = false;
  int water = 3;
  bool stepDone = false;

  @override
  bool get showingSaved => false;

  @override
  Future<Map<String, dynamic>?> nowSaved({bool smallest = false}) async => null;

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async => {
        'kind': empty ? 'EMPTY' : 'PICK',
        'message': '',
        'options': empty
            ? []
            : [
                {'sourceType': 'TASK', 'sourceId': 't1', 'title': 'Draft the outline', 'minutes': 25, 'smaller': false, 'minimum': '', 'why': ''},
              ],
        if (withExtras) ...{
          'counts': [
            {'id': 'w', 'title': 'Water', 'count': water, 'target': 8},
          ],
          'timer': {'label': 'reading', 'minutes': 12, 'forgotten': false},
          'routine': {
            'id': 'r1',
            'title': 'Evening reset',
            'steps': [
              {'text': 'Clear the desk', 'done': stepDone},
              {'text': 'Lay out clothes', 'done': false},
            ],
          },
          'meal': {'meal': 'dinner', 'text': 'Dal and rice', 'tomorrow': false},
          'watchLater': {'id': 's1', 'title': 'A talk', 'url': null, 'line': 'A 12-minute talk you saved fits now.'},
        },
      };

  @override
  Future<List<Map<String, dynamic>>> daySchedule() async => const [];

  @override
  Future<Map<String, dynamic>> plan() async => const {'today': {'blocks': []}};

  @override
  Future<Map<String, dynamic>> addCount(String habitId, {int n = 1}) async {
    calls.add('count:$habitId');
    water++;
    return const {};
  }

  @override
  Future<Map<String, dynamic>> tickNote(String id, String item, bool done) async {
    calls.add('tick:$id:$item:$done');
    stepDone = done;
    return const {};
  }

  @override
  Future<void> markSaveWatched(String id) async => calls.add('watched:$id');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_Repo> _open(WidgetTester t, _Repo repo, {Size size = const Size(360, 760), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final cubit = NowCubit(repo);
  addTearDown(cubit.close);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: TodayScreen(firstName: 'Sam', repo: repo, clock: () => DateTime(2026, 11, 16, 19)),
      ),
    ),
  ));
  await cubit.load();
  await t.pump(const Duration(seconds: 2));
  return repo;
}

Future<void> _show(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('shows every anytime line that applies', (t) async {
    await _open(t, _Repo());
    await _show(t, find.text('ANYTIME TODAY'));
    for (final s in ['Water', '3 of 8', 'reading · 12 min', 'Dal and rice', 'Next meal: dinner', 'Evening reset', '2 left', 'Clear the desk']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('A 12-minute talk you saved fits now.'), findsOneWidget);
    expect(find.text('Open the previous Now screen'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('+1 adds a count and the line updates', (t) async {
    final repo = await _open(t, _Repo());
    await _show(t, find.bySemanticsLabel('Add one: Water'));
    await t.tap(find.bySemanticsLabel('Add one: Water'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.calls, contains('count:w'));
    expect(find.text('4 of 8'), findsOneWidget);
  });

  testWidgets('a routine step ticks, and can be unticked', (t) async {
    final repo = await _open(t, _Repo());
    await _show(t, find.bySemanticsLabel('Clear the desk'));
    await t.tap(find.bySemanticsLabel('Clear the desk'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.calls, contains('tick:r1:Clear the desk:true'));
    expect(find.text('1 left'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Clear the desk'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.calls, contains('tick:r1:Clear the desk:false'));
  });

  testWidgets('a saved video can be marked watched', (t) async {
    final repo = await _open(t, _Repo());
    await _show(t, find.text('Watched'));
    await t.tap(find.text('Watched'));
    await t.pump(const Duration(seconds: 1));
    expect(repo.calls, contains('watched:s1'));
  });

  testWidgets('nothing anytime: no section; the brain dump is always reachable', (t) async {
    await _open(t, _Repo()..withExtras = false);
    expect(find.text('ANYTIME TODAY'), findsNothing);
    await _show(t, find.text('My head is full'));
    expect(find.text('My head is full'), findsOneWidget);
  });

  testWidgets('an empty list offers to tell Ally or say everything', (t) async {
    await _open(t, _Repo()
      ..withExtras = false
      ..empty = true);
    expect(find.text('Nothing on your list yet'), findsOneWidget);
    expect(find.text('Tell Ally'), findsOneWidget);
    expect(find.text('Say everything on your mind'), findsOneWidget);
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _open(t, _Repo(), size: const Size(320, 640), textScale: 1.5);
    for (var i = 0; i < 10; i++) {
      await t.drag(find.byType(ListView), const Offset(0, -400));
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
  });
}
