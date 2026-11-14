import '../../core/api/api_exception.dart';
import '../../data/models/area.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';

/// How much of you an area gets right now. Every area stays alive; a mode is
/// an order of attention, never a cap. Stored on the server as the area's tier.
enum AreaMode {
  push('Push', 'MAIN', 'Getting most of your effort right now.'),
  maintain('Maintain', 'MAINTAIN', 'Kept steady with a small, regular dose.'),
  explore('Explore', 'SECONDARY', 'Trying it out, with no pressure to commit.'),
  rest('Rest', 'LATER', 'Paused on purpose. Nothing is asked here.');

  final String label;
  final String tier;
  final String meaning;
  const AreaMode(this.label, this.tier, this.meaning);

  static AreaMode fromTier(String tier) =>
      AreaMode.values.firstWhere((m) => m.tier == tier, orElse: () => AreaMode.maintain);

  static AreaMode fromName(String name) =>
      AreaMode.values.firstWhere((m) => m.name.toUpperCase() == name, orElse: () => AreaMode.maintain);
}

class AreaStep {
  final String id;
  final String title;
  final int? minutes;

  /// LOW | NORMAL | HIGH; null = normal.
  final String? energy;

  /// The smaller version, for a hard day.
  final String? smaller;
  bool done;
  AreaStep(this.id, this.title, this.minutes, {this.energy, this.smaller, this.done = false});
}

class AreaRoutine {
  final String id;
  final String title;
  final int doneThisWeek;
  const AreaRoutine(this.id, this.title, this.doneThisWeek);
}

/// One area and where it stands this week.
class AreaStanding {
  final String id;
  final String name;
  final AreaMode mode;
  final int? weeklyMinutes;
  final int plannedMinutes;
  final int minutes;

  /// 0 to 1: the length of this area's spoke on the life wheel.
  final double value;
  final String status;
  final List<String> goals;
  final List<AreaStep> nextSteps;
  final List<AreaRoutine> routines;

  const AreaStanding({
    required this.id,
    required this.name,
    required this.mode,
    this.weeklyMinutes,
    this.plannedMinutes = 0,
    this.minutes = 0,
    required this.value,
    required this.status,
    this.goals = const [],
    this.nextSteps = const [],
    this.routines = const [],
  });

  factory AreaStanding.fromJson(Json j) => AreaStanding(
        id: asString(j['id']),
        name: asString(j['name']),
        mode: AreaMode.fromName(asString(j['mode'], 'MAINTAIN')),
        weeklyMinutes: j['weeklyMinutes'] == null ? null : asInt(j['weeklyMinutes']),
        plannedMinutes: asInt(j['plannedMinutes']),
        minutes: asInt(j['minutes']),
        value: asDouble(j['value']).clamp(0.0, 1.0).toDouble(),
        status: asString(j['status']),
        goals: ((j['goals'] as List?) ?? const []).whereType<Json>().map((g) => asString(g['title'])).toList(),
        nextSteps: ((j['nextSteps'] as List?) ?? const [])
            .whereType<Json>()
            .map((s) => AreaStep(asString(s['id']), asString(s['title']), s['minutes'] == null ? null : asInt(s['minutes']),
                energy: asStringOrNull(s['energy']), smaller: asStringOrNull(s['smaller'])))
            .toList(),
        routines: ((j['routines'] as List?) ?? const [])
            .whereType<Json>()
            .map((r) => AreaRoutine(asString(r['id']), asString(r['title']), asInt(r['doneThisWeek'])))
            .toList(),
      );

  /// From the older `GET /areas` list, for a server that has no overview yet:
  /// the mode is known, the week's time is not, so to-dos stand in for it.
  factory AreaStanding.fromArea(Area a) {
    final mode = AreaMode.fromTier(a.tier);
    final resting = mode == AreaMode.rest;
    return AreaStanding(
      id: a.id,
      name: a.name,
      mode: mode,
      value: resting || a.tasksTotal == 0 ? 0 : (a.tasksDone / a.tasksTotal).clamp(0.0, 1.0).toDouble(),
      status: resting
          ? 'Resting'
          : a.tasksTotal == 0
              ? 'Not started yet'
              : '${a.tasksDone} of ${a.tasksTotal} to-dos done',
    );
  }
}

class AreasOverview {
  final List<AreaStanding> areas;
  final int neededMinutes;
  final int freeMinutes;

  /// A suggestion when the week asks for more than there is. Never a block.
  final String? capacityNote;

  /// False when built from the older list: weekly time cannot be set or shown.
  final bool full;

  const AreasOverview({required this.areas, this.neededMinutes = 0, this.freeMinutes = 0, this.capacityNote, this.full = true});

  factory AreasOverview.fromJson(Json j) {
    final cap = j['capacity'] is Json ? j['capacity'] as Json : const <String, dynamic>{};
    return AreasOverview(
      areas: ((j['areas'] as List?) ?? const []).whereType<Json>().map(AreaStanding.fromJson).toList(),
      neededMinutes: asInt(cap['neededMinutes']),
      freeMinutes: asInt(cap['freeMinutes']),
      capacityNote: asStringOrNull(cap['note']),
    );
  }
}

/// The overview, or the same picture built from the older list when the
/// server does not have the overview yet.
Future<AreasOverview> loadAreasOverview(LifeRepository repo) async {
  try {
    return AreasOverview.fromJson(await repo.areasOverview());
  } on ApiException catch (e) {
    if (!e.isNotFound) rethrow;
    final areas = (await repo.areas()).where((a) => a.isActive).toList();
    return AreasOverview(areas: areas.map(AreaStanding.fromArea).toList(), full: false);
  }
}
