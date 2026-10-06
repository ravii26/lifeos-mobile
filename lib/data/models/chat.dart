import 'json.dart';

/// Something the assistant actually did during a chat turn.
class ChatAction {
  final String type; // TASK_ADDED | TASK_COMPLETED | HABIT_LOGGED | REMINDER_SET | NUDGE_SET | REMEMBERED | FORGOT | OPEN_SAVE
  final String? id;
  final String text; // title / reminder text / shared text
  final DateTime? remindAt;
  final String? kind; // NUDGE_SET: NIGHTLY | MORNING
  final String? time; // NUDGE_SET: HH:mm, or null when turned off
  final String? activityId; // for Undo
  final bool undone;

  const ChatAction(
      {required this.type,
      this.id,
      required this.text,
      this.remindAt,
      this.kind,
      this.time,
      this.activityId,
      this.undone = false});

  ChatAction markUndone() => ChatAction(
      type: type, id: id, text: text, remindAt: remindAt, kind: kind, time: time, activityId: activityId, undone: true);

  factory ChatAction.fromJson(Json j) => ChatAction(
        type: asString(j['type']),
        id: asStringOrNull(j['id']),
        text: asString(j['title'] ?? j['text']),
        remindAt: asDate(j['remindAt'])?.toLocal(),
        kind: asStringOrNull(j['kind']),
        time: asStringOrNull(j['time']),
        activityId: asStringOrNull(j['activityId']),
        undone: asBool(j['undone']),
      );

  Json toJson() => {
        'type': type,
        if (id != null) 'id': id,
        'text': text,
        if (remindAt != null) 'remindAt': remindAt!.toUtc().toIso8601String(),
        if (kind != null) 'kind': kind,
        if (time != null) 'time': time,
        if (activityId != null) 'activityId': activityId,
        if (undone) 'undone': true,
      };
}

class ChatMessage {
  final bool fromUser;
  final String text;
  final List<ChatAction> actions;
  final String? role; // FRIEND | ASSISTANT | MENTOR | COACH | GUIDE (assistant replies)
  const ChatMessage(
      {required this.fromUser, required this.text, this.actions = const [], this.role});

  Json toJson() => {
        'u': fromUser,
        't': text,
        'a': [for (final a in actions) a.toJson()],
        if (role != null) 'r': role,
      };

  factory ChatMessage.fromJson(Json j) => ChatMessage(
        fromUser: asBool(j['u']),
        text: asString(j['t']),
        actions: ((j['a'] as List?) ?? const [])
            .whereType<Json>()
            .map(ChatAction.fromJson)
            .toList(),
        role: asStringOrNull(j['r']),
      );
}

class ChatReply {
  final String reply;
  final List<ChatAction> actions;
  final String role;
  const ChatReply(this.reply, this.actions, this.role);

  factory ChatReply.fromJson(Json j) => ChatReply(
        asString(j['reply']),
        ((j['actions'] as List?) ?? const []).whereType<Json>().map(ChatAction.fromJson).toList(),
        asString(j['role'], 'ASSISTANT'),
      );
}

class Reminder {
  final String id;
  final String text;
  final DateTime remindAt;
  const Reminder(this.id, this.text, this.remindAt);

  factory Reminder.fromJson(Json j) =>
      Reminder(asString(j['id']), asString(j['text']), asDate(j['remindAt'])!.toLocal());
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
