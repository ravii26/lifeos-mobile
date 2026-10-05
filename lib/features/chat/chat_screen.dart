import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/models/chat.dart';
import '../guide/guide_style.dart';
import '../guide/save_sheet.dart';
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

  static const _starters = [
    'What should I do now?',
    'Remind me to …',
    "I'm feeling stuck today",
  ];

  @override
  void dispose() {
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
    context.read<ChatCubit>().send(t);
    _input.clear();
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
              Expanded(
                child: s.messages.isEmpty
                    ? _Empty(onPick: _send)
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: s.messages.length + (s.sending ? 1 : 0),
                        itemBuilder: (_, i) => i == s.messages.length
                            ? const _Typing()
                            : _Bubble(s.messages[i]),
                      ),
              ),
              _Composer(controller: _input, sending: s.sending, onSend: _send),
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
  const _Bubble(this.m);

  @override
  Widget build(BuildContext context) {
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
            for (final a in m.actions) _Receipt(a),
          ],
        ),
      ),
    );
  }
}

/// A small line under the reply showing what was actually done.
class _Receipt extends StatelessWidget {
  final ChatAction a;
  const _Receipt(this.a);

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (a.type) {
      'TASK_ADDED' => (Icons.add_task_rounded, 'Added: ${a.text}'),
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
      'REMINDER_SET' => (
          Icons.alarm_rounded,
          'Reminder ${a.remindAt == null ? '' : DateFormat('EEE d MMM, h:mm a').format(a.remindAt!)}: ${a.text}'
        ),
      _ => (Icons.bolt_rounded, a.text),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: G.good),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: G.text(13, color: G.muted, w: FontWeight.w700))),
      ]),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
          child: Text('Thinking…', style: G.voice(16)),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final void Function([String?]) onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 96),
      color: G.bg,
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            style: G.text(16),
            decoration: InputDecoration(
              hintText: 'Message',
              hintStyle: G.text(16, color: G.muted),
              filled: true,
              fillColor: G.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          onPressed: sending ? null : () => onSend(),
          style: IconButton.styleFrom(backgroundColor: G.ink),
          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
        ),
      ]),
    );
  }
}
