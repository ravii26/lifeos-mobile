import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';
import 'package:lifeos_mobile/features/places/now_life_lines.dart';

class _FakeRepo implements LifeRepository {
  @override
  bool get showingSaved => false;

  final List<String> calls = [];
  Map<String, dynamic> next = {};

  @override
  Future<Map<String, dynamic>?> nowSaved({bool smallest = false}) async => null;
  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async {
    calls.add('now');
    return next;
  }

  @override
  Future<Map<String, dynamic>> addCount(String habitId, {int n = 1}) async {
    calls.add('count($habitId,$n)');
    return {'line': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> tickNote(String id, String item, bool done) async {
    calls.add('tick($id,$item,$done)');
    return {};
  }

  @override
  Future<ChatReply> chat(String message, List<ChatMessage> history, {bool spoken = false}) async {
    calls.add('chat($message)');
    return const ChatReply('Stopped.', [], 'ASSISTANT');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _data() => {
      'kind': 'EMPTY',
      'message': 'Nothing waiting.',
      'options': <dynamic>[],
      'prep': <dynamic>[],
      'counts': [
        {'id': 'h1', 'title': 'Water', 'count': 3, 'target': 8}
      ],
      'timer': {'label': 'dsa', 'minutes': 25, 'forgotten': false},
      'routine': {
        'id': 'n1',
        'title': 'Gym routine',
        'steps': [
          {'text': 'Bench press', 'done': true},
          {'text': 'Squats', 'done': false},
        ],
      },
      'meal': {'meal': 'dinner', 'text': 'roti sabzi', 'tomorrow': false},
      'watchLater': {'id': 's1', 'title': 'Atomic Habits summary', 'url': null, 'line': 'You have time. Watch later: Atomic Habits summary (18 min)?'},
    };

void main() {
  testWidgets('shows the lines and answers +1, a routine step and Stop', (tester) async {
    final repo = _FakeRepo()..next = _data();
    final cubit = NowCubit(repo);
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BlocProvider.value(
            value: cubit,
            child: BlocBuilder<NowCubit, NowState>(builder: (_, s) => NowLifeLines(extras: s.extras, busy: s.busy)),
          ),
        ),
      ),
    ));

    expect(find.text('Water: 3 of 8'), findsOneWidget);
    expect(find.text('dsa · 25 min'), findsOneWidget);
    expect(find.text('Gym routine'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
    expect(find.text('Next meal: dinner'), findsOneWidget);
    expect(find.textContaining('You have time. Watch later'), findsOneWidget);

    await tester.tap(find.byTooltip('+1 Water'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(repo.calls, containsAllInOrder(['count(h1,1)', 'tick(n1,Squats,true)', 'chat(stop timer)']));
    // Each answer reloads Now, so the lines follow what the server says.
    expect(repo.calls.where((c) => c == 'now').length, greaterThanOrEqualTo(4));
  });
}
