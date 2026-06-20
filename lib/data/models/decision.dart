import 'json.dart';

/// Response of GET /decisions/now — the "what should I do right now" payload.
class DecisionResult {
  final String headline;
  final String briefing;
  final String tone; // encouraging | firm | celebratory | neutral
  final PrimaryAction? primaryAction;
  final List<Suggestion> suggestions;
  final NeglectedArea? neglectedArea;
  final String todayFocus;
  final String behaviorInsight;
  final String weeklyPattern;
  final List<StreakAlert> streakAlerts;
  final String source; // ai | heuristic

  const DecisionResult({
    required this.headline,
    required this.briefing,
    required this.tone,
    this.primaryAction,
    this.suggestions = const [],
    this.neglectedArea,
    required this.todayFocus,
    required this.behaviorInsight,
    required this.weeklyPattern,
    this.streakAlerts = const [],
    required this.source,
  });

  factory DecisionResult.fromJson(Json j) => DecisionResult(
        headline: asString(j['headline']),
        briefing: asString(j['briefing']),
        tone: asString(j['tone'], 'neutral'),
        primaryAction: j['primaryAction'] is Map
            ? PrimaryAction.fromJson(j['primaryAction'] as Json)
            : null,
        suggestions: (j['suggestions'] as List?)
                ?.map((e) => Suggestion.fromJson(e as Json))
                .toList() ??
            const [],
        neglectedArea: j['neglectedArea'] is Map
            ? NeglectedArea.fromJson(j['neglectedArea'] as Json)
            : null,
        todayFocus: asString(j['todayFocus']),
        behaviorInsight: asString(j['behaviorInsight']),
        weeklyPattern: asString(j['weeklyPattern']),
        streakAlerts: (j['streakAlerts'] as List?)
                ?.map((e) => StreakAlert.fromJson(e as Json))
                .toList() ??
            const [],
        source: asString(j['source'], 'heuristic'),
      );
}

class PrimaryAction {
  final String type; // TASK | HABIT | AREA_FOCUS | REVIEW | GOAL
  final String? refId;
  final String title;
  final String why;
  final int? estimatedMinutes;

  const PrimaryAction({
    required this.type,
    this.refId,
    required this.title,
    required this.why,
    this.estimatedMinutes,
  });

  factory PrimaryAction.fromJson(Json j) => PrimaryAction(
        type: asString(j['type'], 'TASK'),
        refId: asStringOrNull(j['refId']),
        title: asString(j['title']),
        why: asString(j['why']),
        estimatedMinutes:
            j['estimatedMinutes'] == null ? null : asInt(j['estimatedMinutes']),
      );
}

class Suggestion {
  final int rank;
  final String type;
  final String? refId;
  final String title;
  final String reason;
  final String urgency; // HIGH | MEDIUM | LOW
  final List<String> actionableSteps;

  const Suggestion({
    required this.rank,
    required this.type,
    this.refId,
    required this.title,
    required this.reason,
    required this.urgency,
    this.actionableSteps = const [],
  });

  factory Suggestion.fromJson(Json j) => Suggestion(
        rank: asInt(j['rank']),
        type: asString(j['type'], 'TASK'),
        refId: asStringOrNull(j['refId']),
        title: asString(j['title']),
        reason: asString(j['reason']),
        urgency: asString(j['urgency'], 'MEDIUM'),
        actionableSteps: asStringList(j['actionableSteps']),
      );
}

class StreakAlert {
  final String habitId;
  final String title;
  final int streakDays;
  final String message;

  const StreakAlert({
    required this.habitId,
    required this.title,
    required this.streakDays,
    required this.message,
  });

  factory StreakAlert.fromJson(Json j) => StreakAlert(
        habitId: asString(j['habitId']),
        title: asString(j['title']),
        streakDays: asInt(j['streakDays']),
        message: asString(j['message']),
      );
}

class NeglectedArea {
  final String id;
  final String name;
  final int score;
  final String insight;

  const NeglectedArea({
    required this.id,
    required this.name,
    required this.score,
    required this.insight,
  });

  factory NeglectedArea.fromJson(Json j) => NeglectedArea(
        id: asString(j['id']),
        name: asString(j['name']),
        score: asInt(j['score']),
        insight: asString(j['insight']),
      );
}
