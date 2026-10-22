import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/chat.dart';

void main() {
  test('a LIST action keeps its rows, detail lines and kinds, and survives being saved', () {
    final a = ChatAction.fromJson({
      'type': 'LIST',
      'kind': 'REMOVED',
      'title': 'Removed or paused',
      'total': 2,
      'options': [
        {'id': 'e1', 'title': 'Gym session', 'detail': 'habit · removed today', 'kind': 'HABIT'},
        {'id': 'e2', 'title': 'Renew passport', 'detail': 'to-do · removed yesterday', 'kind': 'TASK'},
      ],
    });
    expect(a.type, 'LIST');
    expect(a.kind, 'REMOVED');
    expect(a.text, 'Removed or paused');
    expect(a.options.length, 2);
    expect(a.options.first.detail, 'habit · removed today');
    expect(a.options.first.kind, 'HABIT');

    // The chat is stored on the phone as JSON and read back on the next start.
    final again = ChatAction.fromJson(a.toJson());
    expect(again.options.length, 2);
    expect(again.options.last.title, 'Renew passport');
    expect(again.options.last.detail, 'to-do · removed yesterday');
    expect(again.options.last.kind, 'TASK');
  });

  test('an ASK option marked as a command is sent as written, an old-style one is not', () {
    final ask = ChatAction.fromJson({
      'type': 'ASK',
      'question': 'Which one?',
      'options': [
        {'id': '1', 'title': 'Remove habit: "Gym session"', 'command': true},
        {'id': '2', 'title': 'Pack gym bag'},
      ],
    });
    expect(ask.options[0].command, true);
    expect(ask.options[1].command, false);
    expect(ChatAction.fromJson(ask.toJson()).options[0].command, true);
    expect(ChatAction.fromJson(ask.toJson()).options[1].command, false);
  });

  test('the receipt for removing or changing something reads naturally', () {
    final r = ChatAction.fromJson({'type': 'ITEM_REMOVED', 'itemType': 'HABIT', 'id': 'h1', 'title': 'Gym session', 'detail': 'removed', 'activityId': 'a1'});
    expect(r.kind, 'HABIT');
    expect(r.text, 'Gym session');
    expect(r.activityId, 'a1');
  });
}
