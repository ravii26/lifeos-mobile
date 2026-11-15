import '../../data/models/habit.dart';

/// How a routine is described: plain words, counts, never streaks.

const weekdayCodes = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The parts of the day a routine can belong to; null is anytime.
const dayParts = <(String?, String)>[
  (null, 'Anytime'),
  ('MORNING', 'Morning'),
  ('COMMUTE', 'Commute'),
  ('EVENING', 'Evening'),
  ('NIGHT', 'Night'),
];

String partLabel(String? block) => dayParts.where((p) => p.$1 == block).map((p) => p.$2).firstOrNull ?? 'Anytime';

/// "Every day", "Mon, Wed, Fri", "3 times a week".
String whenWords({required String frequency, List<String> days = const [], int? weeklyTarget}) {
  if (frequency == 'WEEKLY') {
    final n = weeklyTarget ?? 1;
    return n == 1 ? 'Once a week' : '$n times a week';
  }
  if (frequency == 'CUSTOM' && days.isNotEmpty) {
    if (days.length == 7) return 'Every day';
    final ordered = [for (var i = 0; i < 7; i++) if (days.contains(weekdayCodes[i])) weekdayShort[i]];
    if (ordered.length == 5 && !days.contains('SAT') && !days.contains('SUN')) return 'Weekdays';
    if (ordered.length == 2 && days.contains('SAT') && days.contains('SUN')) return 'Weekends';
    return ordered.join(', ');
  }
  return 'Every day';
}

String habitWhen(Habit h) {
  final when = whenWords(frequency: h.frequency, days: h.specificDays, weeklyTarget: h.weeklyTarget);
  return h.timeBlock == null ? when : '$when · ${partLabel(h.timeBlock).toLowerCase()}';
}

/// "18 of the last 28 days". A count, so nothing is ever "broken".
String lastDaysWords(List<bool> history) {
  final done = history.where((d) => d).length;
  if (history.isEmpty) return 'Nothing logged yet';
  return '$done of the last ${history.length} days';
}
