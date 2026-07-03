import 'json.dart';

class Review {
  final String id;
  final String reviewType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? summary;
  final String? highlights;
  final String? improvements;
  final String? userNote;
  final List<ReviewInsight> insights;
  final Json? aiInsights;

  const Review({
    required this.id,
    required this.reviewType,
    this.periodStart,
    this.periodEnd,
    this.summary,
    this.highlights,
    this.improvements,
    this.userNote,
    this.insights = const [],
    this.aiInsights,
  });

  factory Review.fromJson(Json j) => Review(
        id: asString(j['id']),
        reviewType: asString(j['reviewType'], 'WEEKLY'),
        periodStart: asDate(j['periodStart']),
        periodEnd: asDate(j['periodEnd']),
        summary: asStringOrNull(j['summary']),
        highlights: asStringOrNull(j['highlights']),
        improvements: asStringOrNull(j['improvements']),
        userNote: asStringOrNull(j['userNote']),
        insights: (j['insights'] as List?)
                ?.map((e) => ReviewInsight.fromJson(e as Json))
                .toList() ??
            const [],
        aiInsights:
            j['aiInsights'] is Map ? Json.from(j['aiInsights'] as Map) : null,
      );
}

/// Auto-generated review draft (GET /reviews/draft) — factual period stats,
/// pre-filled editable text, and an AI narrative. The user edits, then saves
/// through the normal POST /reviews.
class ReviewDraft {
  final String reviewType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final ReviewStats stats;
  final String suggestedSummary;
  final String suggestedHighlights;
  final String suggestedImprovements;
  final ReviewAiInsights aiInsights;

  /// Raw aiInsights map — passed straight back to POST /reviews so the
  /// narrative persists exactly as generated.
  final Json aiInsightsRaw;

  const ReviewDraft({
    required this.reviewType,
    this.periodStart,
    this.periodEnd,
    required this.stats,
    required this.suggestedSummary,
    required this.suggestedHighlights,
    required this.suggestedImprovements,
    required this.aiInsights,
    this.aiInsightsRaw = const {},
  });

  factory ReviewDraft.fromJson(Json j) {
    final ai = j['aiInsights'] is Map ? Json.from(j['aiInsights'] as Map) : const <String, dynamic>{};
    return ReviewDraft(
      reviewType: asString(j['reviewType'], 'WEEKLY'),
      periodStart: asDate(j['periodStart']),
      periodEnd: asDate(j['periodEnd']),
      stats: ReviewStats.fromJson(
          j['stats'] is Map ? Json.from(j['stats'] as Map) : const {}),
      suggestedSummary: asString(j['suggestedSummary']),
      suggestedHighlights: asString(j['suggestedHighlights']),
      suggestedImprovements: asString(j['suggestedImprovements']),
      aiInsights: ReviewAiInsights.fromJson(ai),
      aiInsightsRaw: ai,
    );
  }
}

class ReviewStats {
  final int tasksCompleted;
  final int habitsLogged;
  final int focusMinutes;
  final List<({String title, int streak})> topStreaks;
  final List<({String name, int score})> areaScores;
  final List<({String title, int confidence, String label})> activeGoals;

  const ReviewStats({
    this.tasksCompleted = 0,
    this.habitsLogged = 0,
    this.focusMinutes = 0,
    this.topStreaks = const [],
    this.areaScores = const [],
    this.activeGoals = const [],
  });

  factory ReviewStats.fromJson(Json j) => ReviewStats(
        tasksCompleted: asInt(j['tasksCompleted']),
        habitsLogged: asInt(j['habitsLogged']),
        focusMinutes: asInt(j['focusMinutes']),
        topStreaks: ((j['topStreaks'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => (
                  title: asString(e['title']),
                  streak: asInt(e['streak']),
                ))
            .toList(),
        areaScores: ((j['areaScores'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => (
                  name: asString(e['name']),
                  score: asInt(e['score']),
                ))
            .toList(),
        activeGoals: ((j['activeGoals'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => (
                  title: asString(e['title']),
                  confidence: asInt(e['confidence']),
                  label: asString(e['label']),
                ))
            .toList(),
      );
}

class ReviewAiInsights {
  final String narrative;
  final List<String> observations;
  final String source; // ai | heuristic

  const ReviewAiInsights({
    this.narrative = '',
    this.observations = const [],
    this.source = 'heuristic',
  });

  factory ReviewAiInsights.fromJson(Json j) => ReviewAiInsights(
        narrative: asString(j['narrative']),
        observations: asStringList(j['observations']),
        source: asString(j['source'], 'heuristic'),
      );
}

class ReviewInsight {
  final String id;
  final String status; // PENDING | IMPLEMENTED | STILL_WORKING | NOT_APPLICABLE
  final String? userNote;
  final String text;

  const ReviewInsight({
    required this.id,
    required this.status,
    this.userNote,
    required this.text,
  });

  factory ReviewInsight.fromJson(Json j) {
    final note = j['note'] as Map<String, dynamic>?;
    return ReviewInsight(
      id: asString(j['id']),
      status: asString(j['status'], 'PENDING'),
      userNote: asStringOrNull(j['userNote']),
      text: asString(note?['content'] ?? note?['title'] ?? j['text'],
          'Insight'),
    );
  }
}
