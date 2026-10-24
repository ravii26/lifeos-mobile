import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/features/chat/talk_controller.dart';

void main() {
  test('listens, asks, speaks, then listens again; stops when told to', () async {
    final heard = ['what is my day', 'thanks'];
    final log = <String>[];
    late TalkController talk;
    talk = TalkController(
      listenOnce: (onPartial) async {
        log.add('listen');
        if (heard.isEmpty) {
          await talk.stop();
          return null;
        }
        final said = heard.removeAt(0);
        onPartial(said);
        return said;
      },
      cancelListening: () async => log.add('cancel'),
      ask: (said) async {
        log.add('ask:$said');
        return 'Reply to $said.';
      },
      speak: (t) async => log.add('speak:$t'),
      stopSpeaking: () async => log.add('stopSpeaking'),
    );
    await talk.start();
    expect(log.take(7).toList(), [
      'listen',
      'ask:what is my day',
      'speak:Reply to what is my day.',
      'listen',
      'ask:thanks',
      'speak:Reply to thanks.',
      'listen',
    ]);
    expect(talk.state, TalkState.off);
    expect(talk.active, false);
  });

  test('hearing nothing three times in a row ends it, with a plain note', () async {
    var listens = 0;
    final talk = TalkController(
      listenOnce: (_) async {
        listens++;
        return '';
      },
      cancelListening: () async {},
      ask: (_) async => 'never',
      speak: (_) async {},
      stopSpeaking: () async {},
    );
    await talk.start();
    expect(listens, 3);
    expect(talk.note, contains("didn't hear anything"));
    expect(talk.state, TalkState.off);
  });

  test('a miss is shown, and clears when the next round is heard', () async {
    var round = 0;
    final seenMissed = <bool>[];
    late TalkController talk;
    talk = TalkController(
      listenOnce: (_) async {
        seenMissed.add(talk.missed);
        return round++ == 0 ? '' : (round == 2 ? 'hello' : null);
      },
      cancelListening: () async {},
      ask: (_) async => 'Hi.',
      speak: (_) async {},
      stopSpeaking: () async {},
    );
    await talk.start();
    // Round 1: nothing yet. Round 2: the miss is showing. Round 3: heard, so it was cleared.
    expect(seenMissed.take(3).toList(), [false, true, false]);
  });

  test('no answer from the server ends it with a note instead of looping', () async {
    final talk = TalkController(
      listenOnce: (_) async => 'hello',
      cancelListening: () async {},
      ask: (_) async => null,
      speak: (_) async {},
      stopSpeaking: () async {},
    );
    await talk.start();
    expect(talk.note, contains("couldn't get an answer"));
  });

  test('a stop during speaking does not start another round', () async {
    var listens = 0;
    late TalkController talk;
    talk = TalkController(
      listenOnce: (_) async {
        listens++;
        return 'hello';
      },
      cancelListening: () async {},
      ask: (_) async => 'Hi.',
      speak: (_) async => talk.stop(),
      stopSpeaking: () async {},
    );
    await talk.start();
    expect(listens, 1);
    expect(talk.state, TalkState.off);
  });

  test('state changes are reported in order', () async {
    final seen = <TalkState>[];
    var rounds = 0;
    late TalkController talk;
    talk = TalkController(
      listenOnce: (_) async => rounds++ == 0 ? 'hi' : null,
      cancelListening: () async {},
      ask: (_) async => 'Hello.',
      speak: (_) async => talk.stop(),
      stopSpeaking: () async {},
    )..addListener(() => seen.add(talk.state));
    await talk.start();
    expect(seen.where((s) => s != TalkState.off).toSet(), {TalkState.listening, TalkState.thinking, TalkState.speaking});
    expect(seen.last, TalkState.off);
  });
}
