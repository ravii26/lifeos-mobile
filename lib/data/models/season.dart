import 'json.dart';

/// One area as the season sees it: where it sits now and what it asks for in a week.
class SeasonArea {
  final String id;
  final String name;
  final String tier; // MAIN | SECONDARY | MAINTAIN | LATER
  final int weeklyMinutes; // from its goals, habits and to-dos; 0 = nothing planned yet

  const SeasonArea({required this.id, required this.name, required this.tier, required this.weeklyMinutes});

  factory SeasonArea.fromJson(Json j) => SeasonArea(
        id: asString(j['id']),
        name: asString(j['name']),
        tier: asString(j['tier'], 'MAINTAIN'),
        weeklyMinutes: asInt(j['weeklyMinutes']),
      );
}

class SeasonPlaceItem {
  final String id;
  final String name;
  final DateTime? until; // parked items only
  const SeasonPlaceItem(this.id, this.name, [this.until]);

  factory SeasonPlaceItem.fromJson(Json j) => SeasonPlaceItem(asString(j['id']), asString(j['name']), asDate(j['until']));
}

/// The chapter itself (null before the first season).
class SeasonInfo {
  final int number;
  final String? name;
  final DateTime startedAt;
  final DateTime? endsAt;
  final String? endEvent;
  final int week;
  final int weeks;
  final bool over;
  final String line; // "Switch & Shape · week 2 of 10"

  const SeasonInfo({
    required this.number,
    required this.name,
    required this.startedAt,
    required this.endsAt,
    required this.endEvent,
    required this.week,
    required this.weeks,
    required this.over,
    required this.line,
  });

  String get title => (name ?? '').trim().isEmpty ? 'Season $number' : name!;

  factory SeasonInfo.fromJson(Json j) => SeasonInfo(
        number: asInt(j['number']),
        name: asStringOrNull(j['name']),
        startedAt: asDate(j['startedAt']) ?? DateTime.now(),
        endsAt: asDate(j['endsAt']),
        endEvent: asStringOrNull(j['endEvent']),
        week: asInt(j['week'], 1),
        weeks: asInt(j['weeks'], 10),
        over: asBool(j['over']),
        line: asString(j['line']),
      );
}

/// GET /season: the chapter, where every area sits, and the week's load.
class SeasonData {
  final SeasonInfo? season;
  final List<SeasonArea> areas;
  final List<SeasonPlaceItem> focus;
  final List<SeasonPlaceItem> keepGoing;
  final List<SeasonPlaceItem> background;
  final List<SeasonPlaceItem> parked;
  final int freeMinutes; // free time in a normal week
  final int maxFocus;
  final int maxKeepGoing;

  const SeasonData({
    required this.season,
    required this.areas,
    required this.focus,
    required this.keepGoing,
    required this.background,
    required this.parked,
    required this.freeMinutes,
    this.maxFocus = 2,
    this.maxKeepGoing = 3,
  });

  static List<SeasonPlaceItem> _items(dynamic v) =>
      (v is List ? v : const []).whereType<Json>().map(SeasonPlaceItem.fromJson).toList();

  factory SeasonData.fromJson(Json j) {
    final places = (j['places'] as Json?) ?? const {};
    final caps = (j['caps'] as Json?) ?? const {};
    return SeasonData(
      season: j['season'] is Json ? SeasonInfo.fromJson(j['season'] as Json) : null,
      areas: ((j['areas'] as List?) ?? const []).whereType<Json>().map(SeasonArea.fromJson).toList(),
      focus: _items(places['focus']),
      keepGoing: _items(places['keepGoing']),
      background: _items(places['background']),
      parked: _items(places['parked']),
      freeMinutes: asInt(j['freeMinutes']),
      maxFocus: asInt(caps['MAIN'], 2),
      maxKeepGoing: asInt(caps['SECONDARY'], 3),
    );
  }
}

/// One area in the season being reviewed, with what got done in it.
class ReviewArea {
  final String id;
  final String name;
  final String place; // FOCUS | KEEP_GOING
  final int done;
  const ReviewArea({required this.id, required this.name, required this.place, required this.done});

  factory ReviewArea.fromJson(Json j) =>
      ReviewArea(id: asString(j['id']), name: asString(j['name']), place: asString(j['place'], 'FOCUS'), done: asInt(j['done']));
}

/// A parked area offered back at the review, with why ("7 things waiting").
class ReviewParked {
  final String id;
  final String name;
  final String why;
  final int waiting;
  const ReviewParked({required this.id, required this.name, required this.why, required this.waiting});

  factory ReviewParked.fromJson(Json j) =>
      ReviewParked(id: asString(j['id']), name: asString(j['name']), why: asString(j['why']), waiting: asInt(j['waiting']));
}

/// GET /season/review (canvas board P1·F): what this season did, what is
/// waiting, and the next season pre-filled.
class SeasonReview {
  final SeasonInfo season;
  final List<String> lines;
  final List<ReviewArea> areas;
  final List<ReviewParked> parked;
  final int nextNumber;
  final List<String> nextFocusIds;
  final List<String> nextKeepGoingIds;
  final bool canLightWeek;

  const SeasonReview({
    required this.season,
    required this.lines,
    required this.areas,
    required this.parked,
    required this.nextNumber,
    required this.nextFocusIds,
    required this.nextKeepGoingIds,
    required this.canLightWeek,
  });

  static List<String> _ids(dynamic v) => (v is List ? v : const []).map((e) => asString(e)).where((e) => e.isNotEmpty).toList();

  factory SeasonReview.fromJson(Json j) {
    final next = (j['next'] as Json?) ?? const {};
    return SeasonReview(
      season: SeasonInfo.fromJson((j['season'] as Json?) ?? const {}),
      lines: _ids(j['lines']),
      areas: ((j['areas'] as List?) ?? const []).whereType<Json>().map(ReviewArea.fromJson).toList(),
      parked: ((j['parked'] as List?) ?? const []).whereType<Json>().map(ReviewParked.fromJson).toList(),
      nextNumber: asInt(next['number'], 2),
      nextFocusIds: _ids(next['focusIds']),
      nextKeepGoingIds: _ids(next['keepGoingIds']),
      canLightWeek: asBool(j['canLightWeek']),
    );
  }
}
