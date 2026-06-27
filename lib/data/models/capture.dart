import 'json.dart';

/// Brain-dump inbox item.
///
/// Capture is now asynchronous: POST /captures returns immediately with the
/// raw text in a PENDING/unclassified state. `confidence`, `worthCheck` and
/// `worthReason` stay null until the background AI classification lands
/// (~1-2s later), so the client must refetch to surface the result.
class Capture {
  final String id;
  final String text;
  final String type; // TASK | HABIT | NOTE | RESOURCE | VAULT
  final double? confidence; // 0..1, null until classified
  final bool processed;
  final String status; // PENDING | CONVERTED | DISMISSED
  final String? detectedUrl;
  final DateTime? createdAt;

  /// AI worth-triage: act on it now, save for later, or not relevant — and why.
  /// null until background classification has run.
  final String? worthCheck; // WORTH_NOW | SAVE_LATER | NOT_RELEVANT
  final String? worthReason;

  /// AI classification hints: title, suggestedAreaId, suggestedTopicId, etc.
  final Json meta;

  /// After conversion — { type, id } pointing at the created entity.
  final Json? createdOutput;

  const Capture({
    required this.id,
    required this.text,
    required this.type,
    this.confidence,
    required this.processed,
    required this.status,
    this.detectedUrl,
    this.createdAt,
    this.worthCheck,
    this.worthReason,
    this.meta = const {},
    this.createdOutput,
  });

  /// True once the background AI classification has produced a confidence
  /// score. Until then the inbox should show a "sorting…" state.
  bool get isClassified => confidence != null;

  int? get confidencePct =>
      confidence == null ? null : (confidence! * 100).round();

  /// The AI flagged this as worth acting on right now.
  bool get isWorthNow => worthCheck == 'WORTH_NOW';

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
        confidence: asDoubleOrNull(j['confidence']),
        processed: asBool(j['processed']),
        status: asString(j['status'], 'PENDING'),
        detectedUrl: asStringOrNull(j['detectedUrl']),
        createdAt: asDate(j['createdAt']),
        worthCheck: asStringOrNull(j['worthCheck']),
        worthReason: asStringOrNull(j['worthReason']),
        meta: j['meta'] is Map ? Json.from(j['meta'] as Map) : const {},
        createdOutput: j['createdOutput'] is Map
            ? Json.from(j['createdOutput'] as Map)
            : null,
      );
}
