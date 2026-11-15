import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/design/components.dart';
import 'package:lifeos_mobile/features/chat/chat_cubit.dart';
import 'package:lifeos_mobile/features/chat/starters.dart';
import 'package:lifeos_mobile/features/talk/talk_screen.dart';
import 'package:lifeos_mobile/features/talk/voice_input.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ally's reply to "remind me to call the dentist and add milk": two things saved.
const _filed = ChatMessage(fromUser: false, text: 'Done. Two things saved.', actions: [
  ChatAction(type: 'TASK_ADDED', id: 't1', text: 'Call the dentist', activityId: 'a1'),
  ChatAction(type: 'NOTE_ADDED', id: 'n1', text: 'Shopping', items: ['milk'], activityId: 'a2'),
]);

class _Chat extends Cubit<ChatState> implements ChatCubit {
  final List<String> calls = [];
  _Chat([List<ChatMessage> messages = const []]) : super(ChatState(messages: messages));

  @override
  Future<String?> send(String text, {bool spoken = false}) async {
    calls.add('send:$text');
    emit(state.copyWith(messages: [...state.messages, ChatMessage(fromUser: true, text: text), _filed]));
    return _filed.text;
  }

  @override
  Future<void> undoAction(int messageIndex, int actionIndex) async {
    calls.add('undo:$messageIndex:$actionIndex');
    final m = state.messages[messageIndex];
    final actions = [...m.actions]..[actionIndex] = m.actions[actionIndex].markUndone();
    emit(state.copyWith(messages: [...state.messages]..[messageIndex] = m.copyWith(actions: actions)));
  }

  @override
  Future<void> undoAll(int messageIndex) async => calls.add('undoAll:$messageIndex');

  @override
  Future<void> clear() async => emit(const ChatState());

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Voice implements VoiceInput {
  void Function(String)? words;
  void Function()? end;
  String? locale;
  bool available = true;

  @override
  Future<bool> dictate({required String locale, required void Function(String words) onWords, required void Function() onEnd}) async {
    if (!available) return false;
    this.locale = locale;
    words = onWords;
    end = onEnd;
    return true;
  }

  @override
  Future<void> stop() async => end?.call();

  @override
  Future<void> cancel() async {}

  @override
  Future<String?> listenOnce({required String locale, required void Function(String partial) onPartial}) async => null;
}

Future<void> _open(WidgetTester t, _Chat chat, {_Voice? voice, Size size = const Size(360, 800), double textScale = 1, VoidCallback? onClose}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearAllTestValues);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BlocProvider<ChatCubit>.value(value: chat, child: TalkScreen(onClose: onClose ?? () {}, voice: voice ?? _Voice())),
    ),
  ));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty: an invitation and things to say, one tap away', (t) async {
    final chat = _Chat();
    await _open(t, chat);
    expect(find.textContaining('Tell me anything'), findsOneWidget);
    expect(find.text('What should I do now?'), findsOneWidget);
    await _tap(t, find.text('What should I do now?'));
    expect(chat.calls, ['send:What should I do now?']);
  });

  testWidgets('what Ally did shows as receipts, each with Undo, and Undo all', (t) async {
    final chat = _Chat();
    await _open(t, chat);
    await t.enterText(find.byType(TextField), 'remind me to call the dentist and add milk');
    await t.pump();
    await _tap(t, find.byTooltip('Send'));
    expect(chat.calls.single, 'send:remind me to call the dentist and add milk');
    expect(find.text('remind me to call the dentist and add milk'), findsOneWidget);
    expect(find.text('Saved 2 things'), findsOneWidget);
    expect(find.text('To-do: Call the dentist'), findsOneWidget);
    expect(find.text('Note Shopping: milk'), findsOneWidget);
    await _tap(t, find.text('Undo all'));
    expect(chat.calls.last, 'undoAll:1');
    await _tap(t, find.byWidgetPredicate((w) => w is AllyButton && w.semanticLabel == 'Undo: To-do: Call the dentist'));
    expect(chat.calls.last, 'undo:1:0');
    expect(find.text('Undone'), findsOneWidget);
    // One thing left: "Undo all" is no longer offered.
    expect(find.text('Undo all'), findsNothing);
  });

  testWidgets('speaking fills the box to fix before sending; the language is remembered', (t) async {
    final voice = _Voice();
    await _open(t, _Chat(), voice: voice);
    await _tap(t, find.byTooltip('Speak'));
    expect(find.text('Listening…'), findsOneWidget);
    expect(voice.locale, 'en_IN');
    voice.words!('kal subah gym');
    await t.pump();
    await _tap(t, find.text('हिन्दी'));
    expect(voice.locale, 'hi_IN');
    expect((await SharedPreferences.getInstance()).getString('talk_voice_lang'), 'hindi');
    voice.words!('दूध लाना');
    await t.pump();
    await _tap(t, find.text('Stop'));
    expect(find.text('Listening…'), findsNothing);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'kal subah gym दूध लाना');
  });

  testWidgets('no speech on the phone: says typing works', (t) async {
    await _open(t, _Chat(), voice: _Voice()..available = false);
    await _tap(t, find.byTooltip('Speak'));
    expect(find.textContaining('Typing works'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('a crisis reply offers a real person first', (t) async {
    await _open(t, _Chat(const [ChatMessage(fromUser: false, text: 'You matter. You can call Tele-MANAS on 14416, any time.')]));
    expect(find.text('Call 14416'), findsOneWidget);
    expect(find.text('More help'), findsOneWidget);
  });

  testWidgets('words from elsewhere and older starters land in the box', (t) async {
    await _open(t, _Chat());
    talkPrefill.value = 'Add to my "Packing" note: ';
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'Add to my "Packing" note: ');
    starterRequest.value = Starter.reminder;
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'Remind me to ');
  });

  testWidgets('Close leaves Talk', (t) async {
    var closed = false;
    await _open(t, _Chat(), onClose: () => closed = true);
    await _tap(t, find.text('Close'));
    expect(closed, isTrue);
  });

  testWidgets('fits a small phone at large text, while listening too', (t) async {
    final chat = _Chat([const ChatMessage(fromUser: true, text: 'remind me to call the dentist and add milk'), _filed]);
    await _open(t, chat, size: const Size(320, 640), textScale: 1.5);
    expect(t.takeException(), isNull);
    await _tap(t, find.byTooltip('Speak'));
    expect(t.takeException(), isNull);
  });
}
