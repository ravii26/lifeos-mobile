import 'json.dart';

/// A behavioral event (GET /behavior).
class BehaviorLog {
  final String id;
  final String eventType;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const BehaviorLog({
    required this.id,
    required this.eventType,
    this.metadata = const {},
    this.createdAt,
  });

  factory BehaviorLog.fromJson(Json j) => BehaviorLog(
        id: asString(j['id']),
        eventType: asString(j['eventType']),
        metadata: j['metadata'] is Map
            ? (j['metadata'] as Map).cast<String, dynamic>()
            : const {},
        createdAt: asDate(j['createdAt']),
      );
}
