import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/season.dart';
import '../../data/repositories/life_repository.dart';

/// The week's shape as setup asks it (decisions log #13: always ask about
/// Saturday and Sunday): which days are work days, and the hours incl. travel.
class WeekShape extends Equatable {
  final Set<int> workDays; // 0 = Sunday … 6 = Saturday
  final String start; // HH:mm
  final String end;
  final String wake;
  final String sleep;
  final bool changed;
  const WeekShape({required this.workDays, required this.start, required this.end, required this.wake, required this.sleep, this.changed = false});

  WeekShape copyWith({Set<int>? workDays, String? start, String? end}) =>
      WeekShape(workDays: workDays ?? this.workDays, start: start ?? this.start, end: end ?? this.end, wake: wake, sleep: sleep, changed: true);

  /// Read from GET /now/schedule: work days are the ones with an office block.
  static WeekShape fromSchedule(List<Map<String, dynamic>> days) {
    final work = <int>{};
    String? start, end, wake, sleep;
    for (final d in days) {
      final wd = (d['weekday'] as num?)?.toInt() ?? -1;
      final blocks = (d['blocks'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
      if (blocks.isEmpty) continue;
      final office = blocks.where((b) => b['block'] == 'OFFICE').firstOrNull;
      if (office != null) {
        work.add(wd);
        start ??= office['start'] as String?;
        end ??= office['end'] as String?;
        wake ??= blocks.first['start'] as String?;
        sleep ??= blocks.last['end'] as String?;
      }
    }
    wake ??= days.expand((d) => (d['blocks'] as List? ?? const []).whereType<Map<String, dynamic>>()).firstOrNull?['start'] as String?;
    sleep ??= '23:00';
    // The server writes midnight as 24:00; the basics call takes 00:00.
    String clock(String? v, String fallback) => v == null ? fallback : (v == '24:00' ? '00:00' : v);
    return WeekShape(workDays: work, start: clock(start, '09:00'), end: clock(end, '19:00'), wake: clock(wake, '07:00'), sleep: clock(sleep, '23:00'));
  }

  @override
  List<Object?> get props => [workDays, start, end, wake, sleep, changed];
}

/// Where an area goes this season. Maps to the area's tier on the server.
enum Place { focus, keepGoing, background, parked }

enum SetupStep { explain, week, areas, pick, name }

enum SetupStatus { loading, ready, error, saving, started }

/// An area with no goals, habits or to-dos yet still costs something; this is
/// the starting guess, shown as a guess and changeable.
const guessMinutes = 120;

class SeasonSetupState extends Equatable {
  final SetupStatus status;
  final SetupStep step;
  final SeasonData? data;
  final Map<String, int> minutes; // per area, editable
  final Set<String> guessed; // areas whose minutes are Ally's guess, not from their plans
  final Map<String, Place> places;
  final String? swapFor; // tapped into a full place: waiting for "which one makes room?"
  final Place? swapPlace;
  final String? error;
  final String? undoId;
  final WeekShape? week; // null until the day schedule loads (or it couldn't)

  const SeasonSetupState({
    this.status = SetupStatus.loading,
    this.step = SetupStep.explain,
    this.data,
    this.minutes = const {},
    this.guessed = const {},
    this.places = const {},
    this.swapFor,
    this.swapPlace,
    this.error,
    this.undoId,
    this.week,
  });

  int get neededMinutes => minutes.values.fold(0, (a, b) => a + b);
  int get freeMinutes => data?.freeMinutes ?? 0;
  List<String> idsIn(Place p) => [
        for (final a in data?.areas ?? const <SeasonArea>[])
          if (places[a.id] == p) a.id,
      ];
  String nameOf(String id) => data?.areas.firstWhere((a) => a.id == id, orElse: () => SeasonArea(id: id, name: id, tier: 'MAINTAIN', weeklyMinutes: 0)).name ?? id;

  SeasonSetupState copyWith({
    SetupStatus? status,
    SetupStep? step,
    SeasonData? data,
    Map<String, int>? minutes,
    Set<String>? guessed,
    Map<String, Place>? places,
    String? swapFor,
    Place? swapPlace,
    bool clearSwap = false,
    String? error,
    String? undoId,
    WeekShape? week,
  }) =>
      SeasonSetupState(
        status: status ?? this.status,
        step: step ?? this.step,
        data: data ?? this.data,
        minutes: minutes ?? this.minutes,
        guessed: guessed ?? this.guessed,
        places: places ?? this.places,
        swapFor: clearSwap ? null : (swapFor ?? this.swapFor),
        swapPlace: clearSwap ? null : (swapPlace ?? this.swapPlace),
        error: error,
        undoId: undoId ?? this.undoId,
        week: week ?? this.week,
      );

  @override
  List<Object?> get props => [status, step, data, minutes, guessed, places, swapFor, swapPlace, error, undoId, week];
}

/// Season setup (decisions log #7, canvas board P1·A): explainer (first time
/// only) → areas with hours → pick up to 2 focus → name it and start.
/// Ally pre-selects; the person only confirms or changes.
/// The next season as the season review pre-filled it.
typedef NextSeason = ({List<String> focusIds, List<String> keepGoingIds});

class SeasonSetupCubit extends Cubit<SeasonSetupState> {
  final LifeRepository _repo;

  /// Set when opened from the season review: start the next season from these picks.
  final NextSeason? next;
  SeasonSetupCubit(this._repo, {this.next}) : super(const SeasonSetupState());

  /// Changing a running season keeps it (same number, week and end). Only
  /// first setup and the season review start a new one.
  bool get editing => next == null && state.data?.season != null;

  /// The number this flow starts or saves.
  int get number => (state.data?.season?.number ?? 0) + (editing ? 0 : 1);

  String name = '';
  String endEvent = '';

  Future<void> load() async {
    emit(state.copyWith(status: SetupStatus.loading));
    try {
      final data = await _repo.season();
      final minutes = <String, int>{};
      final guessed = <String>{};
      for (final a in data.areas) {
        minutes[a.id] = a.weeklyMinutes > 0 ? a.weeklyMinutes : guessMinutes;
        if (a.weeklyMinutes == 0) guessed.add(a.id);
      }
      // A new season gets a new name and end; an edit keeps them.
      name = next == null ? (data.season?.name ?? '') : '';
      endEvent = next == null ? (data.season?.endEvent ?? '') : '';
      WeekShape? week;
      if (next != null || data.season == null) {
        try {
          week = WeekShape.fromSchedule(await _repo.daySchedule());
        } catch (_) {
          // Optional: without the schedule, setup goes straight to the areas.
        }
      }
      emit(state.copyWith(
        status: SetupStatus.ready,
        // The explainer is for the first season only; the week is asked at every new season.
        step: data.season == null ? SetupStep.explain : (week != null ? SetupStep.week : SetupStep.areas),
        week: week,
        data: data,
        minutes: minutes,
        guessed: guessed,
        places: next == null ? _suggest(data, minutes) : _fromNext(data, next!),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SetupStatus.error, error: e.message));
    }
  }

  /// Current places if a season exists; otherwise the 2 biggest areas in
  /// focus and the next 3 kept going, the rest in the background.
  static Map<String, Place> _suggest(SeasonData d, Map<String, int> minutes) {
    final out = <String, Place>{};
    final hasPlaces = d.areas.any((a) => a.tier == 'MAIN' || a.tier == 'SECONDARY' || a.tier == 'LATER');
    if (hasPlaces) {
      for (final a in d.areas) {
        out[a.id] = switch (a.tier) {
          'MAIN' => Place.focus,
          'SECONDARY' => Place.keepGoing,
          'LATER' => Place.parked,
          _ => Place.background,
        };
      }
      return out;
    }
    final byLoad = [...d.areas]..sort((a, b) => (minutes[b.id] ?? 0).compareTo(minutes[a.id] ?? 0));
    for (var i = 0; i < byLoad.length; i++) {
      out[byLoad[i].id] = i < d.maxFocus ? Place.focus : (i < d.maxFocus + d.maxKeepGoing ? Place.keepGoing : Place.background);
    }
    return out;
  }

  /// The review's picks; parked areas stay parked unless picked, the rest wait in the background.
  static Map<String, Place> _fromNext(SeasonData d, NextSeason n) => {
        for (final a in d.areas)
          a.id: n.focusIds.contains(a.id)
              ? Place.focus
              : n.keepGoingIds.contains(a.id)
                  ? Place.keepGoing
                  : (a.tier == 'LATER' ? Place.parked : Place.background),
      };

  void setWeek(WeekShape w) => emit(state.copyWith(week: w));

  /// "Looks right": saves the week only if it changed, then reloads the hours,
  /// since free time is what the areas are measured against.
  Future<void> confirmWeek() async {
    final w = state.week;
    if (w == null || !w.changed) return go(SetupStep.areas);
    emit(state.copyWith(status: SetupStatus.saving));
    try {
      final days = (w.workDays.toList()..sort());
      await _repo.setDayBasics(wake: w.wake, sleep: w.sleep, officeDays: days, officeStart: days.isEmpty ? null : w.start, officeEnd: days.isEmpty ? null : w.end);
      final data = await _repo.season();
      emit(state.copyWith(status: SetupStatus.ready, step: SetupStep.areas, data: data, week: WeekShape(workDays: w.workDays, start: w.start, end: w.end, wake: w.wake, sleep: w.sleep)));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SetupStatus.ready, error: e.message));
    }
  }

  void go(SetupStep step) => emit(state.copyWith(step: step, clearSwap: true));

  void setMinutes(String id, int delta) {
    final m = Map<String, int>.from(state.minutes);
    m[id] = ((m[id] ?? 0) + delta).clamp(0, 40 * 60);
    final g = Set<String>.from(state.guessed)..remove(id);
    emit(state.copyWith(minutes: m, guessed: g));
  }

  /// Puts an area in a place. A full Focus or Keep going is never overfilled:
  /// it asks which one makes room (decisions log #7).
  void place(String id, Place to) {
    final cap = to == Place.focus ? state.data?.maxFocus : (to == Place.keepGoing ? state.data?.maxKeepGoing : null);
    if (cap != null && state.places[id] != to && state.idsIn(to).length >= cap) {
      emit(state.copyWith(swapFor: id, swapPlace: to));
      return;
    }
    emit(state.copyWith(places: {...state.places, id: to}, clearSwap: true));
  }

  /// "Make room": [outId] moves to Parked (Focus) or the background (Keep going).
  void swap(String outId) {
    final inId = state.swapFor, to = state.swapPlace;
    if (inId == null || to == null) return;
    emit(state.copyWith(
      places: {...state.places, outId: to == Place.focus ? Place.parked : Place.background, inId: to},
      clearSwap: true,
    ));
  }

  void cancelSwap() => emit(state.copyWith(clearSwap: true));

  Future<void> start() async {
    emit(state.copyWith(status: SetupStatus.saving));
    try {
      final r = await _repo.startSeason(
        name: name.trim().isEmpty ? null : name.trim(),
        endEvent: endEvent.trim().isEmpty ? null : endEvent.trim(),
        focusIds: state.idsIn(Place.focus),
        keepGoingIds: state.idsIn(Place.keepGoing),
        // Keep each parked area's return date; setup has no date picker, so it must not wipe one.
        parked: [
          for (final id in state.idsIn(Place.parked))
            (areaId: id, until: state.data?.parked.where((p) => p.id == id).firstOrNull?.until),
        ],
        sameSeason: editing,
      );
      emit(state.copyWith(status: SetupStatus.started, data: r.data, undoId: r.activityId));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SetupStatus.ready, error: e.message));
    }
  }
}
