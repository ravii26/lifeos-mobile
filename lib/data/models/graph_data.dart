import 'json.dart';

/// Knowledge graph (GET /graph) — nodes + edges across the user's data.
class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const GraphData({this.nodes = const [], this.edges = const []});

  factory GraphData.fromJson(Json j) => GraphData(
        nodes: (j['nodes'] as List?)
                ?.map((e) => GraphNode.fromJson(e as Json))
                .toList() ??
            const [],
        edges: (j['edges'] as List?)
                ?.map((e) => GraphEdge.fromJson(e as Json))
                .toList() ??
            const [],
      );
}

class GraphNode {
  final String id;
  // AREA | GOAL | PROJECT | TASK | HABIT | TOPIC | NOTEBOOK | NOTE | RESOURCE
  final String type;
  final String label;
  final Map<String, dynamic> data;

  const GraphNode({
    required this.id,
    required this.type,
    required this.label,
    this.data = const {},
  });

  factory GraphNode.fromJson(Json j) => GraphNode(
        id: asString(j['id']),
        type: asString(j['type']),
        label: asString(j['label']),
        data: j['data'] is Map
            ? (j['data'] as Map).cast<String, dynamic>()
            : const {},
      );
}

class GraphEdge {
  final String source;
  final String target;
  // AREA_GOAL | AREA_HABIT | AREA_TOPIC | GOAL_PROJECT | PROJECT_TASK |
  // AREA_TASK | TOPIC_TASK | TOPIC_NOTEBOOK | TOPIC_NOTE | TOPIC_RESOURCE |
  // RESOURCE_NOTE
  final String relation;

  const GraphEdge({
    required this.source,
    required this.target,
    required this.relation,
  });

  factory GraphEdge.fromJson(Json j) => GraphEdge(
        source: asString(j['source']),
        target: asString(j['target']),
        // Server serializes the edge kind as `relation`; fall back to `type`
        // for older payloads.
        relation: asString(j['relation'], asString(j['type'])),
      );
}
