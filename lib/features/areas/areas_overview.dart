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

/// One tracked number: where it started, is, and is going, and the last readings.
class TrackedNumber {
  final String projectId;
  final String name;
  final String unit;
  final double start;
  final double latest;
  final double target;
  final int percent;

  /// Change per week from the recent readings; null until there are enough.
  final double? weeklyChange;

  /// TOWARD | STALLED | AWAY | TOO_EARLY.
  final String trend;
  final List<double> points;

  const TrackedNumber({
    required this.projectId,
    required this.name,
    this.unit = '',
    required this.start,
    required this.latest,
    required this.target,
    this.percent = 0,
    this.weeklyChange,
    this.trend = 'TOO_EARLY',
    this.points = const [],
  });

  factory TrackedNumber.fromJson(Json j) => TrackedNumber(
        projectId: asString(j['projectId']),
        name: asString(j['name']),
        unit: asString(j['unit']),
        start: asDouble(j['start']),
        latest: asDouble(j['latest']),
        target: asDouble(j['target']),
        percent: asInt(j['percent']),
        weeklyChange: j['weeklyChange'] == null ? null : asDouble(j['weeklyChange']),
        trend: asString(j['trend'], 'TOO_EARLY'),
        points: ((j['points'] as List?) ?? const []).whereType<Json>().map((p) => asDouble(p['value'])).toList(),
      );

  /// 72.4 → "72.4", 72.0 → "72".
  static String show(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  String get _u => unit.isEmpty ? '' : ' $unit';

  /// "72.4 kg now · goal 68 kg"
  String get line => '${show(latest)}$_u now · goal ${show(target)}$_u';

  /// Said plainly, never as a failure.
  String get trendWords => switch (trend) {
        'TOWARD' => weeklyChange == null
            ? 'Moving the right way'
            : 'Moving the right way, about ${show(weeklyChange!.abs())}$_u a week',
        'STALLED' => 'Holding steady lately',
        'AWAY' => 'Drifting the other way lately. That happens.',
        _ => 'A few more readings and the trend shows',
      };
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

  /// Three small tastes going here, or null.
  final ({int done, int total, bool decide})? tastes;

  /// A mode change planned for a day ("YYYY-MM-DD"), or null.
  final ({AreaMode mode, String on})? planned;

  /// Steps here reworked three or more times since anything was done.
  final bool reworking;

  /// Numbers tracked here, each with its last readings.
  final List<TrackedNumber> numbers;

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
    this.tastes,
    this.planned,
    this.reworking = false,
    this.numbers = const [],
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
        tastes: j['tastes'] is Json
            ? (
                done: asInt((j['tastes'] as Json)['done']),
                total: asInt((j['tastes'] as Json)['total'], 3),
                decide: asBool((j['tastes'] as Json)['decide']),
              )
            : null,
        planned: j['planned'] is Json
            ? (mode: AreaMode.fromName(asString((j['planned'] as Json)['mode'])), on: asString((j['planned'] as Json)['on']))
            : null,
        reworking: asBool(j['reworking']),
        numbers: ((j['numbers'] as List?) ?? const []).whereType<Json>().map(TrackedNumber.fromJson).toList(),
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
