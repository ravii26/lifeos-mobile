import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/graph_data.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/screen_header.dart';

const double _canvas = 1200;

/// Colour per node type. Not a const map because the palette is mutable
/// (theme can re-skin AppColors at runtime).
Color _typeColor(String type) => switch (type) {
      'AREA' => AppColors.accent,
      'GOAL' => AppColors.warn,
      'PROJECT' => AppColors.career,
      'HABIT' => AppColors.health,
      'TOPIC' => const Color(0xFFA78BFA),
      'NOTEBOOK' => AppColors.relationships,
      'NOTE' => AppColors.tx4,
      _ => AppColors.tx3,
    };

Color _colorFor(GraphNode n) {
  if (n.type == 'AREA') {
    final hex = n.data['color'];
    if (hex is String && hex.isNotEmpty) return _hex(hex);
    return AppColors.accent;
  }
  return _typeColor(n.type);
}

Color _hex(String h) {
  var s = h.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFFC5F23F);
}

double _radiusFor(String type) => switch (type) {
      'AREA' => 14,
      'GOAL' => 10,
      'TOPIC' => 9,
      'PROJECT' => 8,
      'HABIT' => 8,
      'NOTEBOOK' => 7,
      _ => 5,
    };

double _depthFor(String type) => switch (type) {
      'GOAL' || 'HABIT' || 'TOPIC' => 0.30,
      'PROJECT' || 'NOTEBOOK' => 0.40,
      _ => 0.50,
    };

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  late Future<GraphData> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().graph();
  }

  void _reload() => setState(() => _future = getIt<LifeRepository>().graph());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.surface3,
        foregroundColor: AppColors.tx,
        onPressed: _reload,
        child: const Icon(Icons.refresh, size: 20),
      ),
      body: Column(
        children: [
          BackHeader(eyebrow: 'Connections', title: 'Knowledge graph'),
          Expanded(
            child: FutureBuilder<GraphData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent));
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Could not load graph.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.tx4, fontSize: 12)),
                  );
                }
                final data = snap.data!;
                if (data.nodes.isEmpty) {
                  return Center(
                    child: Text(
                        'Nothing connected yet.\nAdd areas, goals and notes to grow your graph.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.tx4, fontSize: 13)),
                  );
                }
                final positions = _layout(data);
                return InteractiveViewer(
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 2.5,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: CustomPaint(
                    size: const Size(_canvas, _canvas),
                    painter: _GraphPainter(data, positions),
                  ),
                );
              },
            ),
          ),
          _legend(),
        ],
      ),
    );
  }

  Widget _legend() {
    const order = [
      'AREA',
      'GOAL',
      'PROJECT',
      'TASK',
      'HABIT',
      'TOPIC',
      'NOTEBOOK',
      'NOTE'
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          for (final t in order)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _typeColor(t),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(t[0] + t.substring(1).toLowerCase(),
                    style: TextStyle(fontSize: 11, color: AppColors.tx3)),
              ],
            ),
        ],
      ),
    );
  }

  /// Deterministic radial cluster: AREA nodes ring the centre; everything else
  /// is propagated outward to the area it connects to and fanned into that sector.
  Map<String, Offset> _layout(GraphData data) {
    final pos = <String, Offset>{};
    final center = const Offset(_canvas / 2, _canvas / 2);
    final areas = data.nodes.where((n) => n.type == 'AREA').toList();
    final nA = math.max(areas.length, 1);
    const rA = _canvas * 0.16;

    for (var i = 0; i < areas.length; i++) {
      final ang = -math.pi / 2 + 2 * math.pi * i / nA;
      pos[areas[i].id] =
          center + Offset(math.cos(ang) * rA, math.sin(ang) * rA);
    }

    // Propagate an area assignment outward along edges.
    final assigned = <String, String>{for (final a in areas) a.id: a.id};
    for (var pass = 0; pass < 6; pass++) {
      for (final e in data.edges) {
        final s = assigned[e.source];
        final t = assigned[e.target];
        if (s != null && t == null) {
          assigned[e.target] = s;
        } else if (t != null && s == null) {
          assigned[e.source] = t;
        }
      }
    }

    // Group children per area.
    final byArea = <String, List<GraphNode>>{};
    final unassigned = <GraphNode>[];
    for (final n in data.nodes) {
      if (n.type == 'AREA') continue;
      final a = assigned[n.id];
      if (a == null) {
        unassigned.add(n);
      } else {
        (byArea[a] ??= []).add(n);
      }
    }

    for (var i = 0; i < areas.length; i++) {
      final children = byArea[areas[i].id] ?? const [];
      final baseAngle = -math.pi / 2 + 2 * math.pi * i / nA;
      final spread = (2 * math.pi / nA) * 0.82;
      final n = children.length;
      for (var k = 0; k < n; k++) {
        final frac = n <= 1 ? 0.5 : k / (n - 1);
        final ang = baseAngle + spread * (frac - 0.5);
        final r = _canvas * _depthFor(children[k].type) + (k % 4) * 11;
        pos[children[k].id] =
            center + Offset(math.cos(ang) * r, math.sin(ang) * r);
      }
    }

    // Orphans: tidy grid bottom-left.
    const cols = 8;
    for (var k = 0; k < unassigned.length; k++) {
      pos[unassigned[k].id] = Offset(
          70 + (k % cols) * 80.0, _canvas - 120 + (k ~/ cols) * 46.0);
    }
    return pos;
  }
}

class _GraphPainter extends CustomPainter {
  final GraphData data;
  final Map<String, Offset> pos;
  _GraphPainter(this.data, this.pos);

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppColors.line2
      ..strokeWidth = 1;
    for (final e in data.edges) {
      final a = pos[e.source];
      final b = pos[e.target];
      if (a != null && b != null) canvas.drawLine(a, b, edgePaint);
    }

    for (final n in data.nodes) {
      final p = pos[n.id];
      if (p == null) continue;
      final color = _colorFor(n);
      final r = _radiusFor(n.type);
      canvas.drawCircle(
          p, r, Paint()..color = color.withValues(alpha: 0.9));
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.bg);

      // Labels only for the structural nodes, to keep it readable.
      if (n.type == 'AREA' || n.type == 'GOAL' || n.type == 'TOPIC') {
        _label(canvas, n.label, p + Offset(0, r + 9),
            n.type == 'AREA' ? 12 : 10, color);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text.length > 22 ? '${text.substring(0, 21)}…' : text,
        style: TextStyle(
            fontSize: size,
            color: AppColors.tx,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: ui.Color(0xCC0A0C08), blurRadius: 4)]),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.data != data || old.pos != pos;
}
