import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/models/user.dart';
import 'package:lifeos_mobile/data/repositories/auth_repository.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:lifeos_mobile/features/firstrun/first_run_data.dart';
import 'package:lifeos_mobile/features/firstrun/first_run_screen.dart';
import 'package:lifeos_mobile/features/firstrun/welcome_screen.dart';
import 'package:lifeos_mobile/features/session/focus_session_screen.dart';
import 'package:lifeos_mobile/features/talk/voice_input.dart';
import 'package:lifeos_mobile/features/you/you_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

// What a person might say, sorted the way the server would (generic sample).
Map<String, dynamic> _sorted({bool byCode = false}) => {
      'byCode': byCode,
      'items': [
        {'title': 'Get a new job', 'kind': 'GOAL', 'areaName': 'Career', 'due': '2027-02-01'},
        {'title': 'Lose some weight', 'kind': 'GOAL', 'areaName': 'Health', 'due': null},
        {'title': 'Pay the card bill', 'kind': 'TASK', 'areaName': 'Money', 'due': null},
        {'title': 'Learn guitar', 'kind': 'GOAL', 'areaName': 'Music', 'due': null},
      ],
      'areas': [
        {'name': 'Career', 'mode': 'PUSH', 'reason': 'It has a deadline, so it gets most of your effort now.'},
        {'name': 'Health', 'mode': 'PUSH', 'reason': 'A clear goal you want to move on now.'},
        {'name': 'Money', 'mode': 'MAINTAIN', 'reason': 'Kept steady with a small, regular dose.'},
        {'name': 'Music', 'mode': 'EXPLORE', 'reason': 'Try it before committing.'},
      ],
    };

class _Repo implements LifeRepository {
  final List<String> calls = [];
  bool failSort = false;
  bool noGoals = false;
  List<Map<String, dynamic>>? appliedAreas;
  List<Map<String, dynamic>>? appliedItems;

  @override
  Future<Map<String, dynamic>> firstRunSort(String text) async {
    calls.add('sort:$text');
    if (failSort) throw const ApiException('No connection');
    return _sorted();
  }

  @override
  Future<void> setDayBasics({required String wake, required String sleep, List<int> officeDays = const [], String? officeStart, String? officeEnd}) async =>
      calls.add('basics:$wake-$sleep:${officeDays.join(",")}:$officeStart-$officeEnd');

  @override
  Future<Map<String, dynamic>> areasOverview() async => {
        'areas': [],
        'capacity': {'neededMinutes': 0, 'freeMinutes': 780},
      };

  @override
  Future<Map<String, dynamic>> firstRunApply({required List<Map<String, dynamic>> areas, required List<Map<String, dynamic>> items}) async {
    appliedAreas = areas;
    appliedItems = items;
    calls.add('apply');
    return {
      'areas': [
        for (final (i, a) in areas.indexed) {'id': 'a$i', 'name': a['name'], 'mode': a['mode']},
      ],
      'goals': noGoals
          ? []
          : [
              {'id': 'g1', 'title': 'Get a new job', 'areaId': 'a0'},
            ],
      'activityId': 'act-apply',
    };
  }

  @override
  Future<Map<String, dynamic>> proposeGoalPlan(String text, {String? why, String? done, int? weeklyMinutes}) async {
    calls.add('propose:$text:$weeklyMinutes');
    return {
      'plan': {
        'title': 'Get a new job',
        'milestones': ['Resume and target list', 'Apply to 20 companies'],
        'steps': [
          {'title': 'List your three strongest projects', 'minutes': 15},
        ],
      },
    };
  }

  List<String>? keptMilestones;

  @override
  Future<Map<String, dynamic>> acceptGoalPlan(Map<String, dynamic> plan, {bool park = false, String? parkUntil, String? areaId}) async {
    calls.add('accept:$areaId');
    keptMilestones = (plan['milestones'] as List).cast<String>();
    return {
      'firstStep': {'id': 't1', 'title': 'List your three strongest projects', 'minutes': 15},
    };
  }

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action, {int? minutes, int? count, String? reason}) async {
    calls.add('done:$sourceId');
    return 'act-done';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Voice implements VoiceInput {
  @override
  Future<bool> dictate({required String locale, required void Function(String words) onWords, required void Function() onEnd}) async {
    onWords('call family more');
    return true;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String?> listenOnce({required String locale, required void Function(String partial) onPartial}) async => null;
}

const _saved = AppUser(id: 'u1', email: 'sam@example.com', name: 'Sam');

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
  await t.pump();
  await t.pump(const Duration(milliseconds: 700));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('draft rules', () {
    FirstRunDraft draft() => FirstRunDraft()..takeSort(_sorted());

    test('moving the last item out of an area removes the area; a new area appears', () {
      final d = draft();
      d.moveItem(d.items[3], 'Hobbies');
      expect(d.areas.map((a) => a.name), ['Career', 'Health', 'Money', 'Hobbies']);
    });
    test('renaming into an existing area merges them', () {
      final d = draft()..renameArea('Music', 'Money');
      expect(d.areas.map((a) => a.name), ['Career', 'Health', 'Money']);
      expect(d.items.where((i) => i.areaName == 'Money').length, 2);
    });
    test('time to start: push 3 h, others 1 h, rest none', () {
      expect(neededMinutes(draft().areas), 180 + 180 + 60 + 60);
    });
  });

  testWidgets('the whole first run: sort, fix, week, modes, plan, step one, save', (t) async {
    await _size(t);
    final repo = _Repo();
    AppUser? done;
    var opened = '';
    await t.pumpWidget(MaterialApp(
      home: FirstRunScreen(
        repo: repo,
        claim: ({required name, required email, required password}) async => _saved,
        onDone: (u) => done = u,
        voice: _Voice(),
        startFocus: (_, title, minutes, area) async {
          opened = '$title|$minutes|$area';
          return const FocusOutcome(FocusEnd.done, 15);
        },
      ),
    ));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('What do you want in your life right now?'), findsOneWidget);
    expect(t.widget<AllyButton>(find.widgetWithText(AllyButton, 'Sort it for me')).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'get a new job, lose some weight, pay the card bill, maybe guitar');
    await _tap(t, find.text('Speak instead'));
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, endsWith('call family more'));
    await _tap(t, find.text('Sort it for me'));
    expect(repo.calls.first, startsWith('sort:get a new job'));

    // Here's what I heard: move "Learn guitar" to a new area.
    expect(find.text("Here's what I heard"), findsOneWidget);
    expect(find.text('Get a new job'), findsOneWidget);
    await _tap(t, find.text('Learn guitar'));
    await t.enterText(find.widgetWithText(TextField, 'Or a new area'), 'Hobbies');
    await _tap(t, find.byTooltip('Move to the new area'));
    expect(find.text('Hobbies'), findsOneWidget);
    expect(find.text('Music'), findsNothing);
    await _tap(t, find.text('Continue'));

    // Your normal week.
    expect(find.text('Your normal week'), findsOneWidget);
    await _tap(t, find.text('10 to 7'));
    await _tap(t, find.text('This is my week'));
    expect(repo.calls.last, 'basics:07:00-23:00:1,2,3,4,5:10:00-19:00');
    expect(find.text('That leaves about 13 h a week that is yours.'), findsOneWidget);
    await _tap(t, find.text('Continue'));

    // Modes: making a third area Push moves the first Push down.
    expect(find.text('A mode for each area'), findsOneWidget);
    expect(find.text('About 8 h a week to start, of about 13 h free.'), findsOneWidget);
    await _tap(t, find.bySemanticsLabel(RegExp('^Money: Maintain')));
    await _tap(t, find.text('Push').last);
    await _tap(t, find.text('Set up my areas'));
    expect(repo.appliedAreas!.map((a) => '${a['name']}:${a['mode']}'), ['Career:MAINTAIN', 'Health:PUSH', 'Money:PUSH', 'Hobbies:EXPLORE']);
    expect(repo.appliedItems!.length, 4);

    // The draft plan for the first goal, and step one.
    await t.pump(const Duration(seconds: 1));
    expect(repo.calls, contains('propose:Get a new job:180'));
    expect(find.text('Career · draft 1'), findsOneWidget);
    expect(find.text('STEP ONE · 15 MIN'), findsOneWidget);
    // The milestones are editable before anything is kept.
    await t.enterText(find.widgetWithText(TextField, 'Apply to 20 companies'), 'Apply to 10 companies');
    await t.pump();
    await _tap(t, find.text('Start step one now'));
    expect(repo.keptMilestones, ['Resume and target list', 'Apply to 10 companies']);
    expect(opened, 'List your three strongest projects|15|Career');
    expect(repo.calls.skip(repo.calls.length - 2), ['accept:a0', 'done:t1']);

    // Save the account.
    expect(find.text('Save your plan'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Your name'), 'Sam');
    await t.enterText(find.widgetWithText(TextField, 'Email'), 'sam@example.com');
    await t.enterText(find.widgetWithText(TextField, 'Password'), 'longenough');
    await t.pump();
    await _tap(t, find.text('Save my account'));
    expect(done, _saved);
    expect((await SharedPreferences.getInstance()).getString('first_run_draft_v1'), isNull);
  });

  testWidgets('leaving midway: it opens where it was', (t) async {
    await _size(t);
    final d = FirstRunDraft(step: 1, text: 'job, gym')..takeSort(_sorted());
    await d.save();
    await t.pumpWidget(MaterialApp(home: FirstRunScreen(repo: _Repo(), claim: ({required name, required email, required password}) async => _saved, onDone: (_) {})));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text("Here's what I heard"), findsOneWidget);
    expect(find.text('Pay the card bill'), findsOneWidget);
  });

  testWidgets('no connection while sorting: says so, words kept', (t) async {
    await _size(t);
    await t.pumpWidget(MaterialApp(home: FirstRunScreen(repo: _Repo()..failSort = true, claim: ({required name, required email, required password}) async => _saved, onDone: (_) {})));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.enterText(find.byType(TextField), 'get a new job');
    await _tap(t, find.text('Sort it for me'));
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('What do you want in your life right now?'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'get a new job');
  });

  testWidgets('no goals to plan: says areas are set; Later skips saving', (t) async {
    await _size(t);
    final d = FirstRunDraft(step: 3, freeMinutes: 600)..takeSort(_sorted());
    await d.save();
    AppUser? done = _saved;
    var finished = false;
    await t.pumpWidget(MaterialApp(
        home: FirstRunScreen(
            repo: _Repo()..noGoals = true,
            claim: ({required name, required email, required password}) async => _saved,
            onDone: (u) {
              done = u;
              finished = true;
            })));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await _tap(t, find.text('Set up my areas'));
    expect(find.text('Your areas are set'), findsOneWidget);
    await _tap(t, find.text('Continue'));
    await _tap(t, find.text('Later'));
    expect(finished, isTrue);
    expect(done, isNull);
  });

  // "Here's what I heard", with one thing said and one idea of Ally's.
  Future<_Repo> heard(WidgetTester t, {Size size = const Size(360, 800), double textScale = 1}) async {
    await _size(t, size: size, textScale: textScale);
    SharedPreferences.setMockInitialValues({});
    final d = FirstRunDraft(step: 1, text: 'reduce my scrolling at night, call the bank tomorrow', freeMinutes: 780)
      ..takeSort({
        'byCode': false,
        'items': [
          {'title': 'Reduce scrolling', 'kind': 'GOAL', 'areaName': 'Health', 'origin': 'SAID', 'said': 'reduce my scrolling at night'},
          {
            'title': 'Draft a weekly schedule',
            'kind': 'TASK',
            'areaName': 'Health',
            'origin': 'IDEA',
            'ideaFor': 'reduce my scrolling at night',
            'reason': 'A plan for the evening leaves less room to scroll.',
          },
          {'title': 'Call the bank', 'kind': 'TASK', 'areaName': 'Money', 'origin': 'SAID', 'said': 'call the bank tomorrow', 'due': '2099-01-05', 'dueKind': 'ON'},
        ],
        'areas': [
          {'name': 'Health', 'mode': 'PUSH', 'reason': 'A clear goal you want to move on now.'},
          {'name': 'Money', 'mode': 'MAINTAIN', 'reason': 'Kept steady with a small, regular dose.'},
        ],
      });
    await d.save();
    final repo = _Repo();
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(MaterialApp(home: FirstRunScreen(repo: repo, claim: ({required name, required email, required password}) async => _saved, onDone: (_) {})));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    return repo;
  }

  Future<void> toModes(WidgetTester t) async {
    // The week is already set in this draft, so both steps are a Continue.
    await _tap(t, find.text('Continue'));
    await _tap(t, find.text('Continue'));
    await _tap(t, find.text('Set up my areas'));
  }

  testWidgets('each item says where it came from; an idea of Ally\'s says what for and why', (t) async {
    await heard(t);
    expect(find.text('From what you said: “reduce my scrolling at night”'), findsOneWidget);
    expect(find.text('Ally\'s idea for “reduce my scrolling at night”'), findsOneWidget);
    expect(find.text('A plan for the evening leaves less room to scroll.'), findsOneWidget);
    expect(find.text('Mon 5 Jan'), findsOneWidget);
    expect(find.textContaining("untick any of Ally's ideas"), findsOneWidget);
  });

  testWidgets('an idea comes ticked; unticking leaves it out of what is set up', (t) async {
    final repo = await heard(t);
    final tick = find.bySemanticsLabel("Keep Ally's idea: Draft a weekly schedule");
    expect(t.widget<AllyCheck>(find.byType(AllyCheck)).done, isTrue);
    await _tap(t, tick);
    expect(t.widget<AllyCheck>(find.byType(AllyCheck)).done, isFalse);
    await toModes(t);
    expect(repo.appliedItems!.map((i) => i['title']), ['Reduce scrolling', 'Call the bank']);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('an item can be renamed, given a when, and moved before anything is saved', (t) async {
    final repo = await heard(t);
    await _tap(t, find.text('Draft a weekly schedule'));
    expect(find.text('Edit'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Draft a weekly schedule'), 'Phone out of the bedroom');
    await t.pump();
    await _tap(t, find.widgetWithText(AllyChip, 'Evening'));
    await _tap(t, find.widgetWithText(AllyChip, 'Money'));
    await _tap(t, find.text('Done'));
    expect(find.text('Phone out of the bedroom'), findsOneWidget);
    expect(find.text('Evenings 6 to 9'), findsOneWidget);
    await toModes(t);
    final sent = repo.appliedItems!.firstWhere((i) => i['title'] == 'Phone out of the bedroom');
    expect(sent, {'title': 'Phone out of the bedroom', 'kind': 'TASK', 'areaName': 'Money', 'due': null, 'windowFrom': '18:00', 'windowTo': '21:00'});
    final bank = repo.appliedItems!.firstWhere((i) => i['title'] == 'Call the bank');
    expect(bank['dueKind'], 'ON');
    // Where it came from stays on the phone; it is not sent.
    expect(sent.containsKey('origin'), isFalse);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('the item sheet fits a small phone at large text', (t) async {
    await heard(t, size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
    await _tap(t, find.text('Call the bank'));
    await t.drag(find.byType(SingleChildScrollView).last, const Offset(0, -1200));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Remove'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('every step fits a small phone at large text', (t) async {
    await _size(t, size: const Size(320, 640), textScale: 1.5);
    for (final step in [0, 1, 2, 3, 5]) {
      SharedPreferences.setMockInitialValues({});
      final d = FirstRunDraft(step: step, text: 'job, gym', freeMinutes: 780)..takeSort(_sorted());
      await d.save();
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(MaterialApp(home: FirstRunScreen(repo: _Repo(), claim: ({required name, required email, required password}) async => _saved, onDone: (_) {})));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.drag(find.byType(ListView).first, const Offset(0, -1500));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull, reason: 'step $step');
    }
  });

  group('welcome and guests', () {
    testWidgets('Get started makes a guest account; sign in is one tap away', (t) async {
      await _size(t);
      final auth = _Auth();
      final bloc = AuthBloc(auth);
      await t.pumpWidget(BlocProvider.value(value: bloc, child: const MaterialApp(home: WelcomeScreen())));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Plan less. Do more.'), findsOneWidget);
      await _tap(t, find.text('Get started'));
      expect(auth.calls, ['guest']);
      expect(bloc.state.user!.guest, isTrue);

      await t.pumpWidget(const SizedBox());
      final bloc2 = AuthBloc(_Auth());
      await t.pumpWidget(BlocProvider.value(value: bloc2, child: const MaterialApp(home: WelcomeScreen())));
      await t.pump(const Duration(milliseconds: 500));
      await _tap(t, find.text('I already have an account'));
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('a guest sees "not saved yet", a way to save, and a warning before signing out', (t) async {
      await _size(t);
      const guest = AppUser(id: 'g1', email: 'guest-1@guest.ally.invalid', name: '', guest: true);
      await t.pumpWidget(MaterialApp(home: Scaffold(body: YouTab(user: guest, repo: _Repo(), claim: ({required name, required email, required password}) async => _saved))));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.text('NOT SAVED YET'), findsOneWidget);
      expect(find.textContaining('guest.ally'), findsNothing);
      expect(find.text('Save your plan'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Sign out'), 300);
      await _tap(t, find.text('Sign out'));
      expect(find.text('Save before signing out?'), findsOneWidget);
    });
  });
}

class _Auth implements AuthRepository {
  final List<String> calls = [];

  @override
  Future<AppUser> startGuest() async {
    calls.add('guest');
    return const AppUser(id: 'g1', email: 'guest-1@guest.ally.invalid', name: '', guest: true);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
