import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/decision.dart';
import '../../data/repositories/life_repository.dart';
import '../shell/life_cubit.dart' show LoadStatus;

class DecisionsState extends Equatable {
  final LoadStatus status;
  final DecisionResult? result;
  final String? error;

  const DecisionsState({
    this.status = LoadStatus.initial,
    this.result,
    this.error,
  });

  DecisionsState copyWith({
    LoadStatus? status,
    DecisionResult? result,
    String? error,
  }) =>
      DecisionsState(
        status: status ?? this.status,
        result: result ?? this.result,
        error: error,
      );

  @override
  List<Object?> get props => [status, result, error];
}

/// Shared `/decisions/now` fetch, so the "What now" screen and the companion
/// overlay always agree on the same briefing instead of each doing their own
/// independent, potentially time-skewed fetch.
class DecisionsCubit extends Cubit<DecisionsState> {
  final LifeRepository _repo;
  DecisionsCubit(this._repo) : super(const DecisionsState());

  Future<void> refresh() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final r = await _repo.decisionsNow();
      emit(state.copyWith(status: LoadStatus.ready, result: r));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  /// Drops cached state on sign-out so a different user signing in on the
  /// same device never briefly sees the previous user's briefing.
  void reset() => emit(const DecisionsState());
}
