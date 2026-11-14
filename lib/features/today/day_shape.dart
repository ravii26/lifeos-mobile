import 'package:flutter/painting.dart' show Color;

import '../../data/models/json.dart';
import '../../design/rings.dart';

/// Turns a person's day (the parts they set up, and what is planned today)
/// into the dial on Today and the answer to "when am I free?". Pure code, no
/// network and no clock of its own, so it is easy to test.

/// One part of the day from `GET /now/schedule`.
class DayBlockInfo {
  final String block;

  /// Minutes from midnight.
  final int start;
  final int end;

  /// How much of this part is the person's own. 0 means spoken for (office).
  final int freeMinutes;

  const DayBlockInfo(this.block, this.start, this.end, this.freeMinutes);

  static int _min(Object? hhmm) {
    final p = '$hhmm'.split(':');
    if (p.length != 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  static DayBlockInfo? fromJson(Object? v) {
    if (v is! Json) return null;
    final start = _min(v['start']), end = _min(v['end']);
    if (end <= start) return null;
    return DayBlockInfo(asString(v['block']), start, end.clamp(0, 1440), asInt(v['freeMinutes']));
  }

  bool get isFree => freeMinutes > 0;
}

/// The blocks for [weekday] (0 = Sunday) out of the `GET /now/schedule` reply.
List<DayBlockInfo> blocksForWeekday(List<Json> schedule, int weekday) {
  for (final day in schedule) {
    if (asInt(day['weekday'], -1) != weekday) continue;
    final list = ((day['blocks'] as List?) ?? const []).map(DayBlockInfo.fromJson).whereType<DayBlockInfo>().toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }
  return const [];
}

/// One line of today's list, from `GET /now/plan`.
class TodayItem {
  final String id;
  final String type; // TASK | HABIT | REMINDER
  final String title;
  final String block;
  final int? minutes;

  /// Minutes from midnight when it has a set time today.
  final int? at;
  bool done;

  TodayItem({
    required this.id,
    required this.type,
    required this.title,
    required this.block,
    this.minutes,
    this.at,
    this.done = false,
  });

  /// What the server calls it when answering: a reminder is a task.
  String get sourceType => type == 'HABIT' ? 'HABIT' : 'TASK';

  static TodayItem fromJson(Json j) {
    int? at;
    final raw = asStringOrNull(j['at']);
    if (raw != null) {
      final t = DateTime.tryParse(raw)?.toLocal();
      if (t != null) at = t.hour * 60 + t.minute;
    }
    return TodayItem(
      id: asString(j['id']),
      type: asString(j['type'], 'TASK'),
      title: asString(j['title']),
      block: asString(j['block'], 'ANYTIME'),
      minutes: j['minutes'] == null ? null : asInt(j['minutes']),
      at: at,
      done: asBool(j['done']),
    );
  }
}

/// Today's items out of the `GET /now/plan` reply: set times first, in order,
/// then the rest in the order the server gave (by part of the day).
List<TodayItem> todayItems(Json plan) {
  final today = plan['today'];
  if (today is! Json) return const [];
  final items = <TodayItem>[
    for (final b in ((today['blocks'] as List?) ?? const []).whereType<Json>())
      for (final i in ((b['items'] as List?) ?? const []).whereType<Json>()) TodayItem.fromJson(i),
  ];
  final timed = items.where((i) => i.at != null).toList()..sort((a, b) => a.at!.compareTo(b.at!));
  return [...timed, ...items.where((i) => i.at == null)];
}

/// The free time that matters right now: the stretch the person is in, or the
/// next one today.
class FreeWindow {
  final int start;
  final int end;

  /// Usable minutes: never more than the part allows, never more than is left.
  final int minutes;

  /// True when it has already begun.
  final bool now;

  const FreeWindow(this.start, this.end, this.minutes, {required this.now});
}

// A window with less than this left is not worth offering.
const _worthIt = 10;

FreeWindow? freeWindow(List<DayBlockInfo> blocks, int nowMin) {
  for (final b in blocks) {
    if (!b.isFree || b.end <= nowMin) continue;
    if (b.start <= nowMin) {
      final left = b.end - nowMin;
      final minutes = left < b.freeMinutes ? left : b.freeMinutes;
      if (minutes < _worthIt) continue;
      return FreeWindow(nowMin, b.end, minutes, now: true);
    }
    final span = b.end - b.start;
    return FreeWindow(b.start, b.end, span < b.freeMinutes ? span : b.freeMinutes, now: false);
  }
  return null;
}

/// The arcs on the dial. Spoken-for time and sleep are thin and dim, free
/// parts are marigold, and anything with a set time sits on top in [planned].
List<DayPart> dialParts(List<DayBlockInfo> blocks, List<TodayItem> items, {required Color planned}) {
  final parts = <DayPart>[];
  if (blocks.isNotEmpty) {
    // Sleep: from the end of the last part of the day to the start of the first.
    final wake = blocks.first.start, bed = blocks.last.end % 1440;
    final asleep = (wake - bed + 1440) % 1440;
    if (asleep >= 60) parts.add(DayPart(bed, wake, DayPartKind.fixed));
  }
  for (final b in blocks) {
    parts.add(DayPart(b.start, b.end, b.isFree ? DayPartKind.free : DayPartKind.fixed));
  }
  for (final i in items) {
    final at = i.at;
    if (at == null || i.done) continue;
    final length = (i.minutes ?? 15).clamp(15, 240);
    parts.add(DayPart(at, (at + length).clamp(0, 1440), DayPartKind.planned, color: planned));
  }
  return parts;
}

/// When the server cannot be reached: the first thing still open on today's
/// list that fits in [minutes]. Things with no length are assumed short.
TodayItem? fitFromList(List<TodayItem> items, int minutes) {
  for (final i in items) {
    if (i.done) continue;
    if ((i.minutes ?? 10) <= minutes) return i;
  }
  return null;
}

/// 1110 → "18:30".
String clock(int minutes) {
  final m = minutes % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// 95 → "1h 35", 40 → "40 min", 120 → "2h".
String duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}';
}

String partName(String block) => switch (block) {
      'MORNING' => 'Morning',
      'COMMUTE' => 'Commute',
      'OFFICE' => 'Work',
      'GYM' => 'Workout',
      'EVENING' => 'Evening',
      'NIGHT' => 'Night',
      _ => 'Anytime',
    };

String greeting(int hour) => hour < 5
    ? 'Still up'
    : hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
