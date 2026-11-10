import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';

/// 90 → "1.5 hours". Rounded to the half hour: an estimate should look like one.
String hoursText(int minutes) {
  if (minutes < 60) return '$minutes minutes';
  final hours = (minutes / 30).round() / 2;
  final shown = hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString();
  return hours == 1 ? '1 hour' : '$shown hours';
}

class PileItem extends Equatable {
  final String sourceType; // TASK | HABIT | PROJECT
  final String sourceId;
  final String title;
  final int weeklyMinutes;
  final String? ageLine;
  final String? dueLine;
  final String needs;
  const PileItem(this.sourceType, this.sourceId, this.title, this.weeklyMinutes, this.ageLine, this.dueLine, this.needs);

  factory PileItem.fromJson(Json j) => PileItem(
        asString(j['sourceType'], 'TASK'),
        asString(j['sourceId']),
        asString(j['title']),
        asInt(j['weeklyMinutes']),
        asStringOrNull(j['ageLine']),
        asStringOrNull(j['dueLine']),
        asString(j['needs']),
      );

  @override
  List<Object?> get props => [sourceType, sourceId, title, weeklyMinutes];
}

enum PileDecision { keep, park, letGo }

class Decided extends Equatable {
  final PileItem item;
  final PileDecision decision;
  final String? activityId;
  const Decided(this.item, this.decision, this.activityId);

  @override
  List<Object?> get props => [item, decision, activityId];
}

enum ShrinkStage { loading, error, empty, summary, deciding, result }

class ShrinkState extends Equatable {
  final ShrinkStage stage;
  final List<PileItem> items;
  final int count; // everything on the list; items may be the first part of it
  final int weeklyMinutes;
  final int freeMinutes;
  final String parkLabel;
  final bool canLetGo;
  final List<Decided> decided;
  final bool busy;
  final String? error;

  const ShrinkState({
    this.stage = ShrinkStage.loading,
    this.items = const [],
    this.count = 0,
    this.weeklyMinutes = 0,
    this.freeMinutes = 0,
    this.parkLabel = '',
    this.canLetGo = true,
    this.decided = const [],
    this.busy = false,
    this.error,
  });

  PileItem? get current => decided.length < items.length ? items[decided.length] : null;

  List<PileItem> _with(PileDecision d) => [for (final e in decided) if (e.decision == d) e.item];
  List<PileItem> get kept => _with(PileDecision.keep);
  List<PileItem> get parked => _with(PileDecision.park);
  List<PileItem> get letGo => _with(PileDecision.letGo);

  /// What is still asked of the week after parking and letting go.
  int get remainingMinutes {
    final removed = [...parked, ...letGo].fold<int>(0, (s, i) => s + i.weeklyMinutes);
    return weeklyMinutes - removed;
  }

  bool get fits => remainingMinutes <= freeMinutes;

  ShrinkState copyWith({
    ShrinkStage? stage,
    List<PileItem>? items,
    int? count,
    int? weeklyMinutes,
    int? freeMinutes,
    String? parkLabel,
    bool? canLetGo,
    List<Decided>? decided,
    bool? busy,
    String? error,
  }) =>
      ShrinkState(
        stage: stage ?? this.stage,
        items: items ?? this.items,
        count: count ?? this.count,
        weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
        freeMinutes: freeMinutes ?? this.freeMinutes,
        parkLabel: parkLabel ?? this.parkLabel,
        canLetGo: canLetGo ?? this.canLetGo,
        decided: decided ?? this.decided,
        busy: busy ?? this.busy,
        error: error,
      );

  @override
  List<Object?> get props => [stage, items, count, weeklyMinutes, freeMinutes, parkLabel, canLetGo, decided, busy, error];
}

/// One pass through the list: see the honest number, then keep, park or let go, one at a time.
class ShrinkCubit extends Cubit<ShrinkState> {
  final LifeRepository _repo;
  final bool lowEnergy;
  ShrinkCubit(this._repo, {this.lowEnergy = false}) : super(const ShrinkState());

  Future<void> load() async {
    emit(const ShrinkState());
    try {
      final data = await _repo.pile();
      final items = ((data['items'] as List?) ?? const []).whereType<Json>().map(PileItem.fromJson).toList();
      emit(ShrinkState(
        stage: items.isEmpty ? ShrinkStage.empty : ShrinkStage.summary,
        items: items,
        count: asInt(data['count']),
        weeklyMinutes: asInt(data['weeklyMinutes']),
        freeMinutes: asInt(data['freeMinutes']),
        parkLabel: asString(data['parkLabel']),
        canLetGo: asBool(data['canLetGo']) && !lowEnergy,
      ));
    } on ApiException catch (e) {
      emit(ShrinkState(stage: ShrinkStage.error, error: e.message));
    }
  }

  void begin() => emit(state.copyWith(stage: ShrinkStage.deciding));

  void _record(Decided d) {
    final decided = [...state.decided, d];
    emit(state.copyWith(decided: decided, busy: false, stage: decided.length >= state.items.length ? ShrinkStage.result : ShrinkStage.deciding));
  }

  void keep() {
    final item = state.current;
    if (item == null || state.busy) return;
    _record(Decided(item, PileDecision.keep, null));
  }

  Future<void> park() => _decide(PileDecision.park, 'PARK');
  Future<void> letGo() => _decide(PileDecision.letGo, 'LET_GO');

  Future<void> _decide(PileDecision decision, String word) async {
    final item = state.current;
    if (item == null || state.busy) return;
    emit(state.copyWith(busy: true));
    try {
      final r = await _repo.decidePile(item.sourceType, item.sourceId, word);
      _record(Decided(item, decision, asStringOrNull(r['activityId'])));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  /// Back one card, taking that decision back with it.
  Future<void> back() async {
    if (state.busy) return;
    if (state.decided.isEmpty) {
      emit(state.copyWith(stage: ShrinkStage.summary));
      return;
    }
    final last = state.decided.last;
    emit(state.copyWith(busy: true));
    try {
      if (last.activityId != null) await _repo.undo(last.activityId!);
      emit(state.copyWith(decided: state.decided.sublist(0, state.decided.length - 1), busy: false, stage: ShrinkStage.deciding));
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  /// Stop whenever: what was decided stays decided, the rest is simply untouched.
  void finishEarly() => emit(state.copyWith(stage: ShrinkStage.result));
}
