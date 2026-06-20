import 'json.dart';

class Habit {
  final String id;
  final String title;
  final String habitType; // BOOLEAN | COUNT | TIMER
  final int targetCount;
  final int targetMinutes;
  final String frequency;
  final String? reminderTime; // "HH:mm" or null
  final String? areaId;
  final bool isActive;

  // Stats block (from GET /habits)
  final int currentStreak;
  final int longestStreak;
  final bool todayDone;
  final int todayCount;
  final int todayMinutes;
  final List<bool> history; // up to 28 days, true = completed

  const Habit({
    required this.id,
    required this.title,
    required this.habitType,
    required this.targetCount,
    required this.targetMinutes,
    required this.frequency,
    this.reminderTime,
    this.areaId,
    required this.isActive,
    required this.currentStreak,
    required this.longestStreak,
    required this.todayDone,
    required this.todayCount,
    required this.todayMinutes,
    required this.history,
  });

  String get kind => switch (habitType.toUpperCase()) {
        'COUNT' => 'count',
        'TIMER' => 'timer',
        _ => 'boolean',
      };

  int get target => kind == 'timer' ? targetMinutes : targetCount;
  int get todayVal => kind == 'timer' ? todayMinutes : todayCount;

  factory Habit.fromJson(Json j) {
    final log = j['todayLog'] as Map<String, dynamic>?;
    return Habit(
      id: asString(j['id']),
      title: asString(j['title']),
      habitType: asString(j['habitType'], 'BOOLEAN'),
      targetCount: asInt(j['targetCount'], 1),
      targetMinutes: asInt(j['targetMinutes']),
      frequency: asString(j['frequency'], 'DAILY'),
      reminderTime: asStringOrNull(j['reminderTime']),
      areaId: asStringOrNull(j['areaId']),
      isActive: asBool(j['isActive'], true),
      currentStreak: asInt(j['currentStreak']),
      longestStreak: asInt(j['longestStreak']),
      todayDone: asBool(j['todayDone']),
      todayCount: asInt(log?['count']),
      todayMinutes: asInt(log?['minutes']),
      history: (j['history'] as List?)
              ?.map((e) => e is Map ? asBool(e['completed']) : asBool(e))
              .toList() ??
          const [],
    );
  }
}
