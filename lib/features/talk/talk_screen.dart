import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/links/open_link.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/system/system_settings.dart';
import '../../core/voice/voice_service.dart';
import '../../data/models/chat.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../chat/chat_cubit.dart';
import '../chat/chat_screen.dart' show ChatListCard;
import '../chat/chat_words.dart';
import '../chat/goal_plan_card.dart';
import '../chat/starters.dart';
import '../chat/talk_controller.dart';
import '../guide/tonight_cubit.dart';
import '../library/save_flow.dart';
import '../places/now_cubit.dart';
import '../places/support_screen.dart';
import 'voice_input.dart';

/// Words for Talk to start with, set from anywhere (a note's "Add to this
/// note", an older screen's starter). The shell opens Talk when it changes.
final ValueNotifier<String?> talkPrefill = ValueNotifier<String?>(null);

/// What a starter asks for, as the start of a sentence to finish.
String starterWords(Starter s) => switch (s) {
      Starter.goal => 'Help me plan a goal: ',
      Starter.reminder => 'Remind me to ',
      Starter.habit => 'I want a daily habit: ',
      Starter.video => 'Turn this video into a step: ',
      Starter.teach => 'Remember this: ',
    };

/// Generic things to say, one tap away.
const talkExamples = [
  'What should I do now?',
  'Remind me tomorrow at 7 to go for a walk',
  'Kal subah 7 baje gym yaad dilana',
  'Read 10 pages every night',
  'How was my week?',
  'Office till 9 today',
];

/// Talk, from + in the bottom bar: type or speak, Ally answers and files
/// things as it goes, each with Undo. Speaking fills the box first, so the
/// words can be fixed before sending. Hands-free talk is one tap away.
class TalkScreen extends StatefulWidget {
  final VoidCallback onClose;

  /// For tests: the phone's speech recogniser by default.
  final VoiceInput? voice;
  const TalkScreen({super.key, required this.onClose, this.voice});

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  late final VoiceInput _voice = widget.voice ?? PhoneVoiceInput();
  VoiceLang _lang = VoiceLang.english;
  bool _listening = false;
  String _dictBase = '';

  // Made on first use, so the speaker is only touched when hands-free starts.
  TalkController? _hf;
  bool get _handsFreeOn => _hf?.active ?? false;

  TalkController _makeHandsFree() => TalkController(
    listenOnce: (onPartial) => _voice.listenOnce(locale: _lang.locale, onPartial: onPartial),
    cancelListening: _voice.cancel,
    ask: (said) => context.read<ChatCubit>().send(said, spoken: true),
    speak: (text) async {
      await VoiceService.instance.speak(text);
      // A short pause so the microphone does not catch the end of Ally's own voice.
      await Future<void>.delayed(const Duration(milliseconds: 450));
    },
    stopSpeaking: VoiceService.instance.stop,
  )..addListener(_onHandsFree);

  @override
  void initState() {
    super.initState();
    VoiceLang.load().then((l) {
      if (mounted) setState(() => _lang = l);
    });
    talkPrefill.addListener(_prefill);
    starterRequest.addListener(_starter);
    _input.addListener(() => setState(() {}));
    _prefill();
    _starter();
  }

  @override
  void dispose() {
    talkPrefill.removeListener(_prefill);
    starterRequest.removeListener(_starter);
    final hf = _hf;
    if (hf != null) {
      hf.removeListener(_onHandsFree);
      hf.stop();
      hf.dispose();
    }
    _voice.cancel();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _prefill() {
    final t = talkPrefill.value;
    if (t == null) return;
    talkPrefill.value = null;
    _input.text = t;
    _input.selection = TextSelection.collapsed(offset: t.length);
    _focus.requestFocus();
  }

  void _starter() {
    final s = starterRequest.value;
    if (s == null) return;
    starterRequest.value = null;
    talkPrefill.value = starterWords(s);
  }

  void _onHandsFree() {
    if (!mounted) return;
    setState(() {});
    final note = _hf?.note;
    if (!_handsFreeOn && note != null) showAllyToast(context, note);
  }

  Future<void> _markStarted() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(allyStartedKey, true);
    } catch (_) {}
  }

  void _send([String? text]) {
    final t = (text ?? _input.text).trim();
    if (t.isEmpty || context.read<ChatCubit>().state.sending) return;
    if (_listening) _stopListening();
    _markStarted();
    context.read<ChatCubit>().send(t);
    _input.clear();
  }

  Future<void> _listen() async {
    _dictBase = _input.text.trim().isEmpty ? '' : '${_input.text.trimRight()} ';
    setState(() => _listening = true);
    final ok = await _voice.dictate(
      locale: _lang.locale,
      onWords: (w) {
        _input.text = '$_dictBase$w';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      showAllyToast(context, 'Voice typing is not available on this phone. Typing works.');
    }
  }

  Future<void> _stopListening() async {
    await _voice.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _setLang(VoiceLang l) async {
    final was = _listening;
    if (was) await _stopListening();
    setState(() => _lang = l);
    await l.save();
    if (was) await _listen();
  }

  Future<void> _toggleHandsFree() async {
    if (_handsFreeOn) {
      await _hf!.stop();
      return;
    }
    if (_listening) await _stopListening();
    _markStarted();
    await (_hf ??= _makeHandsFree()).start();
  }

  Future<void> _allowNotifications() async {
    final n = NotificationService.instance;
    final cubit = context.read<ChatCubit>();
    await n.requestPermission();
    if (!await n.notificationsAllowed()) {
      await SystemSettings.openAppSettings();
      return;
    }
    if (!await n.canScheduleExact()) await n.requestExact();
    cubit.notificationsHandled(allowed: true);
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: Motion.reduced(context) ? Duration.zero : Motion.d2, curve: Motion.ease);
      });

  Future<void> _onState(BuildContext themed, ChatState s) async {
    _scrollToEnd();
    if (s.error != null) showAllyToast(themed, s.error!);
    final last = s.messages.lastOrNull;
    if (!s.sending && last != null && !last.fromUser && last.actions.isNotEmpty) {
      // Chat changed something: every place looks again.
      context.read<TonightCubit?>()?.load();
      context.read<NowCubit?>()?.load();
      placesRefresh.value++;
    }
    final save = s.openSave;
    if (save != null) {
      context.read<ChatCubit>().saveHandled();
      if (await openSaveFlow(themed, SaveSource(text: save))) placesRefresh.value++;
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: BlocConsumer<ChatCubit, ChatState>(
          listener: (_, s) => _onState(themed, s),
          builder: (_, s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _top(c),
            Expanded(child: _thread(themed, c, s)),
            if (s.askNotifications) _notify(c),
            if (_handsFreeOn) _handsFreeBar(c) else if (_listening) _listeningBar(c) else ...[
              if (_input.text.isEmpty && !s.sending) _examples(),
              _composer(c, s),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _top(AllyColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x2, Sp.x1, Sp.x2, 0),
        child: Row(children: [
          AllyButton('Close', kind: AllyButtonKind.ghost, icon: Icons.close_rounded, onPressed: () {
            FocusScope.of(context).unfocus();
            widget.onClose();
          }),
          Expanded(child: Text('Ally files it. You can always undo.', maxLines: 2, textAlign: TextAlign.end, style: AllyType.small(color: c.faint))),
          IconButton(
            tooltip: _handsFreeOn ? 'Stop talking hands-free' : 'Talk hands-free',
            icon: Icon(_handsFreeOn ? Icons.headset_off_rounded : Icons.headset_mic_outlined, color: c.muted),
            onPressed: _toggleHandsFree,
          ),
        ]),
      );

  Widget _thread(BuildContext themed, AllyColors c, ChatState s) {
    final cubit = context.read<ChatCubit>();
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x3, Sp.side, Sp.x3),
      children: [
        if (s.messages.isEmpty) Text('Tell me anything: a task, a reminder, an idea, or "what should I do now?"', style: AllyType.h2(color: c.ink)),
        for (var i = 0; i < s.messages.length; i++)
          s.messages[i].fromUser
              ? _UserLine(s.messages[i].text)
              : _AllyLine(
                  s.messages[i],
                  onUndo: (ai) => cubit.undoAction(i, ai),
                  onUndoAll: () => cubit.undoAll(i),
                  onSay: _send,
                  onSuggest: (t) => cubit.acceptSuggestion(i, t),
                  onMove: () => cubit.moveToLater(i),
                  onUndoMove: () => cubit.undoMove(i),
                ),
        if (s.sending) const Padding(padding: EdgeInsets.only(top: Sp.x4), child: _Thinking()),
        if (s.messages.isNotEmpty && !s.sending)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: Sp.x4),
              child: AllyButton('Clear this chat', kind: AllyButtonKind.ghost, onPressed: cubit.clear),
            ),
          ),
      ],
    );
  }

  Widget _notify(AllyColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x2),
        child: AllyCard(
          strong: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Can Ally remind you on time?', style: AllyType.h2(color: c.ink)),
            const SizedBox(height: Sp.x1),
            Text('It needs permission to send what you asked it to remember.', style: AllyType.body(color: c.muted)),
            const SizedBox(height: Sp.x3),
            Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
              AllyButton('Allow', onPressed: _allowNotifications),
              AllyButton('Not now', kind: AllyButtonKind.ghost, onPressed: () => context.read<ChatCubit>().notificationsHandled(allowed: false)),
            ]),
          ]),
        ),
      );

  Widget _examples() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.side),
          children: [
            for (final t in talkExamples) Padding(padding: const EdgeInsets.only(right: Sp.x2), child: Center(child: AllyChip(t, onTap: () => _send(t)))),
          ],
        ),
      );

  Widget _composer(AllyColors c, ChatState s) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x2, Sp.x3, Sp.x3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focus,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: AllyType.body(color: c.ink),
              decoration: const InputDecoration(hintText: 'Type, in English or Hinglish', counterText: ''),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: Sp.x1),
          IconButton(
            tooltip: 'Send',
            onPressed: _input.text.trim().isEmpty || s.sending ? null : _send,
            icon: const Icon(Icons.arrow_upward_rounded),
            style: IconButton.styleFrom(backgroundColor: c.raised, minimumSize: const Size(48, 48)),
          ),
          const SizedBox(width: Sp.x1),
          IconButton(
            tooltip: 'Speak',
            onPressed: _listen,
            icon: const Icon(Icons.mic_rounded),
            style: IconButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.bg, minimumSize: const Size(48, 48)),
          ),
        ]),
      );

  Widget _listeningBar(AllyColors c) => Container(
        padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x3, Sp.side, Sp.x3),
        decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (_input.text.isNotEmpty) ...[
            Text(_input.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: AllyType.body(color: c.ink)),
            const SizedBox(height: Sp.x2),
          ],
          Row(children: [
            Icon(Icons.graphic_eq_rounded, color: c.ink),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Listening…', style: AllyType.body(color: c.ink, w: FontWeight.w600)),
                Text('Say it all, then tap Stop. You can fix the words before sending.', style: AllyType.small(color: c.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: Sp.x3),
          AllySegmented<VoiceLang>(options: {for (final l in VoiceLang.values) l: l.label}, value: _lang, onChanged: _setLang),
          const SizedBox(height: Sp.x2),
          AllyButton('Stop', wide: true, onPressed: _stopListening),
        ]),
      );

  Widget _handsFreeBar(AllyColors c) {
    final hf = _hf!;
    final words = switch (hf.state) {
      TalkState.listening => hf.missed ? "Didn't catch that. Say it again." : 'Listening…',
      TalkState.thinking => 'Thinking…',
      TalkState.speaking => 'Ally is speaking',
      TalkState.off => 'Starting…',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x3, Sp.side, Sp.x3),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: Row(children: [
        Icon(Icons.headset_mic_outlined, color: c.ink),
        const SizedBox(width: Sp.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(words, style: AllyType.body(color: c.ink, w: FontWeight.w600)),
            if (hf.heard.isNotEmpty) Text(hf.heard, maxLines: 2, overflow: TextOverflow.ellipsis, style: AllyType.small(color: c.muted)),
          ]),
        ),
        AllyButton('Stop', onPressed: _toggleHandsFree),
      ]),
    );
  }
}

class _UserLine extends StatelessWidget {
  final String text;
  const _UserLine(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: Sp.x4, left: Sp.x6),
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(Rad.card)),
        child: Text(text, style: AllyType.body(color: c.ink)),
      ),
    );
  }
}

// Shown as cards or chips of their own, not as receipt lines.
const _notReceipts = {'ASK', 'LIST', 'NOW_PICK', 'STAND', 'WEEK_CARD', 'NOTES_USED', 'COMFORT_SHOWN', 'SEARCH_RESULTS', 'GOAL_PLAN'};

class _AllyLine extends StatelessWidget {
  final ChatMessage m;
  final void Function(int actionIndex) onUndo;
  final VoidCallback onUndoAll;
  final void Function(String text) onSay;
  final void Function(String title) onSuggest;
  final VoidCallback onMove;
  final VoidCallback onUndoMove;
  const _AllyLine(this.m,
      {required this.onUndo, required this.onUndoAll, required this.onSay, required this.onSuggest, required this.onMove, required this.onUndoMove});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final receipts = [for (var i = 0; i < m.actions.length; i++) if (!_notReceipts.contains(m.actions[i].type)) i];
    final created = receipts.where((i) => m.actions[i].isCreation && !m.actions[i].undone && m.actions[i].activityId != null).length;
    final ask = m.actions.where((a) => a.type == 'ASK').firstOrNull;
    final now = m.actions.where((a) => a.type == 'NOW_PICK').firstOrNull;
    final cap = m.capacity;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(m.text, style: AllyType.body(color: c.ink).copyWith(fontSize: 18, height: 1.4)),
        if (isCrisisReply(m.text)) ...[
          const SizedBox(height: Sp.x3),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            AllyButton('Call 14416', icon: Icons.call_outlined, onPressed: () => openLink(context, 'tel:14416')),
            AllyButton('More help', kind: AllyButtonKind.secondary,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SupportScreen()))),
          ]),
        ],
        if (m.aiLimit) ...[
          const SizedBox(height: Sp.x2),
          const AllyNote("Today's free AI is used up, so this came without it. Reminders, lists and your day still work."),
        ],
        if (m.aiDown) ...[
          const SizedBox(height: Sp.x2),
          const AllyNote('My thinking is limited right now. Reminders, lists and timers still work. Ask again in a little while.'),
        ],
        if (receipts.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          AllyCard(
            padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x1, Sp.x1, Sp.x1),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (created >= 2)
                Row(children: [
                  Expanded(child: Text('Saved $created things', style: AllyType.eyebrow(color: c.faint))),
                  AllyButton('Undo all', kind: AllyButtonKind.ghost, onPressed: onUndoAll),
                ]),
              for (final i in receipts) _Receipt(m.actions[i], onUndo: () => onUndo(i)),
            ]),
          ),
        ],
        for (final a in m.actions)
          if (a.type == 'GOAL_PLAN' && a.proposal != null) Padding(padding: const EdgeInsets.only(top: Sp.x3), child: GoalPlanCard(proposal: a.proposal!)),
        for (final a in m.actions)
          if (a.type == 'LIST' && a.options.isNotEmpty) ChatListCard(a, onCommand: onSay),
        if (ask != null && ask.options.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            // "Remove habit: Gym" is a command; "Pack gym bag" (which one did you finish?) is an answer.
            for (final o in ask.options) AllyChip(o.title, onTap: () => onSay(o.command ? o.title : 'Done: ${o.title}')),
          ]),
        ],
        if (now != null && now.options.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final o in now.options) AllyChip('${o.title}${o.minutes > 0 ? ' · ${o.minutes} min' : ''}', onTap: () => onSay('Done: ${o.title}')),
          ]),
        ],
        if (cap != null) ...[
          const SizedBox(height: Sp.x3),
          AllyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(cap.moved && !cap.undone ? 'Moved ${cap.moveIds.length} to later. Today keeps ${cap.keepCount}.' : cap.message,
                  style: AllyType.body(color: c.ink)),
              if (cap.moveIds.isNotEmpty && !cap.moved)
                Align(alignment: Alignment.centerRight, child: AllyButton('Move ${cap.moveIds.length} to later', kind: AllyButtonKind.secondary, onPressed: onMove)),
              if (cap.moved && !cap.undone && cap.moveActivityId != null)
                Align(alignment: Alignment.centerRight, child: AllyButton('Undo', kind: AllyButtonKind.ghost, onPressed: onUndoMove)),
            ]),
          ),
        ],
        if (m.suggestions.isNotEmpty) ...[
          const SizedBox(height: Sp.x3),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final t in m.suggestions) AllyChip('Add habit: $t', onTap: () => onSuggest(t)),
          ]),
        ],
      ]),
    );
  }
}

class _Receipt extends StatelessWidget {
  final ChatAction a;
  final VoidCallback onUndo;
  const _Receipt(this.a, {required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final (icon, text) = describeAction(a);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(children: [
        Icon(icon, size: 18, color: a.undone ? c.faint : c.muted),
        const SizedBox(width: Sp.x3),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.x2),
            child: Text(
              text,
              style: AllyType.body(color: a.undone ? c.faint : c.ink).copyWith(decoration: a.undone ? TextDecoration.lineThrough : null),
            ),
          ),
        ),
        if (a.type == 'CONTACT' && a.url != null)
          AllyButton(a.kind == 'CALL' ? 'Call' : 'WhatsApp', kind: AllyButtonKind.ghost, onPressed: () => openLink(context, a.url!)),
        if (a.undone)
          Padding(padding: const EdgeInsets.only(right: Sp.x3), child: Text('Undone', style: AllyType.small(color: c.faint)))
        else if (a.activityId != null)
          AllyButton('Undo', kind: AllyButtonKind.ghost, semanticLabel: 'Undo: $text', onPressed: onUndo),
      ]),
    );
  }
}

/// Three dots while Ally thinks; still with reduced motion.
class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Motion.reduced(context) ? _t.stop() : _t.repeat();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Semantics(
      label: 'Ally is thinking',
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, _) => Row(children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: c.muted.withValues(alpha: 0.35 + 0.65 * (((_t.value * 3 - i) % 3) < 1 ? 1 : 0)),
                shape: BoxShape.circle,
              ),
            ),
        ]),
      ),
    );
  }
}
