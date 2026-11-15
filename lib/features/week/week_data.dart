import '../../data/models/json.dart';

/// The Week tab's data, from `GET /week`.
class WeekData {
  final String label; // "16 – 22 Nov"
  final String todayKey;
  final List<WeekDay> days;
  final List<WeekRoutine> routines;
  final List<WeekArea> areas;
  final WeekLookBack? lookBack;

  const WeekData({
    required this.label,
    required this.todayKey,
    required this.days,
    this.routines = const [],
    this.areas = const [],
    this.lookBack,
  });

  /// The position of an area in the person's list, which decides its colour.
  int colorIndexOf(String areaId) {
    final i = areas.indexWhere((a) => a.id == areaId);
    return i < 0 ? areas.length : i;
  }

  String nameOf(String areaId) => areas.where((a) => a.id == areaId).map((a) => a.name).firstOrNull ?? 'Other';

  int get todayIndex {
    final i = days.indexWhere((d) => d.key == todayKey);
    return i < 0 ? 0 : i;
  }

  factory WeekData.fromJson(Json j) => WeekData(
        label: asString(j['label']),
        todayKey: asString(j['todayKey']),
        days: ((j['days'] as List?) ?? const []).whereType<Json>().map(WeekDay.fromJson).toList(),
        routines: ((j['routines'] as List?) ?? const []).whereType<Json>().map(WeekRoutine.fromJson).toList(),
        areas: ((j['areas'] as List?) ?? const []).whereType<Json>().map(WeekArea.fromJson).toList(),
        lookBack: j['lookBack'] is Json ? WeekLookBack.fromJson(j['lookBack'] as Json) : null,
      );
}

typedef AreaMinutes = ({String areaId, int minutes});

List<AreaMinutes> _minutes(Object? v) =>
    ((v as List?) ?? const []).whereType<Json>().map((x) => (areaId: asString(x['areaId']), minutes: asInt(x['minutes']))).toList();

class WeekDay {
  final String key;
  final String label; // Mon
  final List<AreaMinutes> done;
  final List<AreaMinutes> planned;
  const WeekDay(this.key, this.label, this.done, this.planned);

  int get doneMinutes => done.fold(0, (s, x) => s + x.minutes);
  int get plannedMinutes => planned.fold(0, (s, x) => s + x.minutes);

  factory WeekDay.fromJson(Json j) => WeekDay(asString(j['key']), asString(j['label']), _minutes(j['done']), _minutes(j['planned']));
}

/// DONE | PLANNED | PAST | OFF for each day, Monday first.
class WeekRoutine {
  final String id;
  final String title;
  final String areaId;
  final List<String> dots;
  final String line;
  const WeekRoutine(this.id, this.title, this.areaId, this.dots, this.line);

  factory WeekRoutine.fromJson(Json j) => WeekRoutine(
        asString(j['id']),
        asString(j['title']),
        asString(j['areaId']),
        ((j['dots'] as List?) ?? const []).map((e) => '$e').toList(),
        asString(j['line']),
      );
}

class WeekArea {
  final String id;
  final String name;
  final String mode; // PUSH | MAINTAIN | EXPLORE | REST
  final int minutes;
  final int plannedMinutes;
  const WeekArea(this.id, this.name, this.mode, this.minutes, this.plannedMinutes);

  factory WeekArea.fromJson(Json j) =>
      WeekArea(asString(j['id']), asString(j['name']), asString(j['mode'], 'MAINTAIN'), asInt(j['minutes']), asInt(j['plannedMinutes']));
}

class WeekLookBack {
  final String month;
  final int totalMinutes;
  final List<({String name, int minutes})> byArea;
  const WeekLookBack(this.month, this.totalMinutes, this.byArea);

  factory WeekLookBack.fromJson(Json j) => WeekLookBack(
        asString(j['month']),
        asInt(j['totalMinutes']),
        ((j['byArea'] as List?) ?? const []).whereType<Json>().map((x) => (name: asString(x['name']), minutes: asInt(x['minutes']))).toList(),
      );
}

/// "41h", "45 min", "1h 30" (hours round to whole hours from 10 up, for a look back).
String hoursLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h >= 10 || m == 0) return '${(minutes / 60).round()}h';
  return '${h}h ${m.toString().padLeft(2, '0')}';
}
