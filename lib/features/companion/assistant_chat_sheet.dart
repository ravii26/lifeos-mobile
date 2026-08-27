import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/life_repository.dart';
import 'assistant_cubit.dart';

/// The mascot's chat surface — opened via long-press on [CompanionOverlay].
/// A proper multi-turn chat sheet (text input + scrollable history *within
/// this sheet's lifetime*, not persisted — Phase 1 is stateless by design),
/// upgrading the mascot from a one-shot speech bubble into something you can
/// actually talk to.
Future<void> showAssistantChatSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => AssistantCubit(getIt<LifeRepository>()),
      child: const _AssistantChatSheet(),
    ),
  );
}

class _AssistantChatSheet extends StatefulWidget {
  const _AssistantChatSheet();

  @override
  State<_AssistantChatSheet> createState() => _AssistantChatSheetState();
}

class _AssistantChatSheetState extends State<_AssistantChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  void _send(BuildContext context) {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    context.read<AssistantCubit>().send(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.tx4.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.tx4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('Jarvis',
                      style: TextStyle(
                          color: AppColors.tx, fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<AssistantCubit, AssistantState>(
                builder: (context, state) {
                  if (state.turns.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Ask about your areas, goals, habits, or tasks — or just say '
                        '"what now" for your current priority.',
                        style: TextStyle(color: AppColors.tx3, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.turns.length + (state.loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= state.turns.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final turn = state.turns[i];
                      final isUser = turn.role == ChatRole.user;
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.accent.withValues(alpha: 0.18)
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(turn.text,
                              style: TextStyle(color: AppColors.tx, fontSize: 13.5, height: 1.35)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: AppColors.tx, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Message Jarvis…',
                        hintStyle: TextStyle(color: AppColors.tx4),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Builder(builder: (context) {
                    return IconButton(
                      onPressed: () => _send(context),
                      icon: Icon(Icons.send_rounded, color: AppColors.accent),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
