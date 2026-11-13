import 'json.dart';

class DumpThing {
  final String id;
  final String title;
  final DateTime? due;
  const DumpThing(this.id, this.title, this.due);

  factory DumpThing.fromJson(Json j) => DumpThing(asString(j['id']), asString(j['title']), asDate(j['due']));
}

/// POST /now/dump ("My head is full"): what was added, sorted by code, and
/// the honest time check for the whole list.
class DumpResult {
  final List<DumpThing> dated; // has a real date
  final List<DumpThing> thisWeek;
  final List<DumpThing> later; // can wait
  final int added;
  final int alreadyThere;
  final bool fits;
  final String line; // "All of this needs about 31 h a week. You have about 11 h free…"
  final bool hasSeason;
  final String? activityId;

  const DumpResult({
    required this.dated,
    required this.thisWeek,
    required this.later,
    required this.added,
    required this.alreadyThere,
    required this.fits,
    required this.line,
    required this.hasSeason,
    required this.activityId,
  });

  static List<DumpThing> _things(dynamic v) => (v is List ? v : const []).whereType<Json>().map(DumpThing.fromJson).toList();

  factory DumpResult.fromJson(Json j) {
    final g = (j['groups'] as Json?) ?? const {};
    return DumpResult(
      dated: _things(g['DATED']),
      thisWeek: _things(g['THIS_WEEK']),
      later: _things(g['LATER']),
      added: asInt(j['added']),
      alreadyThere: asInt(j['alreadyThere']),
      fits: asBool(j['fits']),
      line: asString(j['line']),
      hasSeason: asBool(j['hasSeason']),
      activityId: asStringOrNull(j['activityId']),
    );
  }
}
