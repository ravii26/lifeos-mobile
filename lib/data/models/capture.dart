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

  const Capture({
    required this.id,
    required this.text,
    required this.type,
    required this.confidence,
    required this.processed,
    required this.status,
    this.detectedUrl,
    this.createdAt,
  });

  int get confidencePct => (confidence * 100).round();

  factory Capture.fromJson(Json j) => Capture(
        id: asString(j['id']),
        text: asString(j['text'], asString(j['rawText'])),
        type: asString(j['type'], 'TASK'),
        confidence: asDouble(j['confidence']),
        processed: asBool(j['processed']),
        status: asString(j['status'], 'PENDING'),
        detectedUrl: asStringOrNull(j['detectedUrl']),
        createdAt: asDate(j['createdAt']),
      );
}
