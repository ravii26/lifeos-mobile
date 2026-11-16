import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/features/chat/chat_cubit.dart';
import 'package:lifeos_mobile/features/talk/talk_screen.dart';
import 'package:lifeos_mobile/features/talk/voice_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _msgs = [
  ChatMessage(fromUser: true, text: 'I want to read every night, and call the bank tomorrow'),
  ChatMessage(fromUser: false, text: 'Done.', actions: [
    ChatAction(type: 'TASK_ADDED', id: 't1', text: 'Call the bank', activityId: 'a1', origin: 'SAID', said: 'call the bank tomorrow'),
    ChatAction(type: 'TASK_ADDED', id: 't2', text: 'Put the book on the pillow', activityId: 'a2', origin: 'IDEA', ideaFor: 'read every night', reason: 'Makes starting easier'),
    ChatAction(type: 'HABIT_ADDED', id: 'h1', text: 'Read', activityId: 'a3', origin: 'SAID', said: 'I want to read every night'),
    ChatAction(type: 'REMEMBERED', id: 'm1', text: 'Likes quiet', activityId: 'a4'),
  ]),
];

class _Chat extends Cubit<ChatState> implements ChatCubit {
  final List<String> calls = [];
  _Chat() : super(const ChatState(messages: _msgs));

  @override
  Future<void> rename(int messageIndex, int actionIndex, String title) async => calls.add('rename:$messageIndex:$actionIndex:$title');

  @override
  Future<void> undoAction(int messageIndex, int actionIndex) async => calls.add('undo:$messageIndex:$actionIndex');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Voice implements VoiceInput {
  @override
  Future<bool> dictate({required String locale, required void Function(String words) onWords, required void Function() onEnd}) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String?> listenOnce({required String locale, required void Function(String partial) onPartial}) async => null;
}

Future<_Chat> _open(WidgetTester t, {Size size = const Size(360, 800), double scale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  final chat = _Chat();
  await t.pumpWidget(MaterialApp(
    home: Scaffold(body: BlocProvider<ChatCubit>.value(value: chat, child: TalkScreen(onClose: () {}, voice: _Voice()))),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  return chat;
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('each saved thing says where it came from; Ally\'s ideas say what for and why', (t) async {
    await _open(t);
    expect(find.text('From what you said: “call the bank tomorrow”'), findsOneWidget);
    expect(find.text('From what you said: “I want to read every night”'), findsOneWidget);
    expect(find.text('Ally’s idea for “read every night”: Makes starting easier'), findsOneWidget);
    // A memory has no source line, and no edit button.
    expect(find.byTooltip('Edit: Remembered: Likes quiet'), findsNothing);
    expect(find.byTooltip('Edit: To-do: Call the bank'), findsOneWidget);
  });

  testWidgets('a routine can be renamed from its receipt', (t) async {
    final chat = await _open(t);
    await _tap(t, find.byTooltip('Edit: Habit: Read'));
    expect(find.text('Edit routine'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Read'), 'Read 10 pages');
    await t.pump();
    await _tap(t, find.text('Save'));
    expect(chat.calls, ['rename:1:2:Read 10 pages']);
  });

  testWidgets('"Undo this routine" in the edit sheet undoes it', (t) async {
    final chat = await _open(t);
    await _tap(t, find.byTooltip('Edit: Habit: Read'));
    await _tap(t, find.text('Undo this routine'));
    expect(chat.calls.last, 'undo:1:2');
  });

  testWidgets('a to-do receipt opens the step sheet', (t) async {
    await _open(t);
    await _tap(t, find.byTooltip('Edit: To-do: Call the bank'));
    expect(find.text('Edit step'), findsOneWidget);
    expect(find.text('Call the bank'), findsWidgets);
  });

  testWidgets('fits a small phone at large text', (t) async {
    await _open(t, size: const Size(320, 640), scale: 1.5);
    expect(t.takeException(), isNull);
    await _tap(t, find.byTooltip('Edit: To-do: Put the book on the pillow'));
    expect(t.takeException(), isNull);
  });
}
