import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/data/models/know.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/you/ally_works_page.dart';
import 'package:lifeos_mobile/features/you/history_page.dart';
import 'package:lifeos_mobile/features/you/memories_page.dart';
import 'package:lifeos_mobile/features/you/reminders_page.dart';
import 'package:lifeos_mobile/features/you/search_page.dart';

final _now = DateTime(2026, 11, 16, 9);

// Generic sample data for every You page.
class _Repo implements LifeRepository {
  final List<String> calls = [];
  final Set<String> undone = {};
  final Set<String> forgotten = {};
  bool private = false;
  String focus = 'ALL';
  String tone = 'BALANCED';
  bool ask = false;

  @override
  Future<KnowCardData> knowNext() async => ask
      ? const KnowCardData(
          question: KnowQuestion(id: 'q1', text: 'When do you usually have free time?', why: 'So suggestions land when you can use them.', options: ['Mornings', 'Evenings'], allowText: true),
          answered: 2,
          total: 8,
        )
      : const KnowCardData(answered: 3, total: 8);

  @override
  Future<KnowReply> knowAnswer(String id, {String? answer, bool skip = false}) async {
    calls.add('know:$id:${skip ? 'skip' : answer}');
    ask = false;
    return KnowReply(skip ? 'No problem.' : 'Got it: $answer.');
  }

  @override
  Future<List<Reminder>> reminders() async => [
        Reminder('r2', 'Pay rent', DateTime(2026, 11, 17, 10)),
        Reminder('r1', 'Call the clinic', DateTime(2026, 11, 16, 18, 30), null, const [], true),
      ];

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    calls.add('done:$sourceId');
    return 'act-done';
  }

  @override
  Future<({String message, String? activityId})> letGoStep(String id) async {
    calls.add('letgo:$id');
    return (message: 'ok', activityId: 'act-letgo');
  }

  @override
  Future<void> undo(String activityId) async {
    calls.add('undo:$activityId');
    undone.add(activityId);
  }

  @override
  Future<List<Map<String, dynamic>>> activity({int days = 30}) async => [
        {'id': 'e1', 'title': 'Read 10 pages', 'type': 'LOGGED', 'at': '2026-11-16T03:00:00Z', 'undo': {'kind': 'DELETE_HABIT_LOG'}, 'undoneAt': undone.contains('e1') ? '2026-11-16T04:00:00Z' : null},
        {'id': 'e2', 'title': 'Skipped the gym', 'type': 'SKIPPED', 'at': '2026-11-15T12:00:00Z', 'undo': {'kind': 'NOOP'}, 'undoneAt': null},
      ];

  @override
  Future<List<Map<String, dynamic>>> search(String q) async {
    calls.add('search:$q');
    if (q == 'zzz') return [];
    return [
      {'kind': 'NOTE', 'id': 'n1', 'title': 'Trip packing', 'snippet': 'Charger, passport, two shirts', 'score': 1},
      {'kind': 'MEMORY', 'id': 'm1', 'title': 'Prefers mornings for deep work', 'snippet': '', 'score': 0.5},
    ];
  }

  @override
  Future<List<MemoryItem>> memories() async => [
        if (!forgotten.contains('m1')) MemoryItem('m1', 'Prefers mornings for deep work', 'FACT', _now, saidByYou: true, sensitive: private, quote: 'I think best before 10'),
        MemoryItem('m2', 'Lives in Pune', 'FACT', _now, endedAt: DateTime(2026, 1, 1)),
      ];

  @override
  Future<void> deleteMemory(String id) async {
    calls.add('forget:$id');
    forgotten.add(id);
  }

  @override
  Future<void> setMemoryPrivate(String id, bool sensitive) async {
    calls.add('private:$id:$sensitive');
    private = sensitive;
  }

  @override
  Future<({String focus, String directness})> allyPreferences() async => (focus: focus, directness: tone);

  @override
  Future<void> saveAllyPreferences({String? focus, String? directness}) async {
    calls.add('prefs:$focus:$directness');
    if (focus != null) this.focus = focus;
    if (directness != null) tone = directness;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _open(WidgetTester t, Widget page, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(MaterialApp(home: page));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
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

  testWidgets('reminders: by day, in order; done and let go each offer Undo', (t) async {
    final repo = _Repo();
    await _open(t, RemindersPage(repo: repo, clock: () => _now, onCheckDelivery: () {}));
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('TOMORROW'), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    expect(find.textContaining('Check yours in two steps'), findsOneWidget);

    await _tap(t, find.text('Call the clinic'));
    await _tap(t, find.text('Done'));
    expect(repo.calls.last, 'done:r1');
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-done');

    await _tap(t, find.text('Pay rent'));
    await _tap(t, find.text('Let it go'));
    expect(repo.calls.last, 'letgo:r2');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('history: Undo only where something can be put back', (t) async {
    final repo = _Repo();
    await _open(t, HistoryPage(repo: repo, clock: () => _now));
    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('Skipped the gym'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.single, 'undo:e1');
    expect(find.text('Undone'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('search: waits for typing to pause, labels each match, opens it', (t) async {
    final repo = _Repo();
    SearchHit? opened;
    await _open(t, SearchPage(repo: repo, onOpen: (h) => opened = h));
    await t.enterText(find.byType(TextField), 'pa');
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(find.byType(TextField), 'packing');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 300));
    expect(repo.calls, ['search:packing']);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('ALLY REMEMBERS'), findsOneWidget);
    expect(find.text('Charger, passport, two shirts'), findsOneWidget);
    await _tap(t, find.text('Trip packing'));
    expect(opened!.id, 'n1');

    await t.enterText(find.byType(TextField), 'zzz');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Nothing matches "zzz".'), findsOneWidget);
  });

  testWidgets('memories: forget waits for Undo, so Undo really keeps it', (t) async {
    final repo = _Repo();
    await _open(t, MemoriesPage(repo: repo, forgetAfter: const Duration(seconds: 3)));
    expect(find.text('Prefers mornings for deep work'), findsOneWidget);
    expect(find.text('NO LONGER TRUE'), findsOneWidget);

    await _tap(t, find.text('Prefers mornings for deep work'));
    expect(find.text('Your words: “I think best before 10”'), findsOneWidget);
    await _tap(t, find.text('Forget this'));
    expect(find.text('Prefers mornings for deep work'), findsNothing);
    await _tap(t, find.text('Undo'));
    expect(find.text('Prefers mornings for deep work'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(repo.calls, isNot(contains('forget:m1')));

    await _tap(t, find.text('Prefers mornings for deep work'));
    await _tap(t, find.text('Forget this'));
    await t.pump(const Duration(seconds: 4));
    expect(repo.calls, contains('forget:m1'));
  });

  testWidgets('memories: keep one private, with Undo', (t) async {
    final repo = _Repo();
    await _open(t, MemoriesPage(repo: repo));
    await _tap(t, find.text('Prefers mornings for deep work'));
    await _tap(t, find.text('Keep it private'));
    expect(repo.calls.last, 'private:m1:true');
    expect(find.textContaining('Private'), findsWidgets);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'private:m1:false');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('memories: one getting-to-know-you question at a time; answering or skipping', (t) async {
    final repo = _Repo()..ask = true;
    await _open(t, MemoriesPage(repo: repo));
    expect(find.text('GETTING TO KNOW YOU · 2 OF 8'), findsOneWidget);
    expect(find.text('When do you usually have free time?'), findsOneWidget);
    await _tap(t, find.text('Evenings'));
    expect(repo.calls.last, 'know:q1:Evenings');
    expect(find.text('Got it: Evenings.'), findsOneWidget);
    expect(find.text('When do you usually have free time?'), findsNothing);
    await t.pump(const Duration(seconds: 7));
    expect(find.text('Got it: Evenings.'), findsNothing);

    repo.ask = true;
    await t.pumpWidget(const SizedBox());
    await _open(t, MemoriesPage(repo: repo));
    await _tap(t, find.text('Skip for now'));
    expect(repo.calls.last, 'know:q1:skip');
    await t.pump(const Duration(seconds: 7));
  });

  testWidgets('memories: with nothing to ask there is no card', (t) async {
    await _open(t, MemoriesPage(repo: _Repo()));
    expect(find.textContaining('GETTING TO KNOW YOU'), findsNothing);
  });

  testWidgets('how Ally works: a choice saves at once, with Undo', (t) async {
    final repo = _Repo();
    await _open(t, AllyWorksPage(repo: repo));
    await _tap(t, find.text('Direct'));
    expect(repo.calls.last, 'prefs:null:DIRECT');
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'prefs:null:BALANCED');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('each page fits a small phone at large text', (t) async {
    for (final page in [
      RemindersPage(repo: _Repo(), clock: () => _now, onCheckDelivery: () {}),
      HistoryPage(repo: _Repo(), clock: () => _now),
      MemoriesPage(repo: _Repo()..ask = true),
      AllyWorksPage(repo: _Repo()),
    ]) {
      await _open(t, page, size: const Size(320, 640), textScale: 1.5);
      await t.drag(find.byType(ListView).first, const Offset(0, -1200));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });
}
