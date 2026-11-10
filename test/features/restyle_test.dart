import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/core/di/service_locator.dart';
import 'package:lifeos_mobile/data/models/area.dart';
import 'package:lifeos_mobile/data/models/capture.dart';
import 'package:lifeos_mobile/data/models/habit.dart';
import 'package:lifeos_mobile/data/models/task.dart';
import 'package:lifeos_mobile/data/models/vault_item.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/areas/area_detail_screen.dart';
import 'package:lifeos_mobile/features/areas/areas_screen.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/features/capture/capture_sheet.dart';
import 'package:lifeos_mobile/features/chat/chat_screen.dart' show AiLimitCard;
import 'package:lifeos_mobile/features/places/life_notes_screen.dart';
import 'package:lifeos_mobile/features/places/note_cards.dart';
import 'package:lifeos_mobile/features/focus/focus_screen.dart';
import 'package:lifeos_mobile/features/habits/habit_detail_screen.dart';
import 'package:lifeos_mobile/features/more/settings_screen.dart';
import 'package:lifeos_mobile/features/more/taught_notes_screen.dart';
import 'package:lifeos_mobile/features/more/your_day_screen.dart';
import 'package:lifeos_mobile/features/onboarding/first_run_screen.dart';
import 'package:lifeos_mobile/features/shell/life_cubit.dart';
import 'package:lifeos_mobile/features/tasks/task_detail_screen.dart';
import 'package:lifeos_mobile/features/tasks/tasks_screen.dart';
import 'package:lifeos_mobile/features/vault/vault_screen.dart';

class _Repo implements LifeRepository {
  @override
  Future<void> recordBehavior(String type, {Map<String, dynamic>? metadata}) async {}

  @override
  Future<String> mode() async => 'NORMAL';

  @override
  Future<List<Map<String, dynamic>>> daySchedule() async => [
        for (var d = 0; d < 7; d++)
          {
            'weekday': d,
            'custom': d == 1,
            'blocks': [
              {'block': 'OFFICE', 'start': '10:00', 'end': '19:00', 'freeMinutes': 90},
            ],
          },
      ];

  @override
  Future<List<VaultItem>> vault({String? vaultType}) async => [
        VaultItem.fromJson(const {'id': 'v', 'title': 'The day I shipped it', 'content': 'You did the hard thing once already.', 'vaultType': 'MEMORY', 'triggerTags': ['tired'], 'usedCount': 2, 'helpfulCount': 1}),
      ];

  @override
  Future<List<Map<String, dynamic>>> allyNotes() async => [
        {
          'id': 'n',
          'collection': 'Diet',
          'title': 'Breakfasts',
          'template': 'LIST',
          'items': ['Poha', 'Oats'],
        },
        {
          'id': 'p',
          'collection': 'People',
          'title': 'Rahul',
          'template': 'INFO',
          'items': <String>[],
          'meta': {'phone': '9876543210', 'lastContact': DateTime.now().subtract(const Duration(days: 22)).toIso8601String()},
        },
      ];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Cubit extends LifeCubit {
  _Cubit(LifeState s) : super(_Repo()) {
    emit(s);
  }
}

final _area = Area.fromJson(const {'id': 'a', 'name': 'Health and everything that goes with it', 'score': 0.4, 'tasksDone': 2, 'tasksTotal': 7, 'streak': 9, 'focusMins': 40});

Task _task() => Task.fromJson({
      'id': 't',
      'title': 'Book the blood test and carry the old reports along',
      'priority': 'HIGH',
      'areaId': 'a',
      'dueDate': DateTime.now().toIso8601String(),
      'description': 'Fasting, so go early.',
    });

Habit _habit(String id, String type) => Habit.fromJson({
      'id': id,
      'title': 'Walk after dinner',
      'habitType': type,
      'targetCount': 8,
      'targetMinutes': 30,
      'areaId': 'a',
      'currentStreak': 12,
      'longestStreak': 30,
      'history': const [true, false, true],
    });

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => getIt.registerSingleton<LifeRepository>(_Repo()));
  tearDown(() => getIt.unregister<LifeRepository>());

  final state = LifeState(
    areas: [_area],
    tasks: [_task()],
    habits: [_habit('b', 'BOOLEAN'), _habit('c', 'COUNT'), _habit('m', 'TIMER')],
    captures: [
      Capture.fromJson(const {'id': 'x', 'text': 'Call the bank about the card', 'type': 'TASK', 'processed': false, 'status': 'PENDING', 'confidence': 0.9}),
    ],
  );

  Future<void> show(WidgetTester t, Widget page) async {
    // Narrow like a small phone, tall so a long page is fully built and checked.
    t.view.physicalSize = const Size(360, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final cubit = _Cubit(state);
    addTearDown(cubit.close);
    await t.pumpWidget(MaterialApp(home: BlocProvider<LifeCubit>.value(value: cubit, child: page)));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.textContaining(RegExp('streak|continuity|consistency', caseSensitive: false)), findsNothing);
    expect(find.textContaining(RegExp(r'\d%')), findsNothing);
  }

  test('a part of life is described without a score', () {
    expect(areaLine(0, 0, 0), 'No to-dos yet.');
    expect(areaLine(2, 7, 0), '2 of 7 to-dos done.');
    expect(areaLine(2, 7, 40), '2 of 7 to-dos done. 40 min focused.');
  });

  testWidgets('parts of my life', (t) async {
    await show(t, const AreasScreen());
    expect(find.text('Parts of my life'), findsOneWidget);
  });

  testWidgets('one part of life', (t) async => show(t, const AreaDetailScreen(areaId: 'a')));

  testWidgets('all to-dos count today and later separately', (t) async {
    await show(t, const TasksScreen());
    expect(find.text('1 for today, 0 for later.'), findsOneWidget);
    await t.tap(find.byTooltip('Add a to-do'));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('High'), findsWidgets);
  });

  testWidgets('task detail', (t) async {
    await show(t, const TaskDetailScreen(taskId: 't'));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Mark done'), findsOneWidget);
  });

  for (final kind in const ['b', 'c', 'm']) {
    testWidgets('habit detail ($kind)', (t) async {
      await show(t, HabitDetailScreen(habitId: kind));
      expect(find.text('2 of the last 3 days'), findsOneWidget);
    });
  }

  testWidgets('vault', (t) async {
    await show(t, const VaultScreen());
    expect(find.text('The day I shipped it'), findsOneWidget);
  });

  testWidgets('taught notes', (t) async {
    await show(t, const TaughtNotesScreen());
    expect(find.text('Breakfasts'), findsOneWidget);
  });

  testWidgets('my day', (t) async {
    await show(t, const YourDayScreen());
    expect(find.text('You told Ally this'), findsOneWidget);
    expect(find.text('1 h 30 min free'), findsWidgets);
  });

  testWidgets('first run', (t) async {
    await show(t, const FirstRunScreen());
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('focus', (t) async {
    await show(t, const FocusScreen());
    expect(find.text('Just focus'), findsOneWidget);
  });

  testWidgets('quick capture shows what is waiting', (t) async {
    await show(t, const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: CaptureSheet())));
    expect(find.text('Goes to To-dos. Change'), findsOneWidget);
  });

  testWidgets('delete stays locked until DELETE is typed', (t) async {
    var popped = false;
    await show(t, DeleteAccountScreen(onDownload: () => popped = true));
    await t.tap(find.text('Delete forever'));
    await t.pump();
    expect(find.text('Delete forever'), findsOneWidget);
    await t.tap(find.text('Download my data first'));
    expect(popped, isTrue);
    final button = find.ancestor(of: find.text('Delete forever'), matching: find.byType(OutlinedButton));
    expect(t.widget<OutlinedButton>(button).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'DELETE');
    await t.pump();
    expect(t.widget<OutlinedButton>(button).onPressed, isNotNull);
  });

  test('people: how long ago, and who has gone quiet', () {
    final now = DateTime(2026, 11, 11, 10);
    expect(agoText(DateTime(2026, 11, 11, 8), now), 'today');
    expect(agoText(DateTime(2026, 11, 10, 23), now), 'yesterday');
    expect(agoText(DateTime(2026, 11, 6), now), '5 days ago');
    expect(agoText(DateTime(2026, 10, 20), now), '3 weeks ago');
    expect(agoText(DateTime(2026, 8, 1), now), '3 months ago');
    Map<String, dynamic> person(String name, DateTime? last) => {'title': name, if (last != null) 'meta': {'lastContact': last.toIso8601String()}};
    final people = [person('Amit', DateTime(2026, 11, 10)), person('Rahul', DateTime(2026, 10, 1)), person('Priya', DateTime(2026, 10, 15)), person('New', null)];
    expect(quietPerson(people, now)?['title'], 'Rahul');
    expect(quietPerson([person('Amit', DateTime(2026, 11, 1))], now), isNull);
    expect(quietPerson([person('New', null)], now), isNull);
  });

  testWidgets('people shows who it has been a while with', (t) async {
    await show(t, const LifeNotesScreen(page: LifeNotes.people));
    expect(find.text("It's been a while"), findsOneWidget);
    expect(find.text('You last spoke 3 weeks ago.'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('the daily limit card fits and says what still works', (t) async {
    await show(t, const Scaffold(body: AiLimitCard()));
    expect(find.text("That's today's free chats."), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
  });

  test('a reply over the daily limit is remembered as one', () {
    expect(ChatReply.fromJson({'reply': 'x', 'aiLimit': true}).aiLimit, isTrue);
    expect(ChatMessage.fromJson(const ChatMessage(fromUser: false, text: 'x', aiLimit: true).toJson()).aiLimit, isTrue);
    expect(ChatMessage.fromJson(const ChatMessage(fromUser: false, text: 'x').toJson()).aiLimit, isFalse);
  });
}
