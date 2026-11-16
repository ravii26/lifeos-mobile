import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../areas/areas_overview.dart' show AreaStep;
import '../areas/rename_sheet.dart';
import '../areas/step_sheet.dart';
import '../areas/when_picker.dart' show StepWhen;
import '../chat/chat_cubit.dart';

/// The line under a saved thing that says where it came from, or null when the
/// server did not say (an older server, or something Ally did not create).
String? sourceLine(ChatAction a) {
  if (!a.isCreation || a.undone || a.origin == null) return null;
  if (a.origin == 'IDEA') {
    final forWhat = a.ideaFor == null ? '' : ' for “${a.ideaFor}”';
    final why = a.reason == null ? '' : ': ${a.reason}';
    return 'Ally’s idea$forWhat$why';
  }
  return a.said == null ? null : 'From what you said: “${a.said}”';
}

/// Tap a saved thing in Talk to change it. A to-do opens the same sheet as on
/// an area page (name, length, when, smaller version, let go); everything else
/// can be renamed or let go. Only what was changed is sent, so the length, the
/// energy and the smaller version Ally chose are never wiped by an untouched field.
Future<void> editReceipt(
  BuildContext themed,
  ChatCubit cubit,
  int messageIndex,
  int actionIndex,
  ChatAction a, {
  LifeRepository? repo,
}) async {
  if (a.id == null || a.undone || !a.isCreation) return;
  LifeRepository api() => repo ?? getIt<LifeRepository>();
  if (a.type == 'TASK_ADDED') {
    final step = AreaStep(a.id!, a.text, null);
    final answer = await showAllySheet<StepAnswer>(themed, builder: (_) => StepSheet(step: step, areaName: sourceLine(a) ?? 'Saved from Talk'));
    if (answer == null || !themed.mounted) return;
    switch (answer) {
      case StepLetGo():
        await cubit.undoAction(messageIndex, actionIndex);
      case StepSave(:final title, :final minutes, :final energy, :final smaller, when: final at):
        try {
          final r = await api().editStep(
            a.id!,
            title: title == a.text ? null : title,
            minutes: minutes,
            energy: energy == 'NORMAL' ? null : energy,
            smaller: smaller.isEmpty ? null : smaller,
            when: at == StepWhen.of(step) ? null : at.toJson(),
          );
          await cubit.retitle(messageIndex, actionIndex, title);
          if (!themed.mounted) return;
          final undoId = r.activityId;
          final was = a.text;
          showAllyToast(themed, r.message, onUndo: undoId == null
              ? null
              : () async {
                  try {
                    await api().undo(undoId);
                    await cubit.retitle(messageIndex, actionIndex, was);
                  } on ApiException catch (e) {
                    if (themed.mounted) showAllyToast(themed, e.message);
                  }
                });
        } on ApiException catch (e) {
          if (themed.mounted) showAllyToast(themed, e.message);
        }
    }
    return;
  }
  final what = switch (a.type) {
    'HABIT_ADDED' => 'routine',
    'PROJECT_ADDED' => 'project',
    'NOTE_ADDED' => 'note',
    _ => 'reminder',
  };
  final answer = await showAllySheet<EditAnswer>(
    themed,
    builder: (_) => RenameSheet(
      heading: 'Edit $what',
      name: a.text,
      letGoLabel: 'Undo this $what',
      letGoNote: 'Takes back what Ally just saved. You can also say it again your own way.',
    ),
  );
  if (answer == null || !themed.mounted) return;
  switch (answer) {
    case EditRename(:final name):
      await cubit.rename(messageIndex, actionIndex, name);
    case EditLetGo():
      await cubit.undoAction(messageIndex, actionIndex);
  }
}
