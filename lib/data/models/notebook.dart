import 'json.dart';

/// A Notebook (from GET /notebooks). Lives under a Topic; groups Notes.
class Notebook {
  final String id;
  final String title;
  final String? description;
  final String topicId;
  final List<String> tags;

  const Notebook({
    required this.id,
    required this.title,
    this.description,
    required this.topicId,
    this.tags = const [],
  });

  factory Notebook.fromJson(Json j) => Notebook(
        id: asString(j['id']),
        title: asString(j['title']),
        description: asStringOrNull(j['description']),
        topicId: asString(j['topicId']),
        tags: asStringList(j['tags']),
      );
}
