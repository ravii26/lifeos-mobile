import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/models/chat.dart';
import '../guide/guide_style.dart';
import '../guide/guide_setup_sheet.dart';
import '../guide/save_sheet.dart';
import '../guide/tonight_card.dart';
import '../guide/tonight_cubit.dart';
import 'chat_cubit.dart';
import 'memories_screen.dart';

/// Home tab: one chat. Talk normally; it answers in the right role and does
/// things (adds/completes tasks, logs habits, sets reminders) as it goes.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  bool _listening = false;
  // en_IN for English / Hinglish typed words, hi_IN for spoken Hindi (Ally reads both).
  String _lang = 'en_IN';
  String _dictBase = '';
  static const _langKey = 'chat_voice_lang';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final l = p.getString(_langKey);
      if (l != null && mounted) setState(() => _lang = l);
    }).catchError((_) {});
  }

  static const _starters = [
    'What should I do now?',
    'Remind me to …',
    "I'm feeling stuck today",
  ];

  @override
  void dispose() {
    _speech.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (t.trim().isEmpty) return;
    if (t.endsWith('…')) {
      _input.text = t.replaceAll('…', '');
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      return;
    }
    if (_listening) {
      _speech.stop();
      setState(() => _listening = false);
    }
    context.read<ChatCubit>().send(t);
    _input.clear();
  }

  // Voice: on-device dictation into the box, so a long ramble can be read
  // and fixed before it is sent. Nothing is recorded or uploaded as audio.
  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (st) {
        if ((st == 'done' || st == 'notListening') && mounted) setState(() => _listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Voice typing is not available on this phone.')));
      }
      return;
    }
    _dictBase = _input.text.isEmpty ? '' : '${_input.text.trimRight()} ';
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _input.text = '$_dictBase${r.recognizedWords}';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: _lang,
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _switchLang() async {
    if (_listening) await _toggleVoice();
    final next = _lang == 'en_IN' ? 'hi_IN' : 'en_IN';
    setState(() => _lang = next);
    try {
      await (await SharedPreferences.getInstance()).setString(_langKey, next);
    } catch (_) {}
  }

  Future<void> _edit(int message, int action, String current) async {
    final cubit = context.read<ChatCubit>();
    final c = TextEditingController(text: current);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change the name', style: G.text(17, w: FontWeight.w700)),
        content: TextField(controller: c, autofocus: true, maxLength: 200, style: G.text(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (title != null) await cubit.rename(message, action, title);
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: BlocConsumer<ChatCubit, ChatState>(
          listener: (context, s) async {
            _scrollToEnd();
            if (s.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!)));
            }
            final last = s.messages.lastOrNull;
            if (!s.sending && last != null && !last.fromUser && last.actions.isNotEmpty) {
              context.read<TonightCubit>().load();
            }
            final save = s.openSave;
            if (save != null) {
              final cubit = context.read<ChatCubit>();
              final tonight = context.read<TonightCubit>();
              cubit.saveHandled();
              if (await openSaveSheet(context, SaveSource(text: save))) tonight.load();
            }
          },
          builder: (context, s) {
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(children: [
                  Expanded(child: Text('Ally', style: G.display(26))),
                  IconButton(
                    tooltip: 'Set up your goals and nudges',
                    onPressed: () => openGuideSetup(context),
                    icon: const Icon(Icons.tune_rounded, color: G.ink),
                  ),
                  IconButton(
                    tooltip: 'What I remember about you',
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const MemoriesScreen())),
                    icon: const Icon(Icons.psychology_alt_outlined, color: G.ink),
                  ),
                  if (s.messages.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear chat',
                      onPressed: () => context.read<ChatCubit>().clear(),
                      icon: const Icon(Icons.delete_outline_rounded, color: G.muted),
                    ),
                ]),
              ),
              const TonightCard(),
              Expanded(
                child: s.messages.isEmpty
                    ? _Empty(onPick: _send)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: s.messages.length + (s.sending ? 1 : 0),
                        itemBuilder: (_, i) => i == s.messages.length
                            ? const _Typing()
                            : _Bubble(s.messages[i],
                                onUndo: (ai) => context.read<ChatCubit>().undoAction(i, ai),
                                onUndoAll: () => context.read<ChatCubit>().undoAll(i),
                                onEdit: (ai, current) => _edit(i, ai, current),
                                onPick: (title) => _send('Done: $title'),
                                onSuggest: (t) => context.read<ChatCubit>().acceptSuggestion(i, t),
                                onMove: () => context.read<ChatCubit>().moveToLater(i),
                                onUndoMove: () => context.read<ChatCubit>().undoMove(i)),
                      ),
              ),
              _Composer(
                controller: _input,
                sending: s.sending,
                onSend: _send,
                listening: _listening,
                lang: _lang,
                onMic: _toggleVoice,
                onLang: _switchLang,
                onSave: () async {
                  final tonight = context.read<TonightCubit>();
                  if (await openPasteSave(context)) tonight.load();
                },
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final void Function(String) onPick;
  const _Empty({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      children: [
        Text('Talk to me like a friend who knows your plans.', style: G.display(28)),
        const SizedBox(height: 10),
        Text('Ask what to do, tell me what you finished, ask for a reminder, or just vent.',
            style: G.voice(17)),
        const SizedBox(height: 22),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _ChatScreenState._starters)
            ActionChip(
              label: Text(s, style: G.text(15, w: FontWeight.w500)),
              backgroundColor: G.card,
              side: const BorderSide(color: G.line),
              shape: const StadiumBorder(),
              onPressed: () => onPick(s),
            ),
        ]),
      ],
    );
  }
}

const _roleLabel = {
  'FRIEND': 'AS A FRIEND',
  'ASSISTANT': 'ASSISTANT',
  'MENTOR': 'MENTOR',
  'COACH': 'COACH',
  'GUIDE': 'GUIDE',
};

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final void Function(int actionIndex) onUndo;
  final VoidCallback onUndoAll;
  final void Function(int actionIndex, String current) onEdit;
  final void Function(String title) onPick;
  final void Function(String title) onSuggest;
  final VoidCallback onMove;
  final VoidCallback onUndoMove;
  const _Bubble(this.m,
      {required this.onUndo,
      required this.onUndoAll,
      required this.onEdit,
      required this.onPick,
      required this.onSuggest,
      required this.onMove,
      required this.onUndoMove});

  @override
  Widget build(BuildContext context) {
    // Several things from one message get one card to check; a single thing
    // keeps the small receipt line.
    final created = [for (var i = 0; i < m.actions.length; i++) if (m.actions[i].isCreation) i];
    final grouped = created.length >= 2;
    final ask = m.actions.where((a) => a.type == 'ASK').firstOrNull;
    final now = m.actions.where((a) => a.type == 'NOW_PICK').firstOrNull;
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment: m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!m.fromUser && m.role != null)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 4),
                child: Text(_roleLabel[m.role] ?? 'ALLY', style: G.label()),
              ),
            Container(
              margin: EdgeInsets.only(top: !m.fromUser && m.role != null ? 4 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: m.fromUser ? G.ink : G.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(m.fromUser ? 20 : 6),
                  bottomRight: Radius.circular(m.fromUser ? 6 : 20),
                ),
              ),
              child: Text(
                m.text,
                style: m.fromUser
                    ? G.text(16, color: Colors.white, w: FontWeight.w500)
                    : G.voice(17, color: G.ink),
              ),
            ),
            if (grouped)
              _SavedCard(
                items: [for (final i in created) (i, m.actions[i])],
                onUndo: onUndo,
                onUndoAll: onUndoAll,
                onEdit: onEdit,
              ),
            for (var ai = 0; ai < m.actions.length; ai++)
              if (m.actions[ai].type != 'ASK' && m.actions[ai].type != 'NOW_PICK' && m.actions[ai].type != 'STAND' && m.actions[ai].type != 'WEEK_CARD' && !(grouped && m.actions[ai].isCreation))
                _Receipt(m.actions[ai], onUndo: () => onUndo(ai)),
            if (ask != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in ask.options)
                    ActionChip(
                      label: Text(o.title, style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: G.card,
                      side: const BorderSide(color: G.line),
                      shape: const StadiumBorder(),
                      onPressed: () => onPick(o.title),
                    ),
                ]),
              ),
            // The right-now answer: tap one to say you did it (Ally logs it, with Undo).
            if (now != null && now.options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in now.options)
                    ActionChip(
                      avatar: const Icon(Icons.check_rounded, size: 18, color: G.ink),
                      label: Text('${o.title}${o.minutes > 0 ? ' · ${o.minutes} min' : ''}', style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: G.card,
                      side: const BorderSide(color: G.line),
                      shape: const StadiumBorder(),
                      onPressed: () => onPick(o.title),
                    ),
                ]),
              ),
            if (m.capacity != null)
              _CapacityCard(c: m.capacity!, onMove: onMove, onUndo: onUndoMove),
            if (m.suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in m.suggestions)
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18, color: G.ink),
                      label: Text('Habit: $t', style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: G.card,
                      side: const BorderSide(color: G.line),
                      shape: const StadiumBorder(),
                      onPressed: () => onSuggest(t),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

String _repeatLabel(String rule) {
  const days = {'MO': 'Mon', 'TU': 'Tue', 'WE': 'Wed', 'TH': 'Thu', 'FR': 'Fri', 'SA': 'Sat', 'SU': 'Sun'};
  final parts = {for (final p in rule.split(';')) p.split('=').first: p.contains('=') ? p.split('=').last : ''};
  switch (parts['FREQ']) {
    case 'DAILY':
      return 'every day';
    case 'MONTHLY':
      return 'every month';
    case 'WEEKLY':
      final d = (parts['BYDAY'] ?? '').split(',').where((x) => x.isNotEmpty).map((x) => days[x] ?? x);
      return d.isEmpty ? 'every week' : 'every ${d.join(', ')}';
  }
  return 'repeats';
}

/// (icon, one-line description) of something Ally did.
(IconData, String) _describe(ChatAction a) {
  String time(DateTime t) => DateFormat('h:mm a').format(t);
  return switch (a.type) {
    'TASK_ADDED' => (Icons.add_task_rounded, 'To-do: ${a.text}'),
    'REMEMBERED' => (Icons.bookmark_add_outlined, 'Remembered: ${a.text}'),
    'FORGOT' => (Icons.bookmark_remove_outlined, 'Forgot: ${a.text}'),
    'NUDGE_SET' => (
        Icons.notifications_active_outlined,
        a.time == null
            ? '${a.kind == 'MORNING' ? 'Morning heads-up' : 'Nightly nudge'} turned off'
            : '${a.kind == 'MORNING' ? 'Morning heads-up' : 'Nightly nudge'} at ${a.time}'
      ),
    'TASK_COMPLETED' => (Icons.check_circle_rounded, 'Completed: ${a.text}'),
    'HABIT_LOGGED' => (Icons.check_circle_rounded, 'Logged: ${a.text}'),
    'HABIT_ADDED' => (
        Icons.repeat_rounded,
        'Habit: ${a.text}${a.detail == null ? '' : ' (${a.detail!.toLowerCase()})'}'
      ),
    'PROJECT_ADDED' => (
        Icons.flag_outlined,
        'Project: ${a.text}'
            '${a.tasks > 0 ? ' · ${a.tasks} to-do${a.tasks == 1 ? '' : 's'}' : ''}'
            '${a.detail == null ? '' : ' · due ${DateFormat('EEE d MMM').format(DateTime.parse(a.detail!))}'}'
      ),
    'NOTE_ADDED' => (
        Icons.sticky_note_2_outlined,
        'Note ${a.text}${a.items.isEmpty ? '' : ': ${a.items.join(', ')}'}'
      ),
    'REMINDER_SET' => (
        Icons.alarm_rounded,
        'Reminder ${a.remindAt == null ? '' : DateFormat('EEE d MMM').format(a.remindAt!)} '
            '${a.remindAt == null ? '' : time(a.remindAt!)}'
            '${a.windowEnd == null ? '' : ' to ${time(a.windowEnd!)}'}'
            '${a.repeatRule == null ? '' : ', ${_repeatLabel(a.repeatRule!)}'}: ${a.text}'
      ),
    'MODE_SET' => (
        Icons.bedtime_outlined,
        switch (a.kind) {
          'SICK' => 'Sick mode on',
          'BUSY' => 'Busy mode on${a.detail == null ? '' : ' until ${a.detail}'}',
          'TRAVEL' => 'Travel mode on',
          'HOLIDAY' => 'Holiday mode on',
          _ => 'Back to normal',
        }
      ),
    'PROGRESS_LOGGED' => (Icons.trending_up_rounded, 'Logged: ${a.detail ?? a.text}'),
    'PROJECT_STATUS' => (
        Icons.flag_outlined,
        switch (a.kind) {
          'PAUSED' => '${a.text} paused',
          'ABANDONED' => '${a.text} let go',
          'COMPLETED' => '${a.text} finished',
          _ => '${a.text} back on',
        }
      ),
    'SCHEDULE_SET' => (Icons.schedule_rounded, 'Day updated for ${a.items.join(', ')}'),
    _ => (Icons.bolt_rounded, a.text),
  };
}

/// "5 h planned for 1.5 h": offers to move the extra to later instead of
/// letting today be overloaded. Nothing moves until you tap.
class _CapacityCard extends StatelessWidget {
  final ChatCapacity c;
  final VoidCallback onMove;
  final VoidCallback onUndo;
  const _CapacityCard({required this.c, required this.onMove, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final moved = c.moved && !c.undone;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        color: G.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: G.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(moved ? 'Moved ${c.moveIds.length} to later. Today keeps ${c.keepCount}.' : c.message,
            style: G.text(14, w: FontWeight.w600)),
        const SizedBox(height: 4),
        if (c.moveIds.isNotEmpty && !c.moved)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onMove,
              child: Text('Move ${c.moveIds.length} to later', style: G.text(13, w: FontWeight.w700, color: G.ink)),
            ),
          ),
        if (moved && c.moveActivityId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUndo,
              child: Text('Undo', style: G.text(13, w: FontWeight.w700, color: G.muted)),
            ),
          ),
      ]),
    );
  }
}

/// One card for everything Ally saved from a single message, with a way to
/// rename each thing, undo it, or undo the whole message.
class _SavedCard extends StatelessWidget {
  final List<(int, ChatAction)> items;
  final void Function(int actionIndex) onUndo;
  final VoidCallback onUndoAll;
  final void Function(int actionIndex, String current) onEdit;
  const _SavedCard({required this.items, required this.onUndo, required this.onUndoAll, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final live = items.where((e) => !e.$2.undone).length;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: G.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: G.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(live == 0 ? 'All undone' : 'Saved $live thing${live == 1 ? '' : 's'}. Check?',
            style: G.text(15, w: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final (ai, a) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_describe(a).$1, size: 16, color: a.undone ? G.muted : G.good),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_describe(a).$2,
                    style: G.text(14, color: a.undone ? G.muted : G.ink, w: FontWeight.w500)
                        .copyWith(decoration: a.undone ? TextDecoration.lineThrough : null)),
              ),
              if (!a.undone && a.id != null && a.itemType != null)
                InkWell(
                  onTap: () => onEdit(ai, a.text),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text('Edit', style: G.text(13, w: FontWeight.w700, color: G.ink)),
                  ),
                ),
              if (!a.undone && a.activityId != null)
                InkWell(
                  onTap: () => onUndo(ai),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text('Undo', style: G.text(13, w: FontWeight.w700, color: G.muted)),
                  ),
                ),
            ]),
          ),
        if (live > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUndoAll,
              child: Text('Undo all', style: G.text(13, w: FontWeight.w700, color: G.muted)),
            ),
          )
        else
          const SizedBox(height: 6),
      ]),
    );
  }
}

/// A small line under the reply showing what was actually done.
class _Receipt extends StatelessWidget {
  final ChatAction a;
  final VoidCallback onUndo;
  const _Receipt(this.a, {required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = _describe(a);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: G.good),
        const SizedBox(width: 6),
        Flexible(
          child: Text(a.undone ? 'Undone: $text' : text,
              style: G.text(13,
                  color: G.muted,
                  w: FontWeight.w700).copyWith(decoration: a.undone ? TextDecoration.lineThrough : null)),
        ),
        if (a.activityId != null && !a.undone)
          GestureDetector(
            onTap: onUndo,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text('Undo', style: G.text(13, w: FontWeight.w700, color: G.ink)),
            ),
          ),
      ]),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

/// After a few seconds, say why it's slow: the free server sleeps when idle.
class _TypingState extends State<_Typing> {
  bool _slow = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(seconds: 6), () => mounted ? setState(() => _slow = true) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
          child: Text(_slow ? 'Waking up the server… a few more seconds.' : 'Thinking…', style: G.voice(16)),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final void Function([String?]) onSend;
  final VoidCallback onSave;
  final bool listening;
  final String lang;
  final VoidCallback onMic;
  final VoidCallback onLang;
  const _Composer(
      {required this.controller,
      required this.sending,
      required this.onSend,
      required this.onSave,
      required this.listening,
      required this.lang,
      required this.onMic,
      required this.onLang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 96),
      color: G.bg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (listening)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              lang == 'hi_IN'
                  ? 'Listening in Hindi. Say it all, then tap the mic to stop.'
                  : 'Listening. Say it all, then tap the mic to stop.',
              style: G.text(13, color: G.muted, w: FontWeight.w600),
            ),
          ),
        Row(children: [
          IconButton(
            tooltip: 'Turn a saved video into an action',
            onPressed: onSave,
            icon: const Icon(Icons.link_rounded, color: G.muted),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: G.text(16),
              decoration: InputDecoration(
                hintText: listening ? 'Listening…' : 'Message',
                hintStyle: G.text(16, color: G.muted),
                filled: true,
                fillColor: G.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Tap the label to switch the speaking language.
          InkWell(
            onTap: onLang,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(lang == 'hi_IN' ? 'हिं' : 'EN', style: G.text(13, w: FontWeight.w700, color: G.muted)),
            ),
          ),
          IconButton(
            tooltip: listening ? 'Stop' : 'Speak',
            onPressed: onMic,
            icon: Icon(listening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                color: listening ? G.ink : G.muted),
          ),
          IconButton.filled(
            onPressed: sending ? null : () => onSend(),
            style: IconButton.styleFrom(backgroundColor: G.ink),
            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          ),
        ]),
      ]),
    );
  }
}
