import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/onboarding.dart';
import '../../data/repositories/life_repository.dart';

const Object _keep = Object();

class OnboardingState extends Equatable {
  final bool extracting;
  final OnboardingExtraction? proposal;
  final String? error;
  final Set<String> checkedAreas;
  final Set<int> checkedActions;
  final bool creating;

  const OnboardingState({
    this.extracting = false,
    this.proposal,
    this.error,
    this.checkedAreas = const {},
    this.checkedActions = const {},
    this.creating = false,
  });

  OnboardingState copyWith({
    bool? extracting,
    Object? proposal = _keep,
    Object? error = _keep,
    Set<String>? checkedAreas,
    Set<int>? checkedActions,
    bool? creating,
  }) =>
      OnboardingState(
        extracting: extracting ?? this.extracting,
        proposal: proposal == _keep ? this.proposal : proposal as OnboardingExtraction?,
        error: error == _keep ? this.error : error as String?,
        checkedAreas: checkedAreas ?? this.checkedAreas,
        checkedActions: checkedActions ?? this.checkedActions,
        creating: creating ?? this.creating,
      );

  @override
  List<Object?> get props =>
      [extracting, proposal, error, checkedAreas, checkedActions, creating];
}

/// Result of [OnboardingCubit.createSelected] — a plain summary so the screen
/// can show one toast without the cubit reaching into UI concerns.
class OnboardingCreateResult {
  final int areasCreated;
  final int actionsCreated;
  final int failures;
  const OnboardingCreateResult(this.areasCreated, this.actionsCreated, this.failures);
}

/// Drives the cold-start onboarding intake: free text → AI-proposed starter
/// Areas/Goals/Habits/Tasks → user reviews/deselects → real rows get created
/// via the normal create endpoints. Mirrors [LibraryCubit]'s shape (a
/// self-contained Cubit holding [LifeRepository] directly) since this flow,
/// like Library's extract→review→accept, doesn't fit neatly into LifeCubit.
class OnboardingCubit extends Cubit<OnboardingState> {
  final LifeRepository _repo;
  OnboardingCubit(this._repo) : super(const OnboardingState());

  Future<void> extract(String text) async {
    emit(state.copyWith(extracting: true, error: null));
    try {
      final result = await _repo.extractOnboarding(text);
      if (result.areas.isEmpty) {
        emit(state.copyWith(
          extracting: false,
          error: "Couldn't find anything concrete in that — try adding a bit more detail",
        ));
        return;
      }
      emit(state.copyWith(
        extracting: false,
        proposal: result,
        checkedAreas: result.areas.map((a) => a.name).toSet(),
        checkedActions: {for (var i = 0; i < result.actions.length; i++) i},
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(extracting: false, error: e.message));
    }
  }

  void startOver() => emit(const OnboardingState());

  void toggleArea(String name) {
    final next = {...state.checkedAreas};
    next.contains(name) ? next.remove(name) : next.add(name);
    emit(state.copyWith(checkedAreas: next));
  }

  void toggleAction(int index) {
    final next = {...state.checkedActions};
    next.contains(index) ? next.remove(index) : next.add(index);
    emit(state.copyWith(checkedActions: next));
  }

  Future<OnboardingCreateResult?> createSelected() async {
    final proposal = state.proposal;
    if (proposal == null) return null;
    final areasToCreate = proposal.areas.where((a) => state.checkedAreas.contains(a.name)).toList();
    if (areasToCreate.isEmpty) {
      emit(state.copyWith(error: 'Pick at least one area'));
      return null;
    }

    emit(state.copyWith(creating: true, error: null));
    final nameToId = <String, String>{};
    var failures = 0;
    var actionsCreated = 0;

    for (final area in areasToCreate) {
      try {
        final created = await _repo.createArea(
          name: area.name,
          type: area.type,
          color: area.color,
          icon: area.icon,
        );
        nameToId[area.name] = created.id;
      } catch (_) {
        failures += 1;
      }
    }

    for (var i = 0; i < proposal.actions.length; i++) {
      if (!state.checkedActions.contains(i)) continue;
      final action = proposal.actions[i];
      final areaId = nameToId[action.areaName];
      if (areaId == null) continue; // its area was deselected or failed

      try {
        switch (action.itemType) {
          case 'GOAL':
            await _repo.createGoal(
              title: action.title,
              areaId: areaId,
              description: action.detail,
              priority: action.priority ?? 'MEDIUM',
              deadline: action.dueDate == null ? null : DateTime.tryParse(action.dueDate!),
            );
            break;
          case 'HABIT':
            await _repo.createHabit(
              title: action.title,
              areaId: areaId,
              description: action.detail,
              frequency: action.frequency ?? 'DAILY',
              targetMinutes: action.targetMinutes,
            );
            break;
          default:
            await _repo.createTask(
              title: action.title,
              areaId: areaId,
              priority: action.priority ?? 'MEDIUM',
              dueDate: action.dueDate == null ? null : DateTime.tryParse(action.dueDate!),
            );
        }
        actionsCreated += 1;
      } catch (_) {
        failures += 1;
      }
    }

    emit(state.copyWith(creating: false));
    return OnboardingCreateResult(areasToCreate.length, actionsCreated, failures);
  }
}
