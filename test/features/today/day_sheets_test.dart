import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/today/day_sheets.dart';
import 'package:lifeos_mobile/features/today/today_screen.dart';

class _Repo implements LifeRepository {
  final List<String> calls = [];
  String dayMode = 'NORMAL';
  bool smallest = false;

  @override
  bool get showingSaved => false;

  @override
  Future<Map<String, dynamic>?> nowSaved({bool smallest = false}) async => null;

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async {
    this.smallest = smallest;
    return {
      'kind': 'PICK',
      'message': '',
      'mode': dayMode,
      'options': [
        {'sourceType': 'TASK', 'sourceId': 't1', 'title': 'Write the intro', 'minutes': 25, 'smaller': false, 'minimum': 'Write one line', 'why': ''},
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> daySchedule() async => const [];

  @override
  Future<Map<String, dynamic>> plan() async => const {'today': {'blocks': []}};

  @override
  Future<String?> setDayMode(String mode, {String? until}) async {
    calls.add('mode:$mode:$until');
    dayMode = mode;
    return 'act-mode';
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<_Repo> _open(WidgetTester t, _Repo repo, {Size size = const Size(360, 900), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final cubit = NowCubit(repo);
  addTearDown(cubit.close);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(body: BlocProvider.value(value: cubit, child: TodayScreen(firstName: 'Sam', repo: repo, clock: () => DateTime(2026, 11, 16, 19)))),
  ));
  await cubit.load();
  await t.pump();
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

  test('every feeling has a line, a small thing, and nothing that blames', () {
    expect(feelings.map((f) => f.label), ['Low', "Can't start", 'Scrolling', 'Overthinking', 'Anxious', 'Good']);
    for (final f in feelings) {
      expect(f.line, isNotEmpty);
      expect(f.smallThing, isNotEmpty);
      for (final word in ['should', 'failed', 'lazy', 'behind', 'streak']) {
        expect('${f.line} ${f.smallThing}'.toLowerCase().contains(word), isFalse, reason: '${f.key}: $word');
      }
    }
    expect(feelings.where((f) => f.helpline).map((f) => f.key), ['low', 'anxious']);
  });

  testWidgets('feeling low: a kind line, the helpline, and an easy day', (t) async {
    final repo = await _open(t, _Repo());
    await _tap(t, find.text("I'm feeling…"));
    await _tap(t, find.text('Low'));
    expect(find.text('Low days happen. Nothing needs proving today.'), findsOneWidget);
    expect(find.textContaining('Tele-MANAS: 14416'), findsOneWidget);
    await _tap(t, find.text('Make today easy'));
    expect(find.textContaining('Today is easy'), findsOneWidget);
    expect(repo.smallest, isTrue);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('anxious shows a breath to follow; scrolling has no helpline', (t) async {
    await _open(t, _Repo());
    await _tap(t, find.text("I'm feeling…"));
    await _tap(t, find.text('Anxious'));
    expect(find.bySemanticsLabel('Breathe in for four seconds, out for six.'), findsOneWidget);
    await _tap(t, find.text('Scrolling'));
    expect(find.textContaining('Tele-MANAS'), findsNothing);
    await _tap(t, find.text('Just rest for now'));
    expect(find.text("I'm feeling…"), findsOneWidget);
  });

  testWidgets("can't start: two minutes of the next thing", (t) async {
    await _open(t, _Repo());
    await _tap(t, find.text("I'm feeling…"));
    await _tap(t, find.text("Can't start"));
    await _tap(t, find.text('Start two minutes'));
    expect(find.text('TASK · 2 MIN'), findsNothing);
    expect(find.textContaining('2 MIN'), findsOneWidget);
  });

  testWidgets('a different day: travelling for a few days, shown on Today, back to normal with Undo', (t) async {
    final repo = await _open(t, _Repo());
    await _tap(t, find.text('A different day'));
    expect(t.widget<Text>(find.text('Pick what kind of day')).data, isNotNull);
    await _tap(t, find.text('Travelling'));
    await _tap(t, find.text('A few days'));
    await _tap(t, find.text('Re-plan for travelling'));
    expect(repo.calls.last, 'mode:TRAVEL:2026-11-19');
    expect(find.text('Travelling: only small things that need no desk.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-mode');
    await _tap(t, find.text('Back to normal'));
    expect(repo.calls.last, 'mode:NORMAL:null');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the feeling sheet fits a small phone at large text', (t) async {
    await _open(t, _Repo(), size: const Size(320, 640), textScale: 1.5);
    await _tap(t, find.text("I'm feeling…"));
    await _tap(t, find.text('Low'));
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -800));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });
}
