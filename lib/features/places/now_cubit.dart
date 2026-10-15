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
  final String sourceType; // TASK | HABIT | PROJECT (a session towards a weekly target)
  final String sourceId;
  final String title;
  final int minutes;
  final bool smaller;
  final String minimum;
  final String why;
  final int? count; // a counted session: "apply to 2 jobs"
  const NowOption(this.sourceType, this.sourceId, this.title, this.minutes, this.smaller, this.minimum, this.why, [this.count]);

  factory NowOption.fromJson(Json j) => NowOption(
        asString(j['sourceType'], 'TASK'),
        asString(j['sourceId']),
        asString(j['title']),
        asInt(j['minutes']),
        asBool(j['smaller']),
        asString(j['minimum']),
        asString(j['why']),
        j['count'] == null ? null : asInt(j['count']),
      );

  @override
  List<Object?> get props => [sourceType, sourceId, title, minutes, smaller, count];
}

/// The brain's honest "not now" / "better way" (plan 16, Layer 4).
class NowAdvice extends Equatable {
  final String kind; // LATE_NIGHT | KEEPS_SLIPPING | SAVES_PILING
  final String message;
  final String? sourceType;
  final String? sourceId;
  final List<(String label, String choice)> actions;
  const NowAdvice(this.kind, this.message, this.sourceType, this.sourceId, this.actions);

  static NowAdvice? fromJson(Object? v) {
    if (v is! Json) return null;
    return NowAdvice(
      asString(v['kind']),
      asString(v['message']),
      asStringOrNull(v['sourceType']),
      asStringOrNull(v['sourceId']),
      ((v['actions'] as List?) ?? const []).whereType<Json>().map((a) => (asString(a['label']), asString(a['choice']))).toList(),
    );
  }

  @override
  List<Object?> get props => [kind, message, sourceId];
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
  final NowAdvice? advice;
  final bool focus; // a deadline has taken the rest of today (message says what waits)
  final bool lowEnergy; // "low energy today": smallest versions until tomorrow

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
    this.advice,
    this.focus = false,
    this.lowEnergy = false,
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
    bool clearAdvice = false,
    bool? lowEnergy,
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
        advice: clearAdvice ? null : advice,
        focus: focus,
        lowEnergy: lowEnergy ?? this.lowEnergy,
      );

  @override
  List<Object?> get props => [status, kind, message, options, index, busy, error, note, undoId, prep, advice, focus, lowEnergy];
}

/// The card on Now: the right thing for right now, with Done / Smaller / Not now.
/// Answers work offline (they queue); the last known card is shown when the
/// server cannot be reached.
class NowCubit extends Cubit<NowState> {
  final LifeRepository _repo;
  NowCubit(this._repo) : super(const NowState());

  // "Low energy" holds for the rest of the day it was said on.
  DateTime? _lowEnergyDay;
  bool get _lowToday {
    final d = _lowEnergyDay;
    final n = DateTime.now();
    return d != null && d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> load({bool smallest = false, int? minutes}) async {
    if (state.options.isEmpty) emit(state.copyWith(status: NowStatus.loading));
    try {
      final data = await _repo.now(smallest: smallest || _lowToday, minutes: minutes);
      emit(NowState(
        status: NowStatus.ready,
        kind: asString(data['kind'], 'PICK'),
        message: asString(data['message']),
        options: ((data['options'] as List?) ?? const []).whereType<Json>().map(NowOption.fromJson).toList(),
        prep: ((data['prep'] as List?) ?? const []).whereType<Json>().map((p) => asString(p['prepare'])).where((p) => p.isNotEmpty).toList(),
        advice: NowAdvice.fromJson(data['advice']),
        focus: data['focus'] is Json,
        undoId: state.undoId,
        lowEnergy: _lowToday,
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
      final id = await _repo.respondNow(o.sourceType, o.sourceId, action, minutes: o.minutes, count: o.count);
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

  /// "Low energy today": smallest versions for the rest of the day, no questions.
  Future<void> lowEnergy() async {
    _lowEnergyDay = DateTime.now();
    await load();
  }

  /// One of the advice buttons. MINIMUM_NOW counts the 2-minute version now;
  /// ANYWAY just hides the advice; OPEN_SAVES is handled by the screen.
  Future<void> adviceChoice(String choice) async {
    final a = state.advice;
    if (a == null || state.busy) return;
    if (choice == 'ANYWAY') {
      emit(state.copyWith(clearAdvice: true));
      return;
    }
    if (choice == 'OPEN_SAVES') {
      emit(state.copyWith(clearAdvice: true, note: 'Your saves are in Notes, under "Saves waiting for a decision". Pick one for this week.'));
      return;
    }
    if (choice == 'MINIMUM_NOW') {
      emit(state.copyWith(clearAdvice: true));
      await _answer('MINIMUM');
      return;
    }
    if (a.sourceType == null || a.sourceId == null) return;
    emit(state.copyWith(busy: true, clearUndo: true));
    try {
      final r = await _repo.nowAdvice(a.sourceType!, a.sourceId!, choice);
      placesRefresh.value++;
      emit(state.copyWith(busy: false, clearAdvice: true, undoId: asStringOrNull(r['activityId'])));
      await load();
      // The receipt stays under the new card ("Clean the desk moved to Saturday").
      emit(state.copyWith(note: asString(r['message'])));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

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
