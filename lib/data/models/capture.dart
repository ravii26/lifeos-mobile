import 'json.dart';

/// Brain-dump inbox item.
class Capture {
  final String id;
  final String text;
  final String type; // TASK | HABIT | NOTE | RESOURCE | VAULT
  final double confidence; // 0..1
  final bool processed;
  final String status; // PENDING | CONVERTED | DISMISSED
  final String? detectedUrl;
  final DateTime? createdAt;

  /// AI classification hints: title, suggestedAreaId, suggestedTopicId, etc.
  final Json meta;

  /// After conversion — { type, id } pointing at the created entity.
  final Json? createdOutput;

  const Capture({
    required this.id,
    required this.text,
    required this.type,
    required this.confidence,
    required this.processed,
    required this.status,
    this.detectedUrl,
    this.createdAt,
    this.meta = const {},
    this.createdOutput,
  });

  int get confidencePct => (confidence * 100).round();

  String? get suggestedAreaId => asStringOrNull(meta['suggestedAreaId']);
  String? get suggestedTopicId => asStringOrNull(meta['suggestedTopicId']);

  /// Convert needs the user to pick a parent for these types.
  bool get needsArea => type == 'HABIT' && suggestedAreaId == null;
  bool get needsTopic =>
      (type == 'NOTE' || type == 'RESOURCE') && suggestedTopicId == null;

  factory Capture.fromJson(Json j) => Capture(
        id: asString(j['id']),
        text: asString(j['text'], asString(j['rawText'])),
        type: asString(j['type'], 'TASK'),
        confidence: asDouble(j['confidence']),
        processed: asBool(j['processed']),
        status: asString(j['status'], 'PENDING'),
        detectedUrl: asStringOrNull(j['detectedUrl']),
        createdAt: asDate(j['createdAt']),
        meta: j['meta'] is Map ? Json.from(j['meta'] as Map) : const {},
        createdOutput: j['createdOutput'] is Map
            ? Json.from(j['createdOutput'] as Map)
            : null,
      );
}
