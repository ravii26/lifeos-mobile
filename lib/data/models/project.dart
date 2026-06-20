import 'json.dart';

/// A Project (from GET /projects). Optionally linked to a Goal via [goalId].
class Project {
  final String id;
  final String title;
  final String? description;
  final String areaId;
  final String? goalId;
  final String status; // ACTIVE | COMPLETED | PAUSED | ABANDONED
  final DateTime? deadline;

  const Project({
    required this.id,
    required this.title,
    this.description,
    required this.areaId,
    this.goalId,
    required this.status,
    this.deadline,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isClosed =>
      status == 'COMPLETED' || status == 'ABANDONED' || status == 'PAUSED';

  factory Project.fromJson(Json j) => Project(
        id: asString(j['id']),
        title: asString(j['title']),
        description: asStringOrNull(j['description']),
        areaId: asString(j['areaId']),
        goalId: asStringOrNull(j['goalId']),
        status: asString(j['status'], 'ACTIVE'),
        deadline: asDate(j['deadline']),
      );
}
