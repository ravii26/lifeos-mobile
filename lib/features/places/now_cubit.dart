import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';

/// Bumped whenever something is done, skipped or changed, so Plan and You
/// reload the next time they are looked at.
final ValueNotifier<int> placesRefresh = ValueNotifier<int>(0);

/// One thing the right-now engine suggests, sized for the time there is.
class NowOption extends Equatable {
  final String sourceType; // TASK | HABIT
  final String sourceId;
  final String title;
  final int minutes;
  final bool smaller;
  final String minimum;
  final String why;
  const NowOption(this.sourceType, this.sourceId, this.title, this.minutes, this.smaller, this.minimum, this.why);

  factory NowOption.fromJson(Json j) => NowOption(
        asString(j['sourceType'], 'TASK'),
        asString(j['sourceId']),
        asString(j['title']),
        asInt(j['minutes']),
        asBool(j['smaller']),
        asString(j['minimum']),
        asString(j['why']),
      );

  @override
  List<Object?> get props => [sourceType, sourceId, title, minutes, smaller];
}

enum NowStatus { loading, ready, error }

class NowState extends Equatable {
  final NowStatus status;
  final String kind; // PICK | REST | EMPTY
  final String message;
  final List<NowOption> options;
  final int index; // which option is showing ("Not now" moves on)
  final bool busy;
  final String? error;
  final String? note; // a calm line after an action, e.g. "Saved offline"
  final String? undoId;
  final List<String> prep; // evening prep steps due now

  const NowState({
    this.status = NowStatus.loading,
    this.kind = 'PICK',
    this.message = '',
    this.options = const [],
    this.index = 0,
    this.busy = false,
    this.error,
    this.note,
    this.undoId,
    this.prep = const [],
  });

  NowOption? get current => index < options.length ? options[index] : null;
  List<NowOption> get later => index + 1 < options.length ? options.sublist(index + 1).take(2).toList() : const [];

  NowState copyWith({
    NowStatus? status,
    String? kind,
    String? message,
    List<NowOption>? options,
    int? index,
    bool? busy,
    String? error,
    String? note,
    String? undoId,
    List<String>? prep,
    bool clearUndo = false,
  }) =>
      NowState(
        status: status ?? this.status,
        kind: kind ?? this.kind,
        message: message ?? this.message,
        options: options ?? this.options,
        index: index ?? this.index,
        busy: busy ?? this.busy,
        error: error,
        note: note,
        undoId: clearUndo ? null : (undoId ?? this.undoId),
        prep: prep ?? this.prep,
      );

  @override
  List<Object?> get props => [status, kind, message, options, index, busy, error, note, undoId, prep];
}

/// The card on Now: the right thing for right now, with Done / Smaller / Not now.
/// Answers work offline (they queue); the last known card is shown when the
/// server cannot be reached.
class NowCubit extends Cubit<NowState> {
  final LifeRepository _repo;
  NowCubit(this._repo) : super(const NowState());

  Future<void> load({bool smallest = false, int? minutes}) async {
    if (state.options.isEmpty) emit(state.copyWith(status: NowStatus.loading));
    try {
      final data = await _repo.now(smallest: smallest, minutes: minutes);
      emit(NowState(
        status: NowStatus.ready,
        kind: asString(data['kind'], 'PICK'),
        message: asString(data['message']),
        options: ((data['options'] as List?) ?? const []).whereType<Json>().map(NowOption.fromJson).toList(),
        prep: ((data['prep'] as List?) ?? const []).whereType<Json>().map((p) => asString(p['prepare'])).where((p) => p.isNotEmpty).toList(),
        undoId: state.undoId,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: state.options.isEmpty ? NowStatus.error : NowStatus.ready, error: e.message));
    }
  }

  Future<void> _answer(String action, {bool reload = true}) async {
    final o = state.current;
    if (o == null || state.busy) return;
    emit(state.copyWith(busy: true, clearUndo: true));
    try {
      final id = await _repo.respondNow(o.sourceType, o.sourceId, action);
      placesRefresh.value++;
      emit(state.copyWith(busy: false, undoId: id));
    } on QueuedOfflineException {
      // Saved for later: it syncs when you are back online. The card moves on
      // by itself (there is no server to ask) and keeps the calm note.
      placesRefresh.value++;
      final rest = [...state.options]..removeAt(state.index);
      emit(state.copyWith(
        busy: false,
        options: rest,
        index: state.index >= rest.length ? 0 : state.index,
        note: "Saved offline. It'll sync when you're back online.",
      ));
      return;
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
      return;
    }
    if (reload) await load();
  }

  Future<void> done() => _answer('DONE');

  /// "Not now": log it (with no guilt) and show the next option, if there is one.
  Future<void> notNow() async {
    final hasNext = state.index + 1 < state.options.length;
    await _answer('SKIP', reload: !hasNext);
    if (hasNext) emit(state.copyWith(index: state.index + 1));
  }

  /// "Smaller": the same kind of thing, as small as it gets. Not a failure, not logged as a skip.
  Future<void> smaller() => load(smallest: true);

  Future<void> undo() async {
    final id = state.undoId;
    if (id == null) return;
    try {
      await _repo.undo(id);
      placesRefresh.value++;
      emit(state.copyWith(clearUndo: true));
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
