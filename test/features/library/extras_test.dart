import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/areas/to_sort_card.dart';
import 'package:lifeos_mobile/features/library/library_page.dart';
import 'package:lifeos_mobile/features/today/rules_today_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool oldServer = false;
  int waiting = 5;

  @override
  Future<List<Map<String, dynamic>>> toSort() async {
    if (oldServer) throw const ApiException('Not found', statusCode: 404);
    return [
      {'id': 't1', 'title': 'Renew the gym card', 'suggestedAreaId': 'h'},
      {'id': 't2', 'title': 'Something odd', 'suggestedAreaId': null},
    ];
  }

  @override
  Future<({String message, String? activityId})> sortStep(String id, String areaId) async {
    calls.add('sort:$id:$areaId');
    return (message: 'Sorted.', activityId: 'act-sort');
  }

  @override
  Future<({String message, String? activityId})> letGoStep(String id) async {
    calls.add('letgo:$id');
    return (message: 'Let go.', activityId: 'act-letgo');
  }

  @override
  Future<List<Map<String, dynamic>>> rulesForToday() async => [
        {'id': 'n1', 'title': 'Eating out', 'items': ['Eat before you go', 'One sweet, slowly'], 'because': "Asha's birthday party"},
      ];

  @override
  Future<String?> setWhenNeeded(String id, bool on) async {
    calls.add('when:$id:$on');
    return 'act-when';
  }

  @override
  Future<({String message, bool byCode})> draftForPerson(String id) async {
    calls.add('draft:$id');
    return (message: 'Hi Asha, how did the new job start?', byCode: false);
  }

  @override
  Future<List<Map<String, dynamic>>> allyNotes() async => [];

  @override
  Future<List<Map<String, dynamic>>> saves() async => [
        for (var i = 0; i < waiting; i++) {'id': 's$i', 'title': 'Saved video $i', 'shelved': false, 'later': false},
      ];

  @override
  Future<({int count, String? activityId})> decideManySaves(List<String> ids, String choice) async {
    calls.add('many:${ids.join(",")}:$choice');
    return (count: ids.length, activityId: 'act-many');
  }

  @override
  Future<void> personContacted(String id) async => calls.add('contacted:$id');

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _open(WidgetTester t, Widget page, {Size size = const Size(360, 800), double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [page]))));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _openPage(WidgetTester t, Widget page) async {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final key = GlobalKey<NavigatorState>();
  await t.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
  key.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
  await t.pump();
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

const _areas = [(id: 'w', name: 'Work'), (id: 'h', name: 'Health')];

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('to sort', () {
    testWidgets('things with no area wait; the suggested area comes first; Undo', (t) async {
      final repo = _Repo();
      await _open(t, ToSortCard(repo: repo, areas: _areas));
      expect(find.text('2 things have no area yet'), findsOneWidget);
      await _tap(t, find.text('Sort them'));
      expect(find.text('Where does each go?'), findsOneWidget);
      // The suggested area is first and marked.
      final chips = find.descendant(of: find.ancestor(of: find.text('Renew the gym card'), matching: find.byType(Column)).first, matching: find.text('Health'));
      expect(chips, findsOneWidget);
      await _tap(t, find.text('Health').first);
      expect(repo.calls, ['sort:t1:h']);
      await _tap(t, find.text('Let it go'));
      expect(repo.calls.last, 'letgo:t2');
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Undo'), findsWidgets);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('an older server: nothing shows', (t) async {
      await _open(t, ToSortCard(repo: _Repo()..oldServer = true, areas: _areas));
      expect(find.textContaining('no area yet'), findsNothing);
    });
  });

  testWidgets('rules show before a matching event; Got it hides them for today', (t) async {
    await _open(t, RulesTodayCard(repo: _Repo(), clock: () => DateTime(2026, 11, 16)));
    expect(find.text("FOR ASHA'S BIRTHDAY PARTY"), findsOneWidget);
    expect(find.text('Eat before you go'), findsOneWidget);
    await _tap(t, find.text('Got it'));
    expect(find.text('Eating out'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await _open(t, RulesTodayCard(repo: _Repo(), clock: () => DateTime(2026, 11, 16)));
    expect(find.text('Eating out'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await _open(t, RulesTodayCard(repo: _Repo(), clock: () => DateTime(2026, 11, 17)));
    expect(find.text('Eating out'), findsOneWidget);
  });

  testWidgets('a rules note can be shown when needed, with Undo', (t) async {
    final repo = _Repo();
    await _openPage(
        t,
        NotePage(
          note: const {'id': 'n1', 'collection': 'Fitness', 'template': 'PLAYBOOK', 'title': 'Eating out', 'items': ['Eat before you go']},
          repo: repo,
        ));
    await _tap(t, find.bySemanticsLabel('Show me these when I need them'));
    expect(repo.calls, ['when:n1:true']);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-when');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a drafted message to copy or open in WhatsApp; Ally never sends it', (t) async {
    final repo = _Repo();
    String? opened;
    await _openPage(
        t,
        PersonPage(
          person: const {'id': 'p1', 'collection': 'People', 'title': 'Asha', 'items': ['Started a new job'], 'meta': {'phone': '9876543210'}},
          repo: repo,
          open: (_, url) => opened = url,
        ));
    await _tap(t, find.text('Draft a message'));
    expect(find.text("ALLY'S DRAFT · YOU SEND IT"), findsOneWidget);
    expect(find.text('Hi Asha, how did the new job start?'), findsOneWidget);
    await _tap(t, find.text('Open in WhatsApp'));
    expect(opened, startsWith('https://wa.me/919876543210?text=Hi%20Asha'));
    expect(repo.calls, ['draft:p1', 'contacted:p1']);
  });

  testWidgets('the weekly clean-up keeps the two newest and moves the rest, with Undo', (t) async {
    final repo = _Repo();
    await _openPage(t, LibraryPage(repo: repo, start: LibrarySection.saved));
    expect(find.text('5 waiting for a decision'), findsOneWidget);
    await _tap(t, find.text('Move 3 to watch later'));
    expect(repo.calls, ['many:s2,s3,s4:LATER']);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-many');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('the clean-up is not offered for a few saves', (t) async {
    await _openPage(t, LibraryPage(repo: _Repo()..waiting = 3, start: LibrarySection.saved));
    expect(find.textContaining('waiting for a decision'), findsNothing);
  });

  testWidgets('the cards fit a small phone at large text', (t) async {
    await _open(t, ToSortCard(repo: _Repo(), areas: _areas), size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
    await _open(t, RulesTodayCard(repo: _Repo()), size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
  });
}
