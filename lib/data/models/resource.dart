import 'json.dart';

/// A learning resource (course / book / video) — used on the Learn screen.
class Resource {
  final String id;
  final String title;
  final String resourceType;
  final String? platform;
  final String status;
  final String? topicId;
  final int totalLessons;
  final int lessonsCompleted;
  final int minutesConsumed;

  const Resource({
    required this.id,
    required this.title,
    required this.resourceType,
    this.platform,
    required this.status,
    this.topicId,
    required this.totalLessons,
    required this.lessonsCompleted,
    required this.minutesConsumed,
  });

  double get progress =>
      totalLessons == 0 ? 0 : (lessonsCompleted / totalLessons).clamp(0, 1);

  factory Resource.fromJson(Json j) => Resource(
        id: asString(j['id']),
        title: asString(j['title']),
        resourceType: asString(j['resourceType'], 'COURSE'),
        platform: asStringOrNull(j['platform']),
        status: asString(j['status'], 'ACTIVE'),
        topicId: asStringOrNull(j['topicId']),
        totalLessons: asInt(j['totalLessons']),
        lessonsCompleted: asInt(j['lessonsCompleted']),
        minutesConsumed: asInt(j['minutesConsumed']),
      );
}
