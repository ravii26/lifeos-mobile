import 'dart:ui';

import 'json.dart';

/// An Area with its live score block (from GET /areas).
class Area {
  final String id;
  final String name;
  final String type; // PRIMARY | MAINTENANCE
  final String colorHex;
  final String icon;
  final int order;
  final bool isActive;

  // Live score block
  final int score; // 0..100
  final int tasksDone;
  final int tasksTotal;
  final int streak;
  final int focusMins;

  const Area({
    required this.id,
    required this.name,
    required this.type,
    required this.colorHex,
    required this.icon,
    required this.order,
    required this.isActive,
    required this.score,
    required this.tasksDone,
    required this.tasksTotal,
    required this.streak,
    required this.focusMins,
  });

  Color get color => _parseHex(colorHex);

  factory Area.fromJson(Json j) => Area(
        id: asString(j['id']),
        name: asString(j['name']),
        type: asString(j['type'], 'PRIMARY'),
        colorHex: asString(j['color'], '#c5f23f'),
        icon: asString(j['icon'], 'target'),
        order: asInt(j['order']),
        isActive: asBool(j['isActive'], true),
        // score may arrive as 0..1 or 0..100 depending on backend; normalize.
        score: _normScore(j['score']),
        tasksDone: asInt(j['tasksDone']),
        tasksTotal: asInt(j['tasksTotal']),
        streak: asInt(j['streak']),
        focusMins: asInt(j['focusMins']),
      );

  static int _normScore(dynamic v) {
    final d = asDouble(v);
    if (d <= 1.0) return (d * 100).round();
    return d.round();
  }
}

Color _parseHex(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16) ?? 0xFFC5F23F;
  return Color(v);
}
