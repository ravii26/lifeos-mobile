import 'json.dart';

/// A Topic (from GET /topics). Lives under an Area; parents Notebooks & Notes.
class Topic {
  final String id;
  final String title;
  final String? description;
  final String areaId;
  final String masteryLevel; // BEGINNER | INTERMEDIATE | ADVANCED | EXPERT

  const Topic({
    required this.id,
    required this.title,
    this.description,
    required this.areaId,
    required this.masteryLevel,
  });

  factory Topic.fromJson(Json j) => Topic(
        id: asString(j['id']),
        title: asString(j['title']),
        description: asStringOrNull(j['description']),
        areaId: asString(j['areaId']),
        masteryLevel: asString(j['masteryLevel'], 'BEGINNER'),
      );
}
