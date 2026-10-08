import 'json.dart';

/// The guide's pick for one night (GET /guide/tonight).
class Commitment {
  final String id;
  final String date; // YYYY-MM-DD, the night it belongs to
  final String sourceType; // TASK | HABIT
  final String sourceId;
  final String title;
  final String minimum;
  final String why;
  final String message;
  final String mode; // NORMAL | SMALLER
  final String status; // PENDING | DONE | MINIMUM | SKIPPED
  final String? skipReason;
  // Present right after answering: lets the screen offer Undo.
  final String? activityId;

  const Commitment({
    required this.id,
    required this.date,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.minimum,
    required this.why,
    required this.message,
    required this.mode,
    required this.status,
    this.skipReason,
    this.activityId,
  });

  Commitment withStatus(String s) => Commitment(
        id: id,
        date: date,
        sourceType: sourceType,
        sourceId: sourceId,
        title: title,
        minimum: minimum,
        why: why,
        message: message,
        mode: mode,
        status: s,
        skipReason: skipReason,
      );

  bool get isPending => status == 'PENDING';
  bool get isSmaller => mode == 'SMALLER';

  factory Commitment.fromJson(Json j) => Commitment(
        id: asString(j['id']),
        date: asString(j['date']).split('T').first,
        sourceType: asString(j['sourceType'], 'TASK'),
        sourceId: asString(j['sourceId']),
        title: asString(j['title']),
        minimum: asString(j['minimum']),
        why: asString(j['why']),
        message: asString(j['message']),
        mode: asString(j['mode'], 'NORMAL'),
        status: asString(j['status'], 'PENDING'),
        skipReason: asStringOrNull(j['skipReason']),
        activityId: asStringOrNull(j['activityId']),
      );
}

class Tonight {
  final String date;
  final Commitment? commitment;
  final String? emptyMessage;
  final int missedNights;

  const Tonight({
    required this.date,
    this.commitment,
    this.emptyMessage,
    this.missedNights = 0,
  });

  factory Tonight.fromJson(Json j) => Tonight(
        date: asString(j['date']),
        commitment:
            j['commitment'] is Json ? Commitment.fromJson(j['commitment'] as Json) : null,
        emptyMessage: asStringOrNull(j['emptyMessage']),
        missedNights: asInt(j['missedNights']),
      );
}

/// "One more?" suggestion after tonight's thing is done (GET /guide/next).
class NextStep {
  final String sourceType;
  final String sourceId;
  final String title;
  final String minimum;
  final String why;

  const NextStep({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.minimum,
    required this.why,
  });

  factory NextStep.fromJson(Json j) => NextStep(
        sourceType: asString(j['sourceType'], 'TASK'),
        sourceId: asString(j['sourceId']),
        title: asString(j['title']),
        minimum: asString(j['minimum']),
        why: asString(j['why']),
      );
}

class NightDay {
  final String date;
  final String status;
  const NightDay(this.date, this.status);
}

class GuideHistory {
  final List<NightDay> days;
  final int followThroughDays;

  const GuideHistory({required this.days, required this.followThroughDays});

  factory GuideHistory.fromJson(Json j) => GuideHistory(
        days: ((j['days'] as List?) ?? const [])
            .whereType<Json>()
            .map((d) => NightDay(asString(d['date']), asString(d['status'])))
            .toList(),
        followThroughDays: asInt(j['followThroughDays']),
      );
}

/// One step proposed from a save: a to-do, or a habit if it is worth repeating.
class SaveActionDraft {
  final String action;
  final String minimum;
  final String as; // TODO | HABIT
  final String when; // TONIGHT | THIS_WEEK | LATER
  const SaveActionDraft(this.action, this.minimum, this.as, this.when);

  factory SaveActionDraft.fromJson(Json j) => SaveActionDraft(
        asString(j['action']),
        asString(j['minimum']),
        asString(j['as'], 'TODO'),
        asString(j['when'], 'THIS_WEEK'),
      );
}

/// What the guide drafted for something the person saved (POST /guide/saves).
class SaveProposal {
  final String id;
  final String? url;
  final String? platform;
  final String? author;
  final String contentTitle;
  final String kind; // LEARN | DO | MOTIVATION | ENTERTAINMENT | OTHER
  final String action;
  final String minimum;
  final String? areaId;
  final String when; // TONIGHT | THIS_WEEK | LATER
  final String reason;
  final String purpose; // LEARN | FEELING (Ally's guess, one tap to correct)
  final List<String> feelings; // for a FEELING save: lazy, low, anxious…
  final List<SaveActionDraft> actions; // 1 to 3 steps
  final String summaryState; // NONE | PENDING | READY | UNAVAILABLE
  final List<String> summaryLines; // what the video says, when it was watched
  final bool shelved; // feeling saves wait on the shelf for that feeling

  const SaveProposal({
    required this.id,
    this.url,
    this.platform,
    this.author,
    required this.contentTitle,
    required this.kind,
    required this.action,
    required this.minimum,
    this.areaId,
    required this.when,
    required this.reason,
    this.purpose = 'LEARN',
    this.feelings = const [],
    this.actions = const [],
    this.summaryState = 'NONE',
    this.summaryLines = const [],
    this.shelved = false,
  });

  bool get looksLikeMotivation => kind == 'MOTIVATION';

  factory SaveProposal.fromJson(Json j) {
    final p = (j['proposal'] as Json?) ?? const {};
    return SaveProposal(
      id: asString(j['id']),
      url: asStringOrNull(j['url']),
      platform: asStringOrNull(j['platform']),
      author: asStringOrNull(j['author']),
      contentTitle: asString(p['contentTitle'], 'Your save'),
      kind: asString(p['kind'], 'OTHER'),
      action: asString(p['action']),
      minimum: asString(p['minimum']),
      areaId: asStringOrNull(p['areaId']),
      when: asString(p['when'], 'THIS_WEEK'),
      reason: asString(p['reason']),
      purpose: asString(p['purpose'], 'LEARN'),
      feelings: ((p['feelings'] as List?) ?? const []).map((e) => e.toString()).toList(),
      actions: ((p['actions'] as List?) ?? const []).whereType<Json>().map(SaveActionDraft.fromJson).toList(),
      summaryState: asString((j['summary'] as Json?)?['state'], 'NONE'),
      summaryLines: (((j['summary'] as Json?)?['lines'] as List?) ?? const []).map((e) => e.toString()).toList(),
      shelved: asBool(j['shelved']),
    );
  }
}
