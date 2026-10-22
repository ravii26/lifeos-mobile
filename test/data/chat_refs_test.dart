import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/chat.dart';

void main() {
  test('a reply tells the next message what "it" is, newest last', () {
    final m = ChatMessage(fromUser: false, text: 'Done.', actions: [
      ChatAction.fromJson({'type': 'HABIT_ADDED', 'id': 'h1', 'title': 'Gym', 'activityId': 'a1'}),
      ChatAction.fromJson({'type': 'REMINDER_SET', 'id': 't1', 'text': 'Call mom', 'remindAt': '2026-10-23T12:30:00Z', 'activityId': 'a2'}),
      ChatAction.fromJson({'type': 'NUDGE_SET', 'kind': 'NIGHTLY', 'time': '21:30'}),
    ]);
    expect(m.refs, [
      {'type': 'HABIT', 'id': 'h1', 'title': 'Gym', 'activityId': 'a1'},
      {'type': 'TASK', 'id': 't1', 'title': 'Call mom', 'activityId': 'a2'},
    ]);
    expect(const ChatMessage(fromUser: true, text: 'hi').refs, isEmpty);
  });

  test('undone things are no longer "it"; a goal plan carries what was asked', () {
    final undone = ChatAction.fromJson({'type': 'TASK_ADDED', 'id': 't1', 'title': 'Desk', 'undone': true});
    expect(undone.ref, isNull);
    final plan = ChatAction.fromJson({'type': 'GOAL_PLAN', 'goalText': 'Make me a plan for guitar', 'proposal': <String, dynamic>{}});
    expect(plan.ref, {'type': 'GOAL_PLAN', 'goalText': 'Make me a plan for guitar'});
  });

  test('an update from a follow-up keeps its kind, detail and new time', () {
    final a = ChatAction.fromJson({
      'type': 'ITEM_UPDATED', 'itemType': 'HABIT', 'id': 'h1', 'title': 'Gym', 'detail': 'at 9:00 pm', 'reminderTime': '21:00', 'activityId': 'a9',
    });
    expect(a.kind, 'HABIT');
    expect(a.detail, 'at 9:00 pm');
    expect(a.time, '21:00');
    expect(a.ref, {'type': 'HABIT', 'id': 'h1', 'title': 'Gym', 'activityId': 'a9'});
    // Survives being saved with the chat history.
    expect(ChatAction.fromJson(a.toJson()).goalText, isNull);
  });
}
