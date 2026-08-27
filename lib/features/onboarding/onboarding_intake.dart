import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/onboarding.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../shell/life_cubit.dart';
import 'onboarding_cubit.dart';

const _placeholder =
    'A few sentences is plenty — e.g. "I want to get back into running, work\'s '
    "been overwhelming and I keep missing deadlines, and I've drifted from "
    'calling my parents."';

/// Shown on Home instead of the normal (empty) dashboard when the account has
/// no Areas yet. Turns a few sentences into a proposed starter setup — Areas
/// plus Goals/Habits/Tasks — using the same AI-extraction pattern already
/// proven in Library's "extract actions" (server: `onboarding.extract.ts`).
/// Mirrors the web `OnboardingIntake` component 1:1.
class OnboardingIntake extends StatelessWidget {
  const OnboardingIntake({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(getIt<LifeRepository>()),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.surface4,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _generate() async {
    final t = _text.text.trim();
    if (t.length < 10) {
      _snack('Write a sentence or two first', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final cubit = context.read<OnboardingCubit>();
    await cubit.extract(t);
    final err = cubit.state.error;
    if (err != null) _snack(err, error: true);
  }

  Future<void> _create() async {
    final cubit = context.read<OnboardingCubit>();
    final result = await cubit.createSelected();
    if (!mounted || result == null) {
      final err = cubit.state.error;
      if (err != null) _snack(err, error: true);
      return;
    }
    if (result.failures == 0) {
      _snack('Set up ${result.areasCreated} area${result.areasCreated == 1 ? '' : 's'} '
          'and ${result.actionsCreated} item${result.actionsCreated == 1 ? '' : 's'}');
    } else {
      _snack('Created most of it, but ${result.failures} item${result.failures == 1 ? '' : 's'} '
          'failed — you can add those manually', error: true);
    }
    // LifeCubit owns `areas` for the whole Home screen; refresh so this
    // widget's parent sees areas.isNotEmpty and swaps back to the normal
    // dashboard on its own.
    if (mounted) context.read<LifeCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, s) {
        if (s.proposal == null) return _intro(context, s);
        return _review(context, s);
      },
    );
  }

  Widget _intro(BuildContext context, OnboardingState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow("Let's set up your life"),
        const SizedBox(height: 8),
        Text(
          "Tell me what's going on, and I'll build your starter setup",
          style: GoogleFonts.hankenGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.tx),
        ),
        const SizedBox(height: 8),
        Text(
          'LifeOS works off Areas, Goals, Habits, and Tasks — instead of filling '
          "those in one at a time, just describe your life and what you want to "
          "work on. I'll propose a starter set you can edit or reject before "
          "anything's created.",
          style: TextStyle(fontSize: 13, color: AppColors.tx3, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.inset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line2),
          ),
          child: TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            style: TextStyle(fontSize: 14, color: AppColors.tx),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: _placeholder,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Nothing is created until you review and confirm on the next step.",
          style: TextStyle(fontSize: 11, color: AppColors.tx4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: s.extracting ? null : _generate,
            icon: s.extracting
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accentInk),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(s.extracting ? 'Thinking…' : 'Generate my starter setup'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentInk,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _review(BuildContext context, OnboardingState s) {
    final proposal = s.proposal!;
    final cubit = context.read<OnboardingCubit>();

    final actionsByArea = <String, List<MapEntry<int, OnboardingAction>>>{};
    for (var i = 0; i < proposal.actions.length; i++) {
      final a = proposal.actions[i];
      (actionsByArea[a.areaName] ??= []).add(MapEntry(i, a));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow("Review before anything's created"),
                  const SizedBox(height: 4),
                  Text('Your proposed starter setup',
                      style: GoogleFonts.hankenGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tx)),
                ],
              ),
            ),
            TextButton(
              onPressed: s.creating ? null : cubit.startOver,
              child: const Text('Start over'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final area in proposal.areas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AreaBlock(
              name: area.name,
              type: area.type,
              colorHex: area.color,
              checked: s.checkedAreas.contains(area.name),
              onToggle: () => cubit.toggleArea(area.name),
              items: actionsByArea[area.name] ?? const [],
              checkedActions: s.checkedActions,
              onToggleAction: cubit.toggleAction,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          "Unchecked items won't be created — you can always add them later manually.",
          style: TextStyle(fontSize: 11, color: AppColors.tx4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (s.creating || s.checkedAreas.isEmpty) ? null : _create,
            icon: s.creating
                ? SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accentInk),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(s.creating ? 'Setting up…' : 'Create selected'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.accentInk,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
      ],
    );
  }
}

class _AreaBlock extends StatelessWidget {
  final String name;
  final String type;
  final String colorHex;
  final bool checked;
  final VoidCallback onToggle;
  final List<MapEntry<int, OnboardingAction>> items;
  final Set<int> checkedActions;
  final void Function(int) onToggleAction;

  const _AreaBlock({
    required this.name,
    required this.type,
    required this.colorHex,
    required this.checked,
    required this.onToggle,
    required this.items,
    required this.checkedActions,
    required this.onToggleAction,
  });

  Color get _color {
    var h = colorHex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFFC5F23F);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: checked ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: Row(
                children: [
                  Checkbox(
                    value: checked,
                    onChanged: (_) => onToggle(),
                    activeColor: AppColors.accent,
                    checkColor: AppColors.accentInk,
                  ),
                  AreaDot(_color, size: 8),
                  const SizedBox(width: 8),
                  Text(name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _color)),
                  const SizedBox(width: 8),
                  Chip3(type == 'PRIMARY' ? 'Active focus' : 'Maintenance'),
                ],
              ),
            ),
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 38, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: GestureDetector(
                          onTap: checked ? () => onToggleAction(entry.key) : null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: checkedActions.contains(entry.key),
                                  onChanged: checked
                                      ? (_) => onToggleAction(entry.key)
                                      : null,
                                  activeColor: AppColors.accent,
                                  checkColor: AppColors.accentInk,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          fontSize: 12.5, color: AppColors.tx3),
                                      children: [
                                        TextSpan(
                                          text: '${entry.value.itemType}  ',
                                          style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.tx4,
                                              letterSpacing: 0.4),
                                        ),
                                        TextSpan(
                                          text: entry.value.title,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.tx),
                                        ),
                                        if (entry.value.detail != null)
                                          TextSpan(text: ' — ${entry.value.detail}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
