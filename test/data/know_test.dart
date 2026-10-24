import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/know.dart';

void main() {
  test('a question with chips and a typed answer is read correctly', () {
    final d = KnowCardData.fromJson({
      'question': {
        'id': 'wake',
        'text': 'What time do you usually wake up?',
        'why': 'So I never message you while you sleep.',
        'options': ['Before 5', '5 to 6', '6 to 7'],
        'allowText': true,
        'hint': 'Or type a time, like 6:30',
      },
      'answered': 2,
      'total': 10,
    });
    expect(d.question?.id, 'wake');
    expect(d.question?.options, ['Before 5', '5 to 6', '6 to 7']);
    expect(d.question?.allowText, true);
    expect(d.question?.hint, 'Or type a time, like 6:30');
    expect(d.answered, 2);
    expect(d.total, 10);
  });

  test('nothing to ask is a card with no question', () {
    final d = KnowCardData.fromJson({'question': null, 'answered': 10, 'total': 10});
    expect(d.question, isNull);
  });

  test('a reply that could not be read asks to try again', () {
    final r = KnowReply.fromJson({'message': "I couldn't read that as a time.", 'retry': true});
    expect(r.retry, true);
    expect(KnowReply.fromJson({'message': 'Got it.', 'retry': false}).retry, false);
  });
}
