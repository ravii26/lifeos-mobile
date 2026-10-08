import 'json.dart';

/// One choice in an "which one did you mean?" question.
class AskOption {
  final String id;
  final String title;
  final int minutes; // NOW_PICK: how long it takes now
  final bool smaller;
  const AskOption(this.id, this.title, [this.minutes = 0, this.smaller = false]);
}

/// More planned for today than there is free time: what could move to later.
class ChatCapacity {
  final String message;
  final List<String> moveIds;
  final int keepCount;
  final bool moved;
  final String? moveActivityId; // Undo for the move
  final bool undone;
  const ChatCapacity(this.message, this.moveIds, this.keepCount, {this.moved = false, this.moveActivityId, this.undone = false});

  ChatCapacity copyWith({bool? moved, String? moveActivityId, bool? undone}) => ChatCapacity(message, moveIds, keepCount,
      moved: moved ?? this.moved, moveActivityId: moveActivityId ?? this.moveActivityId, undone: undone ?? this.undone);

  factory ChatCapacity.fromJson(Json j) => ChatCapacity(
        asString(j['message'] ?? j['text']),
        ((j['moveIds'] as List?) ?? ((j['move'] as List?) ?? const []).whereType<Json>().map((m) => m['id'])).map((e) => e.toString()).toList(),
        (j['keepCount'] as num?)?.toInt() ?? ((j['keep'] as List?)?.length ?? 0),
        moved: asBool(j['moved']),
        moveActivityId: asStringOrNull(j['moveActivityId']),
        undone: asBool(j['undone']),
      );

  Json toJson() => {
        'message': message,
        'moveIds': moveIds,
        'keepCount': keepCount,
        if (moved) 'moved': true,
        if (moveActivityId != null) 'moveActivityId': moveActivityId,
        if (undone) 'undone': true,
      };
}

/// Something the assistant actually did during a chat turn.
class ChatAction {
  // TASK_ADDED | TASK_COMPLETED | HABIT_LOGGED | REMINDER_SET | HABIT_ADDED | PROJECT_ADDED | NOTE_ADDED
  // | NUDGE_SET | REMEMBERED | FORGOT | OPEN_SAVE | ASK | NOW_PICK | MODE_SET | SCHEDULE_SET | STAND | PROGRESS_LOGGED | PROJECT_STATUS | WEEK_CARD
  final String type;
  final String? id;
  final String text; // title / reminder text / shared text / the question (ASK)
  final DateTime? remindAt;
  final DateTime? windowEnd; // REMINDER_SET: "sometime between remindAt and windowEnd"
  final String? repeatRule; // REMINDER_SET: RRULE, e.g. FREQ=WEEKLY;BYDAY=SU
  final String? kind; // NUDGE_SET: NIGHTLY | MORNING; PROJECT_ADDED: project kind
  final String? time; // NUDGE_SET: HH:mm, or null when turned off
  final String? activityId; // for Undo
  final bool undone;
  final List<String> items; // NOTE_ADDED
  final int tasks; // PROJECT_ADDED: starter to-dos
  final String? detail; // HABIT_ADDED: time block; PROJECT_ADDED: deadline
  final List<AskOption> options; // ASK

  const ChatAction(
      {required this.type,
      this.id,
      required this.text,
      this.remindAt,
      this.windowEnd,
      this.repeatRule,
      this.kind,
      this.time,
      this.activityId,
      this.undone = false,
      this.items = const [],
      this.tasks = 0,
      this.detail,
      this.options = const []});

  ChatAction copyWith({String? text, bool? undone}) => ChatAction(
      type: type,
      id: id,
      text: text ?? this.text,
      remindAt: remindAt,
      windowEnd: windowEnd,
      repeatRule: repeatRule,
      kind: kind,
      time: time,
      activityId: activityId,
      undone: undone ?? this.undone,
      items: items,
      tasks: tasks,
      detail: detail,
      options: options);

  ChatAction markUndone() => copyWith(undone: true);

  /// Things Ally created from what was said (they get the "Saved N things" card).
  bool get isCreation =>
      const {'TASK_ADDED', 'REMINDER_SET', 'HABIT_ADDED', 'PROJECT_ADDED', 'NOTE_ADDED'}.contains(type);

  /// Server item type for the rename endpoint.
  String? get itemType => switch (type) {
        'TASK_ADDED' || 'REMINDER_SET' => 'task',
        'HABIT_ADDED' => 'habit',
        'PROJECT_ADDED' => 'project',
        'NOTE_ADDED' => 'note',
        _ => null,
      };

  factory ChatAction.fromJson(Json j) => ChatAction(
        type: asString(j['type']),
        id: asStringOrNull(j['id']),
        text: asString(j['title'] ?? j['text'] ?? j['question']),
        remindAt: asDate(j['remindAt'])?.toLocal(),
        windowEnd: asDate(j['windowEnd'])?.toLocal(),
        repeatRule: asStringOrNull(j['repeatRule']),
        kind: asStringOrNull(j['kind'] ?? j['mode'] ?? j['status']),
        time: asStringOrNull(j['time']),
        activityId: asStringOrNull(j['activityId']),
        undone: asBool(j['undone']),
        items: ((j['items'] ?? j['days']) as List? ?? const []).map((e) => e.toString()).toList(),
        tasks: (j['tasks'] as num?)?.toInt() ?? 0,
        detail: asStringOrNull(j['deadline'] ?? j['timeBlock'] ?? j['until'] ?? j['what']),
        options: ((j['options'] as List?) ?? const [])
            .whereType<Json>()
            .map((o) => AskOption(asString(o['id']), asString(o['title']), (o['minutes'] as num?)?.toInt() ?? 0, asBool(o['smaller'])))
            .toList(),
      );

  Json toJson() => {
        'type': type,
        if (id != null) 'id': id,
        'text': text,
        if (remindAt != null) 'remindAt': remindAt!.toUtc().toIso8601String(),
        if (windowEnd != null) 'windowEnd': windowEnd!.toUtc().toIso8601String(),
        if (repeatRule != null) 'repeatRule': repeatRule,
        if (kind != null) 'kind': kind,
        if (time != null) 'time': time,
        if (activityId != null) 'activityId': activityId,
        if (undone) 'undone': true,
        if (items.isNotEmpty) 'items': items,
        if (tasks > 0) 'tasks': tasks,
        if (detail != null) 'deadline': detail,
        if (options.isNotEmpty)
          'options': [for (final o in options) {'id': o.id, 'title': o.title, 'minutes': o.minutes, 'smaller': o.smaller}],
      };
}

class ChatMessage {
  final bool fromUser;
  final String text;
  final List<ChatAction> actions;
  final String? role; // FRIEND | ASSISTANT | MENTOR | COACH | GUIDE (assistant replies)
  final List<String> suggestions; // habits Ally offers, added only on a tap
  final ChatCapacity? capacity;
  const ChatMessage(
      {required this.fromUser,
      required this.text,
      this.actions = const [],
      this.role,
      this.suggestions = const [],
      this.capacity});

  ChatMessage copyWith({List<ChatAction>? actions, List<String>? suggestions, ChatCapacity? capacity}) => ChatMessage(
      fromUser: fromUser,
      text: text,
      actions: actions ?? this.actions,
      role: role,
      suggestions: suggestions ?? this.suggestions,
      capacity: capacity ?? this.capacity);

  Json toJson() => {
        'u': fromUser,
        't': text,
        'a': [for (final a in actions) a.toJson()],
        if (role != null) 'r': role,
        if (suggestions.isNotEmpty) 's': suggestions,
        if (capacity != null) 'c': capacity!.toJson(),
      };

  factory ChatMessage.fromJson(Json j) => ChatMessage(
        fromUser: asBool(j['u']),
        text: asString(j['t']),
        actions: ((j['a'] as List?) ?? const [])
            .whereType<Json>()
            .map(ChatAction.fromJson)
            .toList(),
        role: asStringOrNull(j['r']),
        suggestions: ((j['s'] as List?) ?? const []).map((e) => e.toString()).toList(),
        capacity: j['c'] is Json ? ChatCapacity.fromJson(j['c'] as Json) : null,
      );
}

class ChatReply {
  final String reply;
  final List<ChatAction> actions;
  final String role;
  final List<String> suggestions;
  final ChatCapacity? capacity;
  const ChatReply(this.reply, this.actions, this.role, [this.suggestions = const [], this.capacity]);

  factory ChatReply.fromJson(Json j) => ChatReply(
        asString(j['reply']),
        ((j['actions'] as List?) ?? const []).whereType<Json>().map(ChatAction.fromJson).toList(),
        asString(j['role'], 'ASSISTANT'),
        ((j['suggestions'] as List?) ?? const [])
            .whereType<Json>()
            .map((s) => asString(s['title']))
            .where((t) => t.isNotEmpty)
            .toList(),
        j['capacity'] is Json ? ChatCapacity.fromJson(j['capacity'] as Json) : null,
      );
}

class Reminder {
  final String id;
  final String text;
  final DateTime remindAt;
  final DateTime? windowEnd;
  const Reminder(this.id, this.text, this.remindAt, [this.windowEnd]);

  factory Reminder.fromJson(Json j) => Reminder(asString(j['id']), asString(j['text']),
      asDate(j['remindAt'])?.toLocal() ?? asDate(j['windowEnd'])!.toLocal(), asDate(j['windowEnd'])?.toLocal());
}

/// Something the assistant remembers about the person (from chat).
class MemoryItem {
  final String id;
  final String content;
  final String kind;
  final DateTime createdAt;
  const MemoryItem(this.id, this.content, this.kind, this.createdAt);

  factory MemoryItem.fromJson(Json j) => MemoryItem(
        asString(j['id']),
        asString(j['content']),
        asString(j['kind'], 'FACT'),
        asDate(j['createdAt'])?.toLocal() ?? DateTime.now(),
      );
}
