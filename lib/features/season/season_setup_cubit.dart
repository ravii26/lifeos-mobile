import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/season.dart';
import '../../data/repositories/life_repository.dart';

/// Where an area goes this season. Maps to the area's tier on the server.
enum Place { focus, keepGoing, background, parked }

enum SetupStep { explain, areas, pick, name }

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
      );

  @override
  List<Object?> get props => [status, step, data, minutes, guessed, places, swapFor, swapPlace, error, undoId];
}

/// Season setup (decisions log #7, canvas board P1·A): explainer (first time
/// only) → areas with hours → pick up to 2 focus → name it and start.
/// Ally pre-selects; the person only confirms or changes.
class SeasonSetupCubit extends Cubit<SeasonSetupState> {
  final LifeRepository _repo;
  SeasonSetupCubit(this._repo) : super(const SeasonSetupState());

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
      name = data.season?.name ?? '';
      endEvent = data.season?.endEvent ?? '';
      emit(state.copyWith(
        status: SetupStatus.ready,
        // The explainer is for the first season only.
        step: data.season == null ? SetupStep.explain : SetupStep.areas,
        data: data,
        minutes: minutes,
        guessed: guessed,
        places: _suggest(data, minutes),
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
        parked: [for (final id in state.idsIn(Place.parked)) (areaId: id, until: null)],
      );
      emit(state.copyWith(status: SetupStatus.started, data: r.data, undoId: r.activityId));
    } on ApiException catch (e) {
      emit(state.copyWith(status: SetupStatus.ready, error: e.message));
    }
  }
}
