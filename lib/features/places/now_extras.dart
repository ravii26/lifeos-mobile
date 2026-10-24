import 'package:equatable/equatable.dart';

import '../../data/models/json.dart';

/// The quiet extras under the main pick on Now (Phase D): today's counts, a running
/// timer, the routine for this part of the day, the next meal, and one Watch later
/// suggestion when there is room. All of them come from `GET /now`; none of them
/// replaces the one thing to do.

class NowCount extends Equatable {
  final String id;
  final String title;
  final int count;
  final int? target;
  const NowCount(this.id, this.title, this.count, this.target);

  factory NowCount.fromJson(Json j) =>
      NowCount(asString(j['id']), asString(j['title']), asInt(j['count']), j['target'] == null ? null : asInt(j['target']));

  String get line => target == null ? '$title: $count' : '$title: $count of $target';

  @override
  List<Object?> get props => [id, count, target];
}

class NowStep extends Equatable {
  final String text;
  final bool done;
  const NowStep(this.text, this.done);

  @override
  List<Object?> get props => [text, done];
}

class NowRoutine extends Equatable {
  final String id;
  final String title;
  final List<NowStep> steps;
  const NowRoutine(this.id, this.title, this.steps);

  int get remaining => steps.where((s) => !s.done).length;

  static NowRoutine? fromJson(Object? v) {
    if (v is! Json) return null;
    final steps = ((v['steps'] as List?) ?? const []).whereType<Json>().map((s) => NowStep(asString(s['text']), asBool(s['done']))).toList();
    return steps.isEmpty ? null : NowRoutine(asString(v['id']), asString(v['title']), steps);
  }

  @override
  List<Object?> get props => [id, steps];
}

class NowLater extends Equatable {
  final String id;
  final String title;
  final String? url;
  final String line;
  const NowLater(this.id, this.title, this.url, this.line);

  static NowLater? fromJson(Object? v) {
    if (v is! Json) return null;
    return NowLater(asString(v['id']), asString(v['title']), asStringOrNull(v['url']), asString(v['line']));
  }

  @override
  List<Object?> get props => [id];
}

class NowTimer extends Equatable {
  final String label;
  final int minutes;
  final bool forgotten;
  const NowTimer(this.label, this.minutes, this.forgotten);

  static NowTimer? fromJson(Object? v) {
    if (v is! Json) return null;
    return NowTimer(asString(v['label']), asInt(v['minutes']), asBool(v['forgotten']));
  }

  String get length => minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min';

  @override
  List<Object?> get props => [label, minutes, forgotten];
}

class NowMeal extends Equatable {
  final String meal;
  final String text;
  final bool tomorrow;
  const NowMeal(this.meal, this.text, this.tomorrow);

  static NowMeal? fromJson(Object? v) {
    if (v is! Json) return null;
    return NowMeal(asString(v['meal']), asString(v['text']), asBool(v['tomorrow']));
  }

  String get label => tomorrow ? "Tomorrow's $meal" : 'Next meal: $meal';

  @override
  List<Object?> get props => [meal, text, tomorrow];
}

class NowExtras extends Equatable {
  final List<NowCount> counts;
  final NowTimer? timer;
  final NowRoutine? routine;
  final NowMeal? meal;
  final NowLater? later;
  const NowExtras({this.counts = const [], this.timer, this.routine, this.meal, this.later});

  static const empty = NowExtras();

  bool get isEmpty => counts.isEmpty && timer == null && routine == null && meal == null && later == null;

  factory NowExtras.fromJson(Json data) => NowExtras(
        counts: ((data['counts'] as List?) ?? const []).whereType<Json>().map(NowCount.fromJson).toList(),
        timer: NowTimer.fromJson(data['timer']),
        routine: NowRoutine.fromJson(data['routine']),
        meal: NowMeal.fromJson(data['meal']),
        later: NowLater.fromJson(data['watchLater']),
      );

  @override
  List<Object?> get props => [counts, timer, routine, meal, later];
}
