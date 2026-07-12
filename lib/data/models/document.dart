import 'json.dart';

/// A reference document the user pasted/uploaded into the Library. Chunked and
/// embedded on the server so it can be asked questions (RAG) and mined for
/// actionable Habits/Goals/Tasks.
class LibraryDocument {
  final String id;
  final String title;
  final String sourceType; // PASTED | UPLOADED
  final String status; // PENDING | READY | FAILED
  final int chunkCount;
  final String? error;
  final DateTime? createdAt;

  const LibraryDocument({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.status,
    required this.chunkCount,
    this.error,
    this.createdAt,
  });

  bool get isReady => status == 'READY';
  bool get isPending => status == 'PENDING';
  bool get isFailed => status == 'FAILED';

  factory LibraryDocument.fromJson(Json j) => LibraryDocument(
        id: asString(j['id']),
        title: asString(j['title'], 'Untitled document'),
        sourceType: asString(j['sourceType'], 'PASTED'),
        status: asString(j['status'], 'PENDING'),
        chunkCount: asInt(j['chunkCount']),
        error: asStringOrNull(j['error']),
        createdAt: asDate(j['createdAt']),
      );
}

/// One passage an answer was drawn from — a Document, Note, or Resource.
class AskSource {
  final String sourceType; // DOCUMENT | NOTE | RESOURCE
  final String sourceId;
  final String sourceTitle;
  final String? heading;
  final String snippet;
  final double score;

  const AskSource({
    required this.sourceType,
    required this.sourceId,
    required this.sourceTitle,
    this.heading,
    required this.snippet,
    required this.score,
  });

  factory AskSource.fromJson(Json j) => AskSource(
        sourceType: asString(j['sourceType'], 'DOCUMENT'),
        sourceId: asString(j['sourceId']),
        sourceTitle: asString(j['sourceTitle']),
        heading: asStringOrNull(j['heading']),
        snippet: asString(j['snippet']),
        score: asDouble(j['score']),
      );
}

/// The result of asking the Library a question.
class AskResult {
  final String answer;
  final List<AskSource> sources;
  final bool usedAi;

  const AskResult({
    required this.answer,
    this.sources = const [],
    this.usedAi = false,
  });

  factory AskResult.fromJson(Json j) => AskResult(
        answer: asString(j['answer']),
        sources: (j['sources'] as List? ?? const [])
            .map((e) => AskSource.fromJson(Json.from(e as Map)))
            .toList(),
        usedAi: asBool(j['usedAi']),
      );
}

/// An AI-extracted action proposed from a document, awaiting the user's
/// confirmation before it becomes a real Task/Habit/Goal.
class DocumentSuggestion {
  final String id;
  final String documentId;
  final String itemType; // HABIT | GOAL | TASK
  final String title;
  final String? detail;
  final double confidence;
  final String status; // PENDING | ACCEPTED | DISMISSED
  final String? suggestedAreaId;
  final String? suggestedAreaName;
  final String? frequency;
  final int? targetMinutes;
  final String? priority;
  final String? dueDate;

  const DocumentSuggestion({
    required this.id,
    required this.documentId,
    required this.itemType,
    required this.title,
    this.detail,
    required this.confidence,
    required this.status,
    this.suggestedAreaId,
    this.suggestedAreaName,
    this.frequency,
    this.targetMinutes,
    this.priority,
    this.dueDate,
  });

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';

  /// Habits and Goals require an area; Tasks can be created area-less.
  bool get needsArea => itemType == 'HABIT' || itemType == 'GOAL';

  int get confidencePct => (confidence * 100).round();

  factory DocumentSuggestion.fromJson(Json j) => DocumentSuggestion(
        id: asString(j['id']),
        documentId: asString(j['documentId']),
        itemType: asString(j['itemType'], 'TASK'),
        title: asString(j['title']),
        detail: asStringOrNull(j['detail']),
        confidence: asDouble(j['confidence'], 0.7),
        status: asString(j['status'], 'PENDING'),
        suggestedAreaId: asStringOrNull(j['suggestedAreaId']),
        suggestedAreaName: asStringOrNull(j['suggestedAreaName']),
        frequency: asStringOrNull(j['frequency']),
        targetMinutes: j['targetMinutes'] == null ? null : asInt(j['targetMinutes']),
        priority: asStringOrNull(j['priority']),
        dueDate: asStringOrNull(j['dueDate']),
      );
}
