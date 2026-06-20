import 'json.dart';

/// A Note (from GET /notes). Belongs to a Topic; optionally filed in a Notebook.
class Note {
  final String id;
  final String title;
  final String content;
  final String topicId;
  final String? notebookId;
  final String? resourceId;
  final String noteType; // CONCEPT | INSIGHT | SUMMARY | QUOTE | OTHER
  final List<String> tags;
  final DateTime? updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.topicId,
    this.notebookId,
    this.resourceId,
    required this.noteType,
    this.tags = const [],
    this.updatedAt,
  });

  factory Note.fromJson(Json j) => Note(
        id: asString(j['id']),
        title: asString(j['title']),
        content: asString(j['content']),
        topicId: asString(j['topicId']),
        notebookId: asStringOrNull(j['notebookId']),
        resourceId: asStringOrNull(j['resourceId']),
        noteType: asString(j['noteType'], 'CONCEPT'),
        tags: asStringList(j['tags']),
        updatedAt: asDate(j['updatedAt']),
      );
}
