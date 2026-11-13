import 'json.dart';

/// The five answers behind a fitness plan (decisions log #1).
class FitnessAnswers {
  String goal = 'LOSE_BELLY'; // LOSE_BELLY | LOSE_WEIGHT | BUILD_MUSCLE | STAMINA
  double? weightKg;
  double? heightCm;
  String where = 'GYM'; // GYM | HOME | BOTH
  String? diet; // VEG | VEG_EGG | NON_VEG
  bool homeFood = true;
  bool messFood = false;
  bool outsideOften = false;
  String health = 'NONE'; // NONE | CONDITION | JOINT

  Json toJson() => {
        'goal': goal,
        'weightKg': ?weightKg,
        'heightCm': ?heightCm,
        'where': where,
        'diet': ?diet,
        'homeFood': homeFood,
        'messFood': messFood,
        'outsideOften': outsideOften,
        'health': health,
      };
}

class PlanSession {
  final String key; // STRENGTH | WALK
  final String title;
  final int minutes;
  final String smallest;
  final List<String> days; // full shape, from week 2
  final List<String> week1Days;
  final String detail;

  const PlanSession({required this.key, required this.title, required this.minutes, required this.smallest, required this.days, required this.week1Days, required this.detail});

  factory PlanSession.fromJson(Json j) => PlanSession(
        key: asString(j['key']),
        title: asString(j['title']),
        minutes: asInt(j['minutes']),
        smallest: asString(j['smallest']),
        days: asStringList(j['days']),
        week1Days: asStringList(j['week1Days']),
        detail: asString(j['detail']),
      );
}

class FitnessPlan {
  final String title;
  final int phaseWeeks;
  final double? startKg;
  final double? targetKg;
  final List<PlanSession> sessions;
  final List<String> foodRules;
  final List<String> lifeRules;
  final List<String> cautions;

  const FitnessPlan({
    required this.title,
    required this.phaseWeeks,
    this.startKg,
    this.targetKg,
    required this.sessions,
    required this.foodRules,
    required this.lifeRules,
    required this.cautions,
  });

  factory FitnessPlan.fromJson(Json j) {
    final w = j['weight'];
    return FitnessPlan(
      title: asString(j['title']),
      phaseWeeks: asInt(j['phaseWeeks'], 8),
      startKg: w is Json ? asDouble(w['start']) : null,
      targetKg: w is Json ? asDouble(w['target']) : null,
      sessions: ((j['sessions'] as List?) ?? const []).whereType<Json>().map(PlanSession.fromJson).toList(),
      foodRules: asStringList(j['foodRules']),
      lifeRules: asStringList(j['lifeRules']),
      cautions: asStringList(j['cautions']),
    );
  }
}

/// One session in the Sunday check-in: what it becomes next week.
class CheckinSession {
  final String title;
  final int minutes;
  final List<String> days;
  final String? changed; // "30 min instead of 40", "now Tue, Thu, Sat"; null = same
  const CheckinSession(this.title, this.minutes, this.days, this.changed);

  factory CheckinSession.fromJson(Json j) => CheckinSession(asString(j['title']), asInt(j['minutes']), asStringList(j['days']), asStringOrNull(j['changed']));
}

/// GET /weekplan/checkin: the last 7 days and next week, nothing changed yet.
class CheckinPreview {
  final int week;
  final int weeks;
  final int done;
  final int planned;
  final String verdict; // LIGHTER | SAME | HARDER
  final String message;
  final List<CheckinSession> sessions;
  final bool askWeight;
  final double? lastWeight;
  final bool alreadyDone;

  const CheckinPreview({
    required this.week,
    required this.weeks,
    required this.done,
    required this.planned,
    required this.verdict,
    required this.message,
    required this.sessions,
    required this.askWeight,
    this.lastWeight,
    required this.alreadyDone,
  });

  static CheckinPreview? fromJson(dynamic v) {
    if (v is! Json) return null;
    return CheckinPreview(
      week: asInt(v['week'], 1),
      weeks: asInt(v['weeks'], 8),
      done: asInt(v['done']),
      planned: asInt(v['planned']),
      verdict: asString(v['verdict'], 'SAME'),
      message: asString(v['message']),
      sessions: ((v['sessions'] as List?) ?? const []).whereType<Json>().map(CheckinSession.fromJson).toList(),
      askWeight: asBool(v['askWeight']),
      lastWeight: asDoubleOrNull(v['lastWeight']),
      alreadyDone: asBool(v['alreadyDone']),
    );
  }
}

/// A running plan, as My life shows it.
class RunningPlan {
  final String title;
  final int week;
  final int weeks;
  const RunningPlan(this.title, this.week, this.weeks);

  static RunningPlan? fromJson(dynamic v) => v is Json ? RunningPlan(asString(v['title']), asInt(v['week'], 1), asInt(v['weeks'], 8)) : null;
}
