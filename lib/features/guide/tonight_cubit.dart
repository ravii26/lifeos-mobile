import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/tonight.dart';
import '../../data/repositories/life_repository.dart';
import '../shell/life_cubit.dart' show LoadStatus;

class TonightState extends Equatable {
  final LoadStatus status;
  final Tonight? tonight;
  final GuideHistory? history;
  final NextStep? next;
  final bool busy;
  final String? error;

  const TonightState({
    this.status = LoadStatus.initial,
    this.tonight,
    this.history,
    this.next,
    this.busy = false,
    this.error,
  });

  TonightState copyWith({
    LoadStatus? status,
    Tonight? tonight,
    GuideHistory? history,
    NextStep? next,
    bool clearNext = false,
    bool? busy,
    String? error,
  }) =>
      TonightState(
        status: status ?? this.status,
        tonight: tonight ?? this.tonight,
        history: history ?? this.history,
        next: clearNext ? null : (next ?? this.next),
        busy: busy ?? this.busy,
        error: error,
      );

  @override
  List<Object?> get props => [status, tonight, history, next, busy, error];
}

/// Tonight's one thing: load, answer, swap, and "one more?". Every change
/// reschedules the nightly nudge so the notification always matches.
class TonightCubit extends Cubit<TonightState> {
  final LifeRepository _repo;
  StreamSubscription<void>? _answeredSub;

  TonightCubit(this._repo) : super(const TonightState()) {
    _answeredSub = NotificationService.instance.answered.listen((_) => load());
  }

  bool _nudgeSynced = false;

  Future<void> load() async {
    if (state.tonight == null) emit(state.copyWith(status: LoadStatus.loading));
    try {
      // The server holds the nightly nudge choice (it can be set from chat
      // or another device); pull it once per session before scheduling.
      if (!_nudgeSynced) {
        await NotificationService.instance.setNightlyTime(await _repo.nightlyNudge());
        _nudgeSynced = true;
      }
      final results = await Future.wait([_repo.guideTonight(), _repo.guideHistory()]);
      final tonight = results[0] as Tonight;
      emit(state.copyWith(
        status: LoadStatus.ready,
        tonight: tonight,
        history: results[1] as GuideHistory,
      ));
      await NotificationService.instance.scheduleNightly(tonight);
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  Future<void> respond(String status, {String? reason}) async {
    final c = state.tonight?.commitment;
    if (c == null) return;
    emit(state.copyWith(busy: true));
    try {
      final answered = await _repo.guideRespond(status, reason: reason, date: c.date);
      _lastUndo = answered.activityId;
      await load();
      if (status != 'SKIPPED') await _loadNext();
    } on QueuedOfflineException {
      // Saved for later: show it as answered now; it syncs when back online.
      final t = state.tonight!;
      emit(state.copyWith(
        tonight: Tonight(date: t.date, commitment: c.withStatus(status), missedNights: t.missedNights),
        error: "Saved offline. It'll sync when you're back online.",
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> swap() async {
    emit(state.copyWith(busy: true));
    try {
      final tonight = await _repo.guideSwap();
      emit(state.copyWith(tonight: tonight));
      await NotificationService.instance.scheduleNightly(tonight);
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  Future<void> _loadNext() async {
    try {
      final next = await _repo.guideNext();
      emit(next == null ? state.copyWith(clearNext: true) : state.copyWith(next: next));
    } on ApiException {
      emit(state.copyWith(clearNext: true));
    }
  }

  /// Finishes the "one more" step through the normal task/habit endpoints,
  /// then offers the one after it.
  Future<void> completeNext() async {
    final n = state.next;
    if (n == null) return;
    emit(state.copyWith(busy: true));
    try {
      if (n.sourceType == 'HABIT') {
        await _repo.logHabit(n.sourceId);
      } else {
        await _repo.completeTask(n.sourceId);
      }
      await _loadNext();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  void dismissNext() => emit(state.copyWith(clearNext: true));

  String? _lastUndo;

  /// True right after an answer made in this session, so the card can offer Undo.
  bool get canUndo => _lastUndo != null;

  Future<void> undoLast() async {
    final id = _lastUndo;
    if (id == null) return;
    emit(state.copyWith(busy: true));
    try {
      await _repo.undo(id);
      _lastUndo = null;
      emit(state.copyWith(clearNext: true));
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  @override
  Future<void> close() {
    _answeredSub?.cancel();
    return super.close();
  }
}
