import 'json.dart';

/// A Goal (from GET /goals). When the list is requested with
/// `?withConfidence=true`, each goal carries a nested confidence block.
class Goal {
  final String id;
  final String title;
  final String? description;
  final String areaId;
  final String priority; // LOW | MEDIUM | HIGH | CRITICAL
  final String status; // ACTIVE | PARKED | COMPLETED | PAUSED | ABANDONED
  final DateTime? deadline;
  final DateTime? activatedAt;
  final DateTime? parkedAt;

  // Live confidence block (only present with ?withConfidence=true).
  final int? confidence; // 0..100
  final String? confidenceLabel; // ON_TRACK | AT_RISK | OFF_TRACK

  const Goal({
    required this.id,
    required this.title,
    this.description,
    required this.areaId,
    required this.priority,
    required this.status,
    this.deadline,
    this.activatedAt,
    this.parkedAt,
    this.confidence,
    this.confidenceLabel,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isParked => status == 'PARKED';
  bool get isClosed =>
      status == 'COMPLETED' || status == 'ABANDONED' || status == 'PAUSED';

  factory Goal.fromJson(Json j) {
    int? conf;
    String? label;
    final c = j['confidence'];
    if (c is Map) {
      conf = asInt(c['confidence']);
      label = asStringOrNull(c['label']);
    } else if (c is num) {
      conf = c.toInt();
    }
    return Goal(
      id: asString(j['id']),
      title: asString(j['title']),
      description: asStringOrNull(j['description']),
      areaId: asString(j['areaId']),
      priority: asString(j['priority'], 'MEDIUM'),
      status: asString(j['status'], 'ACTIVE'),
      deadline: asDate(j['deadline']),
      activatedAt: asDate(j['activatedAt']),
      parkedAt: asDate(j['parkedAt']),
      confidence: conf,
      confidenceLabel: label,
    );
  }
}
