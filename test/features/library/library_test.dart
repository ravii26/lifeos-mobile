import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/tonight.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/library/library_page.dart';
import 'package:lifeos_mobile/features/library/library_words.dart';
import 'package:lifeos_mobile/features/library/save_flow.dart';
import 'package:lifeos_mobile/features/talk/talk_screen.dart' show talkPrefill;

final _now = DateTime(2026, 11, 16, 9);

// Generic sample notes, people and saves.
List<Map<String, dynamic>> _notes() => [
      {'id': 'n1', 'collection': 'Home', 'template': 'LIST', 'title': 'Packing', 'items': ['Charger', 'Passport', 'Two shirts'], 'done': ['Charger']},
      {'id': 'n2', 'collection': 'Fitness', 'template': 'PLAYBOOK', 'title': 'Eating out', 'items': ['Eat before you go', 'One sweet, slowly']},
      {'id': 'n3', 'collection': 'Me', 'template': 'INFO', 'title': 'Who I want to be', 'items': [], 'text': 'Someone who keeps small promises.'},
      {
        'id': 'p1', 'collection': 'People', 'template': 'INFO', 'title': 'Asha', 'items': ['Started a new job in October'],
        'meta': {'phone': '9876543210', 'birthday': {'day': 3, 'month': 2}, 'lastContact': '2026-11-08T10:00:00Z'},
      },
    ];

List<Map<String, dynamic>> _saves() => [
      {'id': 's1', 'title': 'Binary search in 9 minutes', 'shelved': false, 'later': false, 'url': 'https://youtu.be/x', 'platform': 'YouTube'},
      {'id': 's2', 'title': 'A long talk on habits', 'shelved': false, 'later': true, 'minutes': 40, 'platform': 'YouTube'},
      {'id': 's3', 'title': 'Something kind', 'shelved': true, 'later': false},
    ];

SaveProposal _proposal({String summary = 'NONE', bool step = true}) => SaveProposal.fromJson({
      'id': 's9',
      'platform': 'YouTube',
      'proposal': {
        'contentTitle': 'Binary search in 9 minutes',
        'action': step ? 'Solve 2 binary-search problems' : '',
        'minimum': step ? 'Read one solution' : '',
        'when': 'THIS_WEEK',
        'actions': step
            ? [
                {'action': 'Solve 2 binary-search problems', 'minimum': 'Read one solution', 'as': 'TODO', 'when': 'THIS_WEEK'},
              ]
            : [],
      },
      'summary': {'state': summary},
    });

class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool offline = false;
  bool noStep = false;

  @override
  Future<List<Map<String, dynamic>>> allyNotes() async {
    if (offline) throw const ApiException('No connection');
    return _notes();
  }

  @override
  Future<List<Map<String, dynamic>>> saves() async => _saves();

  @override
  Future<Map<String, dynamic>> tickNote(String id, String item, bool done) async {
    calls.add('tick:$id:$item:$done');
    return {};
  }

  @override
  Future<String?> deleteAllyNote(String id) async {
    calls.add('delete:$id');
    return 'act-del';
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo:$activityId');

  @override
  Future<void> personContacted(String id) async => calls.add('contacted:$id');

  @override
  Future<void> markSaveWatched(String id) async => calls.add('watched:$id');

  @override
  Future<SaveProposal> createSave(String text) async {
    calls.add('create:$text');
    return _proposal(step: !noStep);
  }

  @override
  Future<SaveProposal> getSave(String id) async {
    calls.add('get:$id');
    return _proposal(step: !noStep);
  }

  @override
  Future<SaveProposal> setSaveMoods(String id, List<String> moods) async {
    calls.add('moods:$id:${moods.join(",")}');
    return _proposal();
  }

  @override
  Future<bool> decideSave(String id,
      {required String choice, String? action, String? minimum, String? areaId, String? when, int? minutes, String? list, List<Map<String, String>>? actions}) async {
    calls.add('decide:$id:$choice${actions == null ? '' : ':${actions.first['action']}'}');
    return false;
  }

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

Future<void> _open(WidgetTester t, Widget page, {Size size = const Size(360, 800), double textScale = 1}) async {
  await _size(t, size: size, textScale: textScale);
  final key = GlobalKey<NavigatorState>();
  await t.pumpWidget(MaterialApp(navigatorKey: key, home: const Scaffold(body: SizedBox())));
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

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  tearDown(() => talkPrefill.value = null);

  group('words', () {
    test('notes say what they are', () {
      expect(noteTag(_notes()[0]), 'Home · List · 3 items, 1 ticked');
      expect(noteTag(_notes()[1]), 'Fitness · Rules · 2');
      expect(noteTag(_notes()[2]), 'Me · Free text');
    });
    test('people: last spoke and birthday, plainly', () {
      expect(personLine(_notes()[3], _now), 'Last spoke 8 days ago · Birthday 3 Feb');
      expect(personLine({'title': 'Ravi', 'items': ['Moved to Pune']}, _now), 'Moved to Pune');
      expect(dialable('98765 43210'), '+919876543210');
    });
  });

  testWidgets('notes, people and saved, one tap apart', (t) async {
    await _open(t, LibraryPage(repo: _Repo(), clock: () => _now));
    expect(find.text('Packing'), findsOneWidget);
    expect(find.text('Asha'), findsNothing);
    await _tap(t, find.text('People'));
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Last spoke 8 days ago · Birthday 3 Feb'), findsOneWidget);
    await _tap(t, find.text('Saved'));
    expect(find.text('WAITING FOR A DECISION'), findsOneWidget);
    expect(find.text('TO WATCH'), findsOneWidget);
    expect(find.text('FOR A LOW DAY'), findsOneWidget);
  });

  testWidgets('a list ticks; a note can be deleted with Undo', (t) async {
    final repo = _Repo();
    await _open(t, LibraryPage(repo: repo));
    await _tap(t, find.text('Packing'));
    expect(find.text('Passport'), findsOneWidget);
    await _tap(t, find.bySemanticsLabel('Tick Passport'));
    expect(repo.calls.last, 'tick:n1:Passport:true');
    await _tap(t, find.text('Delete'));
    expect(repo.calls.last, 'delete:n1');
    expect(find.text('Note deleted.'), findsOneWidget);
    await _tap(t, find.text('Undo'));
    expect(repo.calls.last, 'undo:act-del');
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('rules read in order; "Add to this note" opens Talk with words to finish', (t) async {
    await _open(t, LibraryPage(repo: _Repo()));
    await _tap(t, find.text('Eating out'));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('One sweet, slowly'), findsOneWidget);
    await _tap(t, find.text('Add to this note'));
    expect(talkPrefill.value, 'Add to my "Eating out" note: ');
  });

  testWidgets('a person: what they told you, and Call notes when you last spoke', (t) async {
    final repo = _Repo();
    String? opened;
    await _open(t, PersonPage(person: _notes()[3], repo: repo, clock: () => _now, open: (_, url) => opened = url));
    expect(find.text('THINGS THEY TOLD YOU'), findsOneWidget);
    expect(find.text('Started a new job in October'), findsOneWidget);
    await _tap(t, find.text('Call'));
    expect(opened, 'tel:+919876543210');
    expect(repo.calls, ['contacted:p1']);
    await _tap(t, find.text('WhatsApp'));
    expect(opened, 'https://wa.me/919876543210');
  });

  testWidgets('watched leaves the list', (t) async {
    final repo = _Repo();
    await _open(t, LibraryPage(repo: repo, start: LibrarySection.saved));
    await _tap(t, find.text('Watched'));
    expect(repo.calls, ['watched:s2']);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('offline with nothing loaded: says so, with Try again', (t) async {
    await _open(t, LibraryPage(repo: _Repo()..offline = true));
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('save a link', () {
    Future<void> openFlow(WidgetTester t, _Repo repo, SaveSource source) async {
      await _size(t);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => openSaveFlow(c, source, repo: repo), child: const Text('open'))))));
      await t.tap(find.text('open'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets('why first; "do something" shows one step; adding it decides the save', (t) async {
      final repo = _Repo();
      await openFlow(t, repo, const SaveSource(text: 'https://youtu.be/x'));
      expect(repo.calls, ['create:https://youtu.be/x']);
      expect(find.text('Why are you saving this?'), findsOneWidget);
      await _tap(t, find.text('To do something with it'));
      expect(find.text('ONE STEP FROM THIS'), findsOneWidget);
      expect(find.text('Solve 2 binary-search problems'), findsOneWidget);
      await _tap(t, find.text('Add this step'));
      expect(repo.calls.last, 'decide:s9:ACTION:Solve 2 binary-search problems');
      expect(find.text('Added: Solve 2 binary-search problems'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('watch later and a low day save in one tap', (t) async {
      final repo = _Repo();
      await openFlow(t, repo, const SaveSource(text: 'https://youtu.be/x'));
      await _tap(t, find.text('To watch later'));
      expect(repo.calls.last, 'decide:s9:LATER');
      await t.pump(const Duration(seconds: 5));

      await openFlow(t, repo, const SaveSource(existingId: 's9'));
      await _tap(t, find.text('For a day when I feel low'));
      expect(repo.calls.skip(repo.calls.length - 2), ['moods:s9:low', 'decide:s9:SHELF']);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('no clear step: keep it, said plainly', (t) async {
      final repo = _Repo()..noStep = true;
      await openFlow(t, repo, const SaveSource(text: 'just a funny reel'));
      await _tap(t, find.text('To do something with it'));
      expect(find.text('No clear step in this one.'), findsOneWidget);
      await _tap(t, find.text('Keep it to watch later'));
      expect(repo.calls.last, 'decide:s9:LATER');
      await t.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('each page fits a small phone at large text', (t) async {
    for (final page in [
      LibraryPage(repo: _Repo(), clock: () => _now),
      LibraryPage(repo: _Repo(), start: LibrarySection.people, clock: () => _now),
      LibraryPage(repo: _Repo(), start: LibrarySection.saved),
      NotePage(note: _notes()[0], repo: _Repo()),
      PersonPage(person: _notes()[3], repo: _Repo(), clock: () => _now),
    ]) {
      await _open(t, page, size: const Size(320, 640), textScale: 1.5);
      await t.drag(find.byType(ListView).first, const Offset(0, -1200));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });
}
