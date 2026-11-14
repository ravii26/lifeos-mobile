import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart' show QueuedOfflineException;
import '../../core/api/api_exception.dart';
import '../../core/widget/widget_sync_service.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import 'now_extras.dart';

/// Bumped whenever something is done, skipped or changed, so Plan and You
/// reload the next time they are looked at.
final ValueNotifier<int> placesRefresh = ValueNotifier<int>(0);

/// Chat says "low energy today" (true) or "back to full energy" (false); the Now card follows.
final ValueNotifier<bool?> lowEnergyRequest = ValueNotifier<bool?>(null);

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
  final String? detail; // the steps (a plan session's exercises), for "Not clear what to do"
  // The area it belongs to, when the server says (lets the completion moment move that area's ring).
  final String? areaId;
  final String? areaName;
  const NowOption(this.sourceType, this.sourceId, this.title, this.minutes, this.smaller, this.minimum, this.why,
      [this.count, this.detail, this.areaId, this.areaName]);

  factory NowOption.fromJson(Json j) => NowOption(
        asString(j['sourceType'], 'TASK'),
        asString(j['sourceId']),
        asString(j['title']),
        asInt(j['minutes']),
        asBool(j['smaller']),
        asString(j['minimum']),
        asString(j['why']),
        j['count'] == null ? null : asInt(j['count']),
        asStringOrNull(j['detail']),
        asStringOrNull(j['areaId']),
        asStringOrNull(j['areaName']),
      );

  @override
  List<Object?> get props => [sourceType, sourceId, title, minutes, smaller, count];
}

/// Coming back after a week or more (decisions log #14): what got in the way
/// last time, the honest record, and what can be offered (a light week,
/// moving sessions to the time of day that didn't keep failing, a re-setup).
class NowRestart extends Equatable {
  final String level; // WEEK | LONG | VERY_LONG
  final int gapDays;
  final String? insight;
  final String? suggestBlock; // MORNING | EVENING
  final String? record;
  final bool canLightWeek;
  final bool resetup;
  const NowRestart(this.level, this.gapDays, this.insight, this.suggestBlock, this.record, this.canLightWeek, this.resetup);

  static NowRestart? fromJson(Object? v) {
    if (v is! Json) return null;
    final i = v['insight'];
    return NowRestart(
      asString(v['level']),
      asInt(v['gapDays']),
      i is Json ? asStringOrNull(i['line']) : null,
      i is Json ? asStringOrNull(i['suggestBlock']) : null,
      asStringOrNull(v['record']),
      asBool(v['canLightWeek']),
      asBool(v['resetup']),
    );
  }

  @override
  List<Object?> get props => [level, gapDays, insight, suggestBlock, record, canLightWeek, resetup];
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
  final NowExtras extras; // counts, timer, routine, meal, watch later (Phase D)
  final bool restedToday; // "I'm finished for today": nothing more is suggested
  final bool welcomeBack; // back after a gap: no catching up asked for
  final bool sick; // sick mode: nothing is asked of them today
  final bool fromSaved; // no connection: this is the last card the phone kept
  final String? season; // "Switch & Shape · week 2 of 10"; null before the first season
  final NowRestart? restart; // set after a week or more away

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
    this.extras = NowExtras.empty,
    this.restedToday = false,
    this.welcomeBack = false,
    this.sick = false,
    this.fromSaved = false,
    this.season,
    this.restart,
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
    NowExtras? extras,
    bool? fromSaved,
    bool clearRestart = false,
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
        extras: extras ?? this.extras,
        restedToday: restedToday,
        welcomeBack: welcomeBack,
        sick: sick,
        fromSaved: fromSaved ?? this.fromSaved,
        season: season,
        restart: clearRestart ? null : restart,
      );

  @override
  List<Object?> get props => [status, kind, message, options, index, busy, error, note, undoId, prep, advice, focus, lowEnergy, extras, restedToday, welcomeBack, sick, fromSaved, season, restart];
}

/// The card on Now: the right thing for right now, with Done / Smaller / Not now.
/// Answers work offline (they queue); the last known card is shown when the
/// server cannot be reached.
class NowCubit extends Cubit<NowState> {
  final LifeRepository _repo;
  NowCubit(this._repo) : super(const NowState()) {
    lowEnergyRequest.addListener(_onLowEnergyRequest);
  }

  void _onLowEnergyRequest() {
    final on = lowEnergyRequest.value;
    if (on == null) return;
    lowEnergyRequest.value = null;
    _lowEnergyDay = on ? DateTime.now() : null;
    load();
  }

  @override
  Future<void> close() {
    lowEnergyRequest.removeListener(_onLowEnergyRequest);
    return super.close();
  }

  // "Low energy" holds for the rest of the day it was said on.
  DateTime? _lowEnergyDay;
  bool get _lowToday {
    final d = _lowEnergyDay;
    final n = DateTime.now();
    return d != null && d.year == n.year && d.month == n.month && d.day == n.day;
  }

  // "I'm finished for today" holds for the rest of that day, unless they ask for more.
  DateTime? _restDay;
  bool get _restToday {
    final d = _restDay;
    final n = DateTime.now();
    return d != null && d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> finishForToday() async {
    _restDay = DateTime.now();
    await load();
  }

  Future<void> resumeToday() async {
    _restDay = null;
    await load();
  }

  Future<void> load({bool smallest = false, int? minutes}) async {
    if (_restToday) {
      emit(NowState(status: NowStatus.ready, kind: 'REST', undoId: state.undoId, restedToday: true, extras: state.extras));
      return;
    }
    var showingEarly = false;
    if (state.options.isEmpty) {
      // A recent copy (today, under 3 h) shows at once, so the first open never
      // waits on a waking server. The live answer replaces it a moment later.
      final saved = minutes == null ? await _repo.nowSaved(smallest: smallest || _lowToday) : null;
      if (saved != null) {
        emit(_stateFrom(saved, fromSaved: false));
        showingEarly = true;
      } else {
        emit(state.copyWith(status: NowStatus.loading));
      }
    }
    try {
      final data = await _repo.now(smallest: smallest || _lowToday, minutes: minutes);
      // The home-screen widget shows the same pick (best effort, never blocks Now).
      WidgetSyncService.instance?.pushNow(data).catchError((_) {});
      emit(_stateFrom(data, fromSaved: _repo.showingSaved));
    } on ApiException catch (e) {
      if (showingEarly) {
        // Keep the card; just say it's the phone's copy. No error toast on top.
        emit(state.copyWith(fromSaved: true));
        return;
      }
      emit(state.copyWith(status: state.options.isEmpty ? NowStatus.error : NowStatus.ready, error: e.message));
    }
  }

  NowState _stateFrom(Json data, {required bool fromSaved}) => NowState(
        status: NowStatus.ready,
        kind: asString(data['kind'], 'PICK'),
        message: asString(data['message']),
        options: ((data['options'] as List?) ?? const []).whereType<Json>().map(NowOption.fromJson).toList(),
        prep: ((data['prep'] as List?) ?? const []).whereType<Json>().map((p) => asString(p['prepare'])).where((p) => p.isNotEmpty).toList(),
        advice: NowAdvice.fromJson(data['advice']),
        focus: data['focus'] is Json,
        undoId: state.undoId,
        lowEnergy: _lowToday,
        extras: _extrasOf(data),
        welcomeBack: asBool(data['welcomeBack']),
        sick: asString(data['mode']) == 'SICK',
        fromSaved: fromSaved,
        season: asStringOrNull(data['season']),
        // Answered (or dismissed) today: not asked again on every reload.
        restart: _restartAnsweredToday ? null : NowRestart.fromJson(data['restart']),
      );

  DateTime? _restartAnswered;
  bool get _restartAnsweredToday {
    final a = _restartAnswered, now = DateTime.now();
    return a != null && a.year == now.year && a.month == now.month && a.day == now.day;
  }

  /// "Keep as is": the restart card goes away for today, nothing changes.
  void dismissRestart() {
    _restartAnswered = DateTime.now();
    emit(state.copyWith(clearRestart: true));
  }

  /// After a gap: a light week and/or sessions moved to the time of day that
  /// didn't keep failing. Offered on the card, never done silently; Undo keeps it reversible.
  Future<void> restartPlan({bool lightWeek = false, String? switchTo}) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, clearUndo: true));
    try {
      final r = await _repo.restartPlan(lightWeek: lightWeek, switchTo: switchTo);
      _restartAnswered = DateTime.now();
      placesRefresh.value++;
      emit(state.copyWith(busy: false, undoId: r.activityId, clearRestart: true));
      await load();
      emit(state.copyWith(note: r.message, clearRestart: true));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  // ---- Phase D: the quiet lines under the pick ----

  final Set<String> _hiddenLater = {};

  NowExtras _extrasOf(Json data) {
    final e = NowExtras.fromJson(data);
    final l = e.later;
    if (l == null || !_hiddenLater.contains(l.id)) return e;
    return NowExtras(counts: e.counts, timer: e.timer, routine: e.routine, meal: e.meal);
  }

  Future<void> _act(Future<void> Function() run) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      await run();
      placesRefresh.value++;
      await load();
    } on QueuedOfflineException {
      emit(state.copyWith(busy: false, note: 'Saved for when you are online.'));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  /// "Stop timer" goes through chat, so the same rules apply (a forgotten timer asks first).
  Future<void> stopTimer() => _act(() async {
        await _repo.chat('stop timer', const []);
      });
  Future<void> addCount(String habitId) => _act(() async {
        await _repo.addCount(habitId);
      });
  Future<void> tickStep(String noteId, String item, bool done) => _act(() async {
        await _repo.tickNote(noteId, item, done);
      });
  Future<void> resetRoutine(String noteId) => _act(() async {
        await _repo.resetNote(noteId);
      });
  Future<void> watched(String saveId) => _act(() async {
        await _repo.markSaveWatched(saveId);
      });

  /// "Not now" on the Watch later line: it stays out of the way until the app is opened again.
  void hideLater(String id) {
    _hiddenLater.add(id);
    load();
  }

  /// True when the answer was saved, or queued to be saved once back online.
  Future<bool> _answer(String action, {bool reload = true, String? reason, int? minutes}) async {
    final o = state.current;
    if (o == null || state.busy) return false;
    emit(state.copyWith(busy: true, clearUndo: true));
    try {
      final id = await _repo.respondNow(o.sourceType, o.sourceId, action, minutes: minutes ?? o.minutes, count: o.count, reason: reason);
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
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
      return false;
    }
    if (reload) await load();
    return true;
  }

  /// [minutes]: the time actually given, when a focus session measured it.
  /// It only counts towards a weekly time target (a goal session); a to-do or
  /// routine is simply done.
  Future<bool> done({int? minutes}) => _answer('DONE', minutes: minutes);

  /// From the Not now choices: TOMORROW, WEEKEND or LET_GO, each undoable.
  /// [reason]: what got in the way ("no time", "forgot"), kept so a restart can learn from it.
  Future<void> moveCurrent(String choice, {String? reason}) async {
    final o = state.current;
    if (o == null || state.busy) return;
    emit(state.copyWith(busy: true, clearUndo: true));
    try {
      final r = await _repo.nowAdvice(o.sourceType, o.sourceId, choice, reason: reason);
      placesRefresh.value++;
      emit(state.copyWith(busy: false, undoId: asStringOrNull(r['activityId'])));
      await load();
      emit(state.copyWith(note: asString(r['message'])));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  /// "Not now": log it (with no guilt) and show the next option, if there is one.
  Future<void> notNow({String? reason}) async {
    final hasNext = state.index + 1 < state.options.length;
    await _answer('SKIP', reload: !hasNext, reason: reason);
    if (hasNext) emit(state.copyWith(index: state.index + 1));
  }

  /// "Smaller": the same kind of thing, as small as it gets. Not a failure, not logged as a skip.
  Future<void> smaller() => load(smallest: true);

  /// "Low energy today": smallest versions for the rest of the day, no questions.
  Future<void> lowEnergy() async {
    _lowEnergyDay = DateTime.now();
    await load();
  }

  /// Feeling better after a low-energy day: back to normal suggestions.
  Future<void> endLowEnergy() async {
    _lowEnergyDay = null;
    await load();
  }

  /// Leaving sick mode. Waits for the server, because the next card depends on it.
  Future<void> feelingBetter() async {
    try {
      await _repo.setMode('NORMAL');
      placesRefresh.value++;
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
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
