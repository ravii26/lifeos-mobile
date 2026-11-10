import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/di/service_locator.dart';
import 'package:lifeos_mobile/data/models/area.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/data/models/json.dart';
import 'package:lifeos_mobile/data/models/know.dart';
import 'package:lifeos_mobile/data/models/tonight.dart';
import 'package:lifeos_mobile/features/chat/goal_plan_card.dart';
import 'package:lifeos_mobile/features/guide/save_sheet.dart';
import 'package:lifeos_mobile/features/places/know_card.dart';
import 'package:lifeos_mobile/features/places/life_notes_screen.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/habits/habits_screen.dart';
import 'package:lifeos_mobile/features/places/week_screen.dart';
import 'package:lifeos_mobile/features/shrink/parked_screen.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/places/now_screen.dart';
import 'package:lifeos_mobile/features/places/plan_screen.dart';
import 'package:lifeos_mobile/features/places/support_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements LifeRepository {
  Map<String, dynamic> nowData = {'kind': 'REST', 'mode': 'SICK', 'message': 'Rest', 'options': <dynamic>[]};
  String? modeSet;
  bool saved = false;

  @override
  bool get showingSaved => saved;

  @override
  Future<KnowCardData> knowNext() async => const KnowCardData(
        question: KnowQuestion(id: 'q', text: 'When do you feel most awake?', why: 'So hard things land at the right time.', options: ['Morning', 'Late night'], allowText: true),
      );

  @override
  Future<SaveProposal> createSave(String text) async => const SaveProposal(
        id: 's',
        platform: 'YouTube',
        contentTitle: 'Dynamic programming in 12 minutes',
        kind: 'LEARN',
        action: 'Solve one DP problem',
        minimum: 'Read one problem',
        when: 'THIS_WEEK',
        reason: 'It fits your goal.',
      );

  @override
  Future<List<Area>> areas() async => const [];

  @override
  Future<List<Json>> parked() async => [
        {'activityId': 'e1', 'title': 'Learn guitar', 'untilLabel': 'January'},
      ];

  @override
  Future<void> undo(String activityId) async => undone.add(activityId);
  final undone = <String>[];

  @override
  Future<Json> weekCheck() async => {
        'daysActive': 4,
        'done': 11,
        'minimums': 3,
        'minutes': 360,
        'habits': [
          {'title': 'Gym', 'days': 3},
        ],
        'moved': <dynamic>[],
        'topArea': 'Work',
        'quietArea': 'Friends',
      };

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async => nowData;

  @override
  Future<void> setMode(String m) async {
    modeSet = m;
    nowData = {'kind': 'EMPTY', 'mode': 'NORMAL', 'message': '', 'options': <dynamic>[]};
  }

  @override
  Future<Map<String, dynamic>> plan() async => {
        'today': {
          'blocks': [
            {
              'block': 'EVENING',
              'items': [
                {'id': 'a', 'type': 'TASK', 'title': 'One DSA problem', 'minutes': 30},
                {'id': 'b', 'type': 'TASK', 'title': 'Call Mummy', 'minutes': 10},
              ],
            },
          ],
        },
        'thisWeek': {'days': <dynamic>[], 'carried': <dynamic>[]},
        'habits': <dynamic>[],
        'projects': {'office': <dynamic>[], 'personal': <dynamic>[]},
        'later': {'count': 0},
        'suggested': <dynamic>[],
      };

  @override
  Future<Map<String, dynamic>> staleTodos() async => {'total': 0, 'items': <dynamic>[]};

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({'ally_started': true});
    getIt.registerSingleton<LifeRepository>(_Repo());
  });
  tearDown(() => getIt.unregister<LifeRepository>());

  void small(WidgetTester t) {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  test('plan summary reads naturally', () {
    expect(planSummary(0, 0), 'Nothing left for today.');
    expect(planSummary(1, 0), '1 thing.');
    expect(planSummary(3, 30), '3 things. About 30 minutes.');
    expect(planSummary(3, 60), '3 things. About an hour.');
    expect(planSummary(4, 150), '4 things. About 2.5 hours.');
  });

  test('habit progress never mentions a streak', () {
    expect(habitWeekLine(const []), 'Just started');
    expect(habitWeekLine(const [true, false, true]), '2 of the last 3 days');
    expect(habitWeekLine(List.filled(10, true)), '7 of the last 7 days');
  });

  test('any reply with the helpline counts as a crisis reply', () {
    expect(isCrisisReply('Please call Tele-MANAS at 14416.'), isTrue);
    expect(isCrisisReply('Sounds like a long day.'), isFalse);
  });

  testWidgets('support screen fits a small phone and shows both numbers', (t) async {
    small(t);
    await t.pumpWidget(const MaterialApp(home: SupportScreen()));
    expect(t.takeException(), isNull);
    expect(find.text('Call Tele-MANAS 14416'), findsOneWidget);
    expect(find.text('In immediate danger: call 112'), findsOneWidget);
  });

  testWidgets('sick mode shows the easy day, and feeling better leaves it', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = _Repo();
    final cubit = NowCubit(repo);
    await cubit.load();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: BlocProvider.value(value: cubit, child: const NowScreen()))));
    await t.pump();
    expect(find.text('Just take care of yourself.'), findsOneWidget);
    expect(find.text('Plan a goal'), findsNothing);
    await t.tap(find.text("I'm feeling better"));
    await t.pump();
    await t.pump();
    expect(repo.modeSet, 'NORMAL');
    expect(find.text('Just take care of yourself.'), findsNothing);
    await cubit.close();
  });

  test('each life page shows only its own notes', () {
    final shopping = {'template': 'LIST', 'collection': 'Lists'};
    final mummy = {'template': 'LIST', 'collection': 'People'};
    final diet = {'template': 'INFO', 'collection': 'Diet'};
    final routine = {'template': 'ROUTINE', 'collection': 'Routines'};
    expect(belongsOn(LifeNotes.lists, shopping), isTrue);
    expect(belongsOn(LifeNotes.lists, mummy), isFalse);
    expect(belongsOn(LifeNotes.lists, routine), isFalse);
    expect(belongsOn(LifeNotes.people, mummy), isTrue);
    expect(belongsOn(LifeNotes.meals, diet), isTrue);
  });

  test('an AI-down reply is remembered as one', () {
    expect(ChatReply.fromJson({'reply': 'x', 'aiDown': true}).aiDown, isTrue);
    expect(ChatReply.fromJson({'reply': 'x', 'usedAi': false}).aiDown, isFalse);
    expect(ChatMessage.fromJson(const ChatMessage(fromUser: false, text: 'x', aiDown: true).toJson()).aiDown, isTrue);
  });

  test('week wording never scores', () {
    expect(weekHeadline(0), 'A fresh week starts whenever you do.');
    expect(weekHeadline(1), 'You showed up 1 day.');
    expect(weekHeadline(4), 'You showed up 4 days.');
    expect(timeShort(45), '45 min');
    expect(timeShort(120), '2 h');
    expect(timeShort(90), '1.5 h');
  });

  testWidgets('the week check names the quiet area and fits a small phone', (t) async {
    small(t);
    await t.pumpWidget(const MaterialApp(home: WeekScreen()));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('You showed up 4 days.'), findsOneWidget);
    expect(find.text('Nothing from Friends in two weeks. Want to change that?'), findsOneWidget);
  });

  testWidgets('parked things can be brought back', (t) async {
    small(t);
    final repo = getIt<LifeRepository>() as _Repo;
    await t.pumpWidget(const MaterialApp(home: ParkedScreen()));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Comes back in January'), findsOneWidget);
    await t.tap(find.text('Bring back'));
    await t.pump();
    await t.pump();
    expect(repo.undone, ['e1']);
  });

  testWidgets('with no connection Now says so once', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final repo = getIt<LifeRepository>() as _Repo;
    repo.saved = true;
    repo.nowData = {
      'kind': 'PICK',
      'message': '',
      'options': [
        {'sourceType': 'TASK', 'sourceId': 't', 'title': 'One DSA problem', 'minutes': 30, 'minimum': '', 'why': ''},
      ],
    };
    final cubit = NowCubit(repo);
    await cubit.load();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: BlocProvider.value(value: cubit, child: const NowScreen()))));
    await t.pump();
    expect(find.textContaining("Can't reach the internet"), findsOneWidget);
    await cubit.close();
  });

  testWidgets('the goal plan and quick question fit a narrow phone', (t) async {
    t.view.physicalSize = const Size(360, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [
          GoalPlanCard(proposal: {
            'plan': {
              'title': 'Crack DSA by March',
              'targets': [
                {'title': 'DSA practice with a rather long name to wrap', 'unit': 'minutes', 'perWeek': 180},
              ],
            },
            'caution': {'message': 'You already have two big goals.'},
          }),
          const KnowCard(),
        ]),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Start anyway'), findsOneWidget);
    expect(find.text('Park it'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
  });

  testWidgets('the save sheet fits a small phone and offers the design choices', (t) async {
    small(t);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(onPressed: () => openSaveSheet(c, const SaveSource(text: 'x')), child: const Text('open')),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(find.text('Dynamic programming in 12 minutes'), findsOneWidget);
    final sheet = find.byType(Scrollable).first; // the sheet itself; later ones are inside its text fields
    await t.scrollUntilVisible(find.text('Add to my plan'), 200, scrollable: sheet);
    await t.scrollUntilVisible(find.text("Don't need it"), 200, scrollable: sheet);
    expect(find.text('Watch later'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('plan lists every item today, with the next one first', (t) async {
    small(t);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: PlanScreen())));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('2 things. About 40 minutes.'), findsOneWidget);
    expect(find.text('One DSA problem'), findsOneWidget);
    expect(find.text('Call Mummy'), findsOneWidget);
  });
}
