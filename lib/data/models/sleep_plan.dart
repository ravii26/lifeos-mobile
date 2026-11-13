import 'json.dart';

class SleepStep {
  final int week;
  final String wake; // "HH:MM"
  final String sleep; // "HH:MM", "24:00" = midnight
  const SleepStep(this.week, this.wake, this.sleep);

  factory SleepStep.fromJson(Json j) => SleepStep(asInt(j['week'], 1), asString(j['wake']), asString(j['sleep']));

  @override
  bool operator ==(Object other) => other is SleepStep && other.week == week && other.wake == wake && other.sleep == sleep;
  @override
  int get hashCode => Object.hash(week, wake, sleep);
}

/// "07:00" → "7:00 am", "24:00" → "12:00 midnight".
String clockLabel(String hhmm) {
  if (hhmm == '24:00' || hhmm == '00:00') return '12:00 midnight';
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? parts[1] : '00';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m ${h < 12 ? 'am' : 'pm'}';
}

/// The sleep fix (decisions log #13): one fast jump, then 30 minutes a week.
/// Mirrors the server's sleep.rules.ts `ladder` so setup can show the plan
/// before anything is saved; the server's answer is what counts after.
List<SleepStep> previewLadder(String fromWake, String targetWake, int hours) {
  int toMin(String t) => (int.parse(t.split(':')[0]) * 60) + int.parse(t.split(':')[1]);
  String fmt(int m) {
    final d = ((m % 1440) + 1440) % 1440;
    return '${(d ~/ 60).toString().padLeft(2, '0')}:${(d % 60).toString().padLeft(2, '0')}';
  }

  final target = toMin(targetWake), from = toMin(fromWake);
  var wake = from < target + 60 ? from : target + 60;
  if (wake < target) wake = target;
  final steps = <SleepStep>[];
  for (var week = 1;; week++, wake -= 30) {
    final w = wake < target ? target : wake;
    final bed = w - hours;
    steps.add(SleepStep(week, fmt(w), bed == 0 ? '24:00' : fmt(bed)));
    if (w == target) break;
  }
  return steps;
}

class SleepPlan {
  final String targetWake;
  final int hours; // minutes asleep wanted
  final int step; // 1-based week of the ladder
  final List<SleepStep> steps;
  final bool done;
  final DateTime? stepAt;

  const SleepPlan({required this.targetWake, required this.hours, required this.step, required this.steps, required this.done, this.stepAt});

  SleepStep get current => steps[(step - 1).clamp(0, steps.length - 1)];

  static SleepPlan? fromJson(dynamic v) {
    if (v is! Json) return null;
    return SleepPlan(
      targetWake: asString(v['targetWake']),
      hours: asInt(v['hours'], 420),
      step: asInt(v['step'], 1),
      steps: ((v['steps'] as List?) ?? const []).whereType<Json>().map(SleepStep.fromJson).toList(),
      done: asBool(v['done']),
      stepAt: asDate(v['stepAt']),
    );
  }
}
