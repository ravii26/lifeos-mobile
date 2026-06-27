import 'json.dart';

/// Maps backend Priority enum <-> design's P1/P2/P3 labels.
class Priority {
  static const high = 'HIGH';
  static const medium = 'MEDIUM';
  static const low = 'LOW';

  /// Design label (P1/P2/P3) for a backend priority.
  static String label(String p) => switch (p.toUpperCase()) {
        'HIGH' || 'URGENT' || 'P1' => 'P1',
        'MEDIUM' || 'P2' => 'P2',
        _ => 'P3',
      };

  /// Backend value for a design label.
  static String fromLabel(String label) => switch (label.toUpperCase()) {
        'P1' => high,
        'P2' => medium,
        _ => low,
      };
}

class Task {
  final String id;
  final String title;
  final String status; // TaskStatus enum
  final String priority; // backend Priority
  final String taskType; // STANDARD | COUNT | TIMER ...
  final int targetCount;
  final int completedCount;
  final int targetMinutes;
  final DateTime? dueDate;
  final String? areaId;
  final String? projectId;
  final String? goalId;
  final String? source; // MANUAL | DUMP | LEARN

  const Task({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.taskType,
    required this.targetCount,
    required this.completedCount,
    required this.targetMinutes,
    this.dueDate,
    this.areaId,
    this.projectId,
    this.goalId,
    this.source,
  });

  bool get isDone => status.toUpperCase() == 'COMPLETED';
  String get priorityLabel => Priority.label(priority);

  /// 'count' | 'timer' | 'standard' — mirrors the design's task.type.
  String get kind => switch (taskType.toUpperCase()) {
        'COUNT' => 'count',
        'TIMER' => 'timer',
        _ => 'standard',
      };

  factory Task.fromJson(Json j) => Task(
        id: asString(j['id']),
        title: asString(j['title']),
        status: asString(j['status'], 'PENDING'),
        priority: asString(j['priority'], 'MEDIUM'),
        taskType: asString(j['taskType'], 'STANDARD'),
        targetCount: asInt(j['targetCount']),
        completedCount: asInt(j['completedCount']),
        targetMinutes: asInt(j['targetMinutes']),
        dueDate: asDate(j['dueDate']),
        areaId: asStringOrNull(j['areaId']),
        projectId: asStringOrNull(j['projectId']),
        goalId: asStringOrNull(j['goalId']),
        source: asStringOrNull(j['source']),
      );
}
