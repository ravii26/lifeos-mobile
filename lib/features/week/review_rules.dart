import '../areas/areas_overview.dart';

/// The weekly review's rules, kept out of the screen so they can be tested.

/// How a Push area's week felt. Changes next week's time by a quarter.
enum PlanFeel {
  light('Too much', 0.75),
  same('About right', 1),
  more('A bit more', 1.25);

  final String label;
  final double factor;
  const PlanFeel(this.label, this.factor);
}

/// One stepper step, and the most one area can be given in a week.
const reviewStep = 15;
const reviewMax = 20 * 60;

/// The time an area starts the review with: what was set for it, else what
/// this week planned, else a small default for its mode.
int startingMinutes(AreaStanding a) {
  if (a.weeklyMinutes != null) return a.weeklyMinutes!;
  if (a.plannedMinutes > 0) return roundToStep(a.plannedMinutes);
  return switch (a.mode) {
    AreaMode.push => 180,
    AreaMode.maintain || AreaMode.explore => 60,
    AreaMode.rest => 0,
  };
}

int roundToStep(num minutes) => ((minutes / reviewStep).round() * reviewStep).clamp(0, reviewMax).toInt();

/// "Too much" never takes an area to zero: a smaller dose, not a stop.
int adjusted(int minutes, PlanFeel feel) {
  if (feel == PlanFeel.same || minutes == 0) return minutes;
  final r = roundToStep(minutes * feel.factor);
  return r == 0 ? reviewStep : r;
}

/// Weekly time that differs from what is stored, as (area, before, after).
List<({String areaId, int? before, int after})> timeChanges(List<AreaStanding> areas, Map<String, int> minutes) => [
      for (final a in areas)
        if (minutes.containsKey(a.id) && minutes[a.id] != a.weeklyMinutes) (areaId: a.id, before: a.weeklyMinutes, after: minutes[a.id]!),
    ];

/// Primary on Saturday, Sunday and Monday; on other days it is still there, quietly.
bool reviewIsDue(DateTime now) => now.weekday >= DateTime.saturday || now.weekday == DateTime.monday;

/// A plain note when the plan asks for more than the free time. A suggestion, never a block.
String? overNote(int planned, int free) {
  if (free <= 0 || planned <= free) return null;
  return 'That is ${minutesLabel(planned - free)} more than your free time. Something would slip; trim one, or keep it if this is a push week.';
}

/// "45 min", "1 h", "1 h 30".
String minutesLabel(int m) {
  if (m < 60) return '$m min';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h h' : '$h h ${r.toString().padLeft(2, '0')}';
}
