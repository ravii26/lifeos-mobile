import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/system/system_settings.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../guide/save_sheet.dart';
import '../places/now_card.dart';
import '../places/now_cubit.dart';
import '../guide/tonight_cubit.dart';
import 'chat_cubit.dart';
import 'goal_plan_card.dart';
import 'starters.dart';

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
  static const _startedKey = 'ally_started';

  // A guided starter in progress (doc 17): one question at a time.
  Starter? _starter;
  final Map<String, String> _answers = {};
  final List<String> _answered = [];
  bool _askFree = false;
  // Has this person ever told Ally anything? Changes Now's hello.
  bool _started = true;

  void _onStarterRequest() {
    final s = starterRequest.value;
    if (s == null) return;
    starterRequest.value = null;
    _startGuide(s);
  }

  @override
  void initState() {
    super.initState();
    starterRequest.addListener(_onStarterRequest);
    SharedPreferences.getInstance().then((p) {
      final l = p.getString(_langKey);
      if (!mounted) return;
      setState(() {
        if (l != null) _lang = l;
        _started = p.getBool(_startedKey) ?? false;
      });
    }).catchError((_) {});
  }

  void _markStarted() {
    if (_started) return;
    setState(() => _started = true);
    SharedPreferences.getInstance().then((p) => p.setBool(_startedKey, true)).catchError((_) => false);
  }

  StarterStep? get _step =>
      _starter == null ? null : nextStep(_starter!, _answers, askFree: _askFree, now: DateTime.now());

  Future<void> _startGuide(Starter s) async {
    HapticFeedback.selectionClick();
    var askFree = false;
    if (s == Starter.goal) {
      // Asked only the first time a plan needs it.
      try {
        askFree = !await getIt<LifeRepository>().dayIsSet();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _starter = s;
      _askFree = askFree;
      _answers.clear();
      _answered.clear();
    });
    _input.clear();
  }

  void _closeGuide() => setState(() {
        _starter = null;
        _answers.clear();
        _answered.clear();
      });

  // A quick double tap on a chip must not also answer the next question.
  DateTime _lastAnswer = DateTime(0);

  Future<void> _answer(String text) async {
    final step = _step;
    if (step == null) return;
    final now = DateTime.now();
    if (now.difference(_lastAnswer) < const Duration(milliseconds: 400)) return;
    _lastAnswer = now;
    var value = text.trim();
    if (value == 'Paste from clipboard') {
      value = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (value.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Nothing copied yet. Copy the link first, or paste it in the box.')));
        }
        return;
      }
    }
    if (value.isEmpty && !step.canSkip) return;
    setState(() {
      _answers[step.key] = value;
      _answered.add(step.key);
    });
    _input.clear();
    if (_step == null) await _finishGuide();
  }

  void _back() {
    if (_answered.isEmpty) return _closeGuide();
    setState(() => _answers.remove(_answered.removeLast()));
  }

  Future<void> _finishGuide() async {
    final s = _starter!;
    final answers = Map<String, String>.from(_answers);
    _closeGuide();
    _markStarted();
    final free = answers['free'];
    if (s == Starter.goal && free != null) {
      final b = basicsForFree(free);
      if (b != null) {
        try {
          await getIt<LifeRepository>().setDayBasics(
              wake: b.wake, sleep: b.sleep, officeDays: b.officeDays, officeStart: b.start, officeEnd: b.end);
        } catch (_) {}
      }
    }
    if (!mounted) return;
    final message = composeMessage(s, answers, DateTime.now());
    if (s == Starter.video) {
      final tonight = context.read<TonightCubit>();
      final now = context.read<NowCubit>();
      if (await openSaveSheet(context, SaveSource(text: message))) {
        tonight.load();
        now.load();
        placesRefresh.value++;
      }
      return;
    }
    context.read<ChatCubit>().send(message);
  }

  /// The notification card's button: Android's own question, then exact
  /// alarms. If the person said no before, Android won't ask again, so the
  /// app's settings page opens instead.
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

  @override
  void dispose() {
    starterRequest.removeListener(_onStarterRequest);
    _speech.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final t = text ?? _input.text;
    if (_starter != null) {
      _answer(t);
      return;
    }
    if (t.trim().isEmpty) return;
    _markStarted();
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
              // Chat just changed something: the card, Plan and Notes should look again.
              context.read<NowCubit>().load();
              placesRefresh.value++;
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
            final talking = s.messages.isNotEmpty;
            final step = _step;
            final guiding = _starter != null && step != null;
            final nowPicking = context.select<NowCubit, bool>((c) => c.state.current != null && c.state.kind == 'PICK');
            return Column(children: [
              // Before you say anything, Now is the whole screen. Once you talk, it
              // folds to one line and the conversation takes the space.
              if (!guiding) NowCard(compact: talking, fresh: !_started, onStarter: _startGuide),
              if (guiding)
                Expanded(
                  child: _GuidePanel(
                    starter: _starter!,
                    step: step,
                    answers: _answers,
                    total: steps(_starter!, _answers, askFree: _askFree, now: DateTime.now()).length,
                    askFree: _askFree,
                    onChip: _answer,
                    onSkip: () => _answer(''),
                    onBack: _back,
                    onClose: _closeGuide,
                  ),
                )
              else if (talking)
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                    itemCount: s.messages.length + 1,
                    itemBuilder: (_, i) => i == s.messages.length
                        ? (s.sending
                            ? const _Typing()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => context.read<ChatCubit>().clear(),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: G.muted),
                                  child: Text('Clear this chat', style: G.text(13, color: G.muted)),
                                ),
                              ))
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
              // Reminders need permission: asked right after the first one is set, with the reason.
              if (!guiding && s.askNotifications)
                _NotifyCard(
                  onAllow: _allowNotifications,
                  onLater: () => context.read<ChatCubit>().notificationsHandled(allowed: false),
                ),
              // Never a blank box: things to say, always one tap away. Hidden while
              // the empty Now already shows the big starters.
              if (!guiding && (talking || nowPicking))
                _Suggestions(controller: _input, onStarter: _startGuide, onSay: _send),
              _Composer(
                controller: _input,
                hint: guiding ? step.hint : null,
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

const _roleLabel = {
  'FRIEND': 'As a friend',
  'ASSISTANT': 'Assistant',
  'MENTOR': 'Mentor',
  'COACH': 'Coach',
  'GUIDE': 'Guide',
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
        constraints: BoxConstraints(maxWidth: m.fromUser ? 300 : double.infinity),
        child: Column(
          crossAxisAlignment: m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!m.fromUser) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: G.accent),
                  const SizedBox(width: 5),
                  Text(_roleLabel[m.role] ?? 'Ally whisper', style: G.label(size: 11, color: G.faint)),
                ]),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: G.accent.withValues(alpha: 0.5), width: 1.5)),
                ),
                child: Text(
                  '“${m.text}”',
                  style: G.voice(15.5, color: G.ink),
                ),
              ),
            ] else ...[
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.text,
                  style: G.text(14.5, height: 1.4, color: G.ink),
                ),
              ),
            ],
            if (grouped)
              _SavedCard(
                items: [for (final i in created) (i, m.actions[i])],
                onUndo: onUndo,
                onUndoAll: onUndoAll,
                onEdit: onEdit,
              ),
            for (var ai = 0; ai < m.actions.length; ai++)
              if (m.actions[ai].type != 'ASK' && m.actions[ai].type != 'NOW_PICK' && m.actions[ai].type != 'STAND' && m.actions[ai].type != 'WEEK_CARD' && m.actions[ai].type != 'NOTES_USED' && m.actions[ai].type != 'COMFORT_SHOWN' && m.actions[ai].type != 'SEARCH_RESULTS' && m.actions[ai].type != 'GOAL_PLAN' && !(grouped && m.actions[ai].isCreation))
                _Receipt(m.actions[ai], onUndo: () => onUndo(ai)),
            for (final a in m.actions)
              if (a.type == 'GOAL_PLAN' && a.proposal != null) GoalPlanCard(proposal: a.proposal!),
            if (ask != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final o in ask.options)
                    ActionChip(
                      label: Text(o.title, style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: G.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                      avatar: Icon(Icons.check_rounded, size: 18, color: G.ink),
                      label: Text('${o.title}${o.minutes > 0 ? ' · ${o.minutes} min' : ''}', style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: G.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                      avatar: Icon(Icons.add_rounded, size: 18, color: G.ink),
                      label: Text('Habit: $t', style: G.text(14, w: FontWeight.w600)),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(color: G.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
    'NOTE_UPDATED' => (Icons.sticky_note_2_outlined, 'Updated note: ${a.text}'),
    'PROGRESS_LOGGED' => (Icons.trending_up_rounded, 'Logged: ${a.detail ?? a.text}'),
    'BUSY_SET' => (
        Icons.event_busy_outlined,
        a.detail == null ? 'Free again' : 'Busy until ${time(DateTime.parse(a.detail!).toLocal())}: nothing from me till then'
      ),
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: G.ink, width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(moved ? 'Moved ${c.moveIds.length} to later. Today keeps ${c.keepCount}.' : c.message,
            style: G.text(15, w: FontWeight.w500, height: 1.45)),
        if (c.moveIds.isNotEmpty && !c.moved)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onMove,
              child: Text('Move ${c.moveIds.length} to later', style: G.text(14, w: FontWeight.w700, color: G.ink)),
            ),
          ),
        if (moved && c.moveActivityId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUndo,
              child: Text('Undo', style: G.text(13, w: FontWeight.w500, color: G.muted)),
            ),
          ),
      ]),
    );
  }
}

/// One list for everything Ally saved from a single message, with a way to
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
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: G.inset,
        border: Border.all(color: G.lineSoft, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 16, color: G.good),
            const SizedBox(width: 6),
            Text(live == 0 ? 'All undone' : 'Saved $live thing${live == 1 ? '' : 's'}. Check?',
                style: G.label(size: 12, color: G.ink, w: FontWeight.w600)),
          ]),
          if (live > 1)
            InkWell(
              onTap: onUndoAll,
              child: Text('Undo all', style: G.label(size: 11, color: G.faint)),
            ),
        ]),
        const SizedBox(height: 8),
        Container(height: 0.5, color: G.lineSoft),
        for (final (ai, a) in items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: a.itemType == 'HABIT' ? G.good : G.carried,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _describe(a).$2,
                  style: G.text(13.5, color: a.undone ? G.faint : G.ink, w: FontWeight.w500)
                      .copyWith(decoration: a.undone ? TextDecoration.lineThrough : null),
                ),
              ),
              if (!a.undone && a.id != null && a.itemType != null)
                InkWell(
                  onTap: () => onEdit(ai, a.text),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: Text('Edit', style: G.label(size: 11, color: G.accent)),
                  ),
                ),
              if (!a.undone && a.activityId != null)
                InkWell(
                  onTap: () => onUndo(ai),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                    child: Text('Undo', style: G.label(size: 11, color: G.faint)),
                  ),
                ),
            ]),
          ),
          if (items.last != (ai, a)) Container(height: 0.5, color: G.lineSoft),
        ],
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
        Icon(icon, size: 15, color: G.good),
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
          margin: const EdgeInsets.only(top: 12),
          child: Text(_slow ? 'Waking up the server… a few more seconds.' : 'Thinking…', style: G.voice(16)),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool sending;
  final void Function([String?]) onSend;
  final VoidCallback onSave;
  final bool listening;
  final String lang;
  final VoidCallback onMic;
  final VoidCallback onLang;
  const _Composer(
      {required this.controller,
      this.hint,
      required this.sending,
      required this.onSend,
      required this.onSave,
      required this.listening,
      required this.lang,
      required this.onMic,
      required this.onLang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (listening)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang == 'hi_IN'
                    ? 'Listening in Hindi. Say it all, then tap the mic. You can fix the words before sending.'
                    : 'Listening. Say it all, then tap the mic. You can fix the words before sending.',
                style: G.text(13, color: G.muted, height: 1.45),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: G.card,
            border: Border.all(color: listening ? G.accent : G.lineSoft, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(Icons.edit_note_rounded, size: 20, color: G.faint),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: G.text(14),
                cursorColor: G.accent,
                decoration: InputDecoration(
                  hintText: listening ? 'Listening…' : (hint ?? 'Tell Ally anything or ask…'),
                  hintStyle: G.label(size: 13, color: G.faint),
                  isDense: true,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            // Dialect Toggle Pill
            InkWell(
              onTap: onLang,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  lang == 'hi_IN' ? 'हिं' : 'EN',
                  style: G.label(size: 10, color: G.muted, w: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Link-Save Icon
            InkWell(
              onTap: onSave,
              child: SizedBox(
                height: 38,
                width: 34,
                child: Icon(Icons.bookmark_add_outlined, size: 18, color: G.faint),
              ),
            ),
            // Send / Mic Action Capsule
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, v, _) {
                final send = v.text.trim().isNotEmpty && !listening;
                return InkWell(
                  onTap: send ? (sending ? null : () => onSend()) : onMic,
                  child: Container(
                    height: 32,
                    width: 32,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: send
                          ? G.accent.withValues(alpha: 0.15)
                          : (listening ? G.accent.withValues(alpha: 0.2) : G.inset),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Icon(
                      send
                          ? Icons.arrow_upward_rounded
                          : (listening ? Icons.stop_rounded : Icons.mic_none_rounded),
                      size: 17,
                      color: send || listening ? G.accent : G.faint,
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

/// One guided question at a time: what was answered so far, the question,
/// big chips, and always a way back out (doc 17).
class _GuidePanel extends StatelessWidget {
  final Starter starter;
  final StarterStep step;
  final Map<String, String> answers;
  final int total;
  final bool askFree;
  final ValueChanged<String> onChip;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onClose;
  const _GuidePanel({
    required this.starter,
    required this.step,
    required this.answers,
    required this.total,
    required this.askFree,
    required this.onChip,
    required this.onSkip,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final done = steps(starter, answers, askFree: askFree, now: DateTime.now()).where((x) => answers.containsKey(x.key)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
        child: Row(children: [
          Icon(starter.icon, size: 18, color: G.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(starter.label, style: G.text(15, w: FontWeight.w600))),
          if (total > 1) Text('${done.length + 1} of $total', style: G.label(size: 12, color: G.faint)),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: G.muted),
          ),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 12), children: [
          for (final d in done) ...[
            Text(d.question, style: G.text(13, color: G.muted)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(answers[d.key]!.isEmpty ? 'Skipped' : answers[d.key]!, style: G.text(14.5)),
              ),
            ),
          ],
          Text(step.question, style: G.voice(19, color: G.ink)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in step.chips)
              ActionChip(
                label: Text(c, style: G.text(15, w: FontWeight.w600)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                backgroundColor: G.card,
                side: BorderSide(color: G.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onPressed: () => onChip(c),
              ),
          ]),
          if (step.chips.isEmpty)
            Text('Type it below, or tap the mic and say it.', style: G.text(13, color: G.muted)),
          const SizedBox(height: 20),
          Row(children: [
            TextButton.icon(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: G.muted),
              label: Text(done.isEmpty ? 'Cancel' : 'Back', style: G.text(14, color: G.muted)),
            ),
            const Spacer(),
            if (step.canSkip)
              TextButton(onPressed: onSkip, child: Text('Skip', style: G.text(14, color: G.muted))),
          ]),
        ]),
      ),
    ]);
  }
}

/// Small things to say above the text box, so it is never a blank page.
/// Hidden while typing.
class _Suggestions extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<Starter> onStarter;
  final void Function([String?]) onSay;
  const _Suggestions({required this.controller, required this.onStarter, required this.onSay});

  @override
  Widget build(BuildContext context) {
    final evening = DateTime.now().hour >= 18;
    final ask = evening ? 'Plan tomorrow' : 'What should I do now?';
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, v, _) {
        if (v.text.isNotEmpty) return const SizedBox.shrink();
        Widget chip(String label, VoidCallback onTap) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(label, style: G.text(13.5, w: FontWeight.w500)),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: G.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onPressed: onTap,
              ),
            );
        return SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            chip(ask, () => onSay(ask)),
            for (final s in nowStarters) chip(s.short, () => onStarter(s)),
          ]),
        );
      },
    );
  }
}

/// Asked once, right after the first reminder: why, then Android's question.
class _NotifyCard extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onLater;
  const _NotifyCard({required this.onAllow, required this.onLater});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        decoration: BoxDecoration(
          color: G.inset,
          border: Border(left: BorderSide(color: G.accent, width: 2)),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('To remind you on time, I need to send you notifications.', style: G.text(14.5, height: 1.4)),
          Text('Only for things you ask for. Nothing else.', style: G.text(12.5, color: G.muted)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: onLater, child: Text('Not now', style: G.text(14, color: G.muted))),
            TextButton(
              onPressed: onAllow,
              child: Text('Allow notifications', style: G.text(14, w: FontWeight.w700, color: G.accent)),
            ),
          ]),
        ]),
      );
}
