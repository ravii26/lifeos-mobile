import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/chat.dart';
import 'package:lifeos_mobile/data/models/tonight.dart';
import 'package:lifeos_mobile/features/places/note_cards.dart';
import 'package:lifeos_mobile/features/places/now_extras.dart';

void main() {
  group('NowExtras', () {
    test('is empty when the server sends nothing extra', () {
      final e = NowExtras.fromJson({'kind': 'PICK', 'timer': null, 'meal': null, 'routine': null, 'watchLater': null, 'counts': []});
      expect(e.isEmpty, isTrue);
      expect(NowExtras.fromJson(const {}).isEmpty, isTrue);
    });

    test('reads counts, timer, routine, meal and watch later', () {
      final e = NowExtras.fromJson({
        'counts': [
          {'id': 'h1', 'title': 'Drink 8 glasses of water', 'count': 3, 'target': 8}
        ],
        'timer': {'label': 'dsa', 'minutes': 75, 'forgotten': false},
        'routine': {
          'id': 'n1',
          'title': 'Gym routine',
          'steps': [
            {'text': 'Bench press 3x10', 'done': true},
            {'text': 'Squats 3x8', 'done': false},
          ],
        },
        'meal': {'meal': 'lunch', 'text': 'dal rice', 'tomorrow': false},
        'watchLater': {'id': 's1', 'title': 'Atomic Habits summary', 'url': 'https://example.com', 'line': 'You have time. Watch later: Atomic Habits summary (18 min)?'},
      });
      expect(e.isEmpty, isFalse);
      expect(e.counts.single.line, 'Drink 8 glasses of water: 3 of 8');
      expect(e.timer!.length, '1 h 15 min');
      expect(e.routine!.remaining, 1);
      expect(e.meal!.label, 'Next meal: lunch');
      expect(e.later!.line, contains('Atomic Habits summary'));
    });

    test('a count with no target and a meal for tomorrow read plainly', () {
      expect(NowCount.fromJson({'id': 'a', 'title': 'Chai', 'count': 2}).line, 'Chai: 2');
      expect(const NowMeal('breakfast', 'oats', true).label, "Tomorrow's breakfast");
      expect(const NowTimer('reading', 12, false).length, '12 min');
    });

    test('a routine with no steps is not shown', () {
      expect(NowRoutine.fromJson({'id': 'n', 'title': 'Gym', 'steps': []}), isNull);
      expect(NowRoutine.fromJson(null), isNull);
    });
  });

  group('notes', () {
    test('lists, routines, people and the diet get their own cards', () {
      expect(isSpecialNote({'template': 'LIST', 'collection': 'Shopping'}), isTrue);
      expect(isSpecialNote({'template': 'ROUTINE', 'collection': 'Gym'}), isTrue);
      expect(isSpecialNote({'template': 'INFO', 'collection': 'People'}), isTrue);
      expect(isSpecialNote({'template': 'ROUTINE', 'collection': 'Diet'}), isTrue);
      expect(isSpecialNote({'template': 'INFO', 'collection': 'Saves'}), isFalse);
      expect(isSpecialNote({'template': 'PLAYBOOK', 'collection': 'Situations'}), isFalse);
    });

    test('a 10-digit number is taken as Indian, like the server does', () {
      expect(dialNumber('9876543210'), '+919876543210');
      expect(dialNumber('+91 98111-22333'), '+919811122333');
      expect(dialNumber('+44 7700 900123'), '+447700900123');
    });
  });

  group('save and chat parsing', () {
    test('a save carries what Ally suggests', () {
      final p = SaveProposal.fromJson({
        'id': 's1',
        'url': 'https://example.com',
        'proposal': {
          'contentTitle': '5 films to watch',
          'kind': 'OTHER',
          'action': 'x',
          'minimum': 'y',
          'when': 'THIS_WEEK',
          'reason': 'r',
          'suggestedChoice': 'LIST',
          'suggestionReason': 'A pick to keep on your movies list.',
          'listName': 'Movies',
          'lengthMinutes': 12,
        },
        'summary': {'state': 'NONE', 'lines': []},
      });
      expect(p.suggestedChoice, 'LIST');
      expect(p.listName, 'Movies');
      expect(p.lengthMinutes, 12);
      expect(p.suggestionReason, contains('movies'));
    });

    test('an older save has no suggestion', () {
      final p = SaveProposal.fromJson({
        'id': 's2',
        'proposal': {'contentTitle': 'Old', 'kind': 'LEARN', 'action': 'a', 'minimum': 'm', 'when': 'THIS_WEEK', 'reason': ''},
        'summary': {'state': 'NONE', 'lines': []},
      });
      expect(p.suggestedChoice, isNull);
      expect(p.lengthMinutes, isNull);
    });

    test('a contact action keeps its link', () {
      final a = ChatAction.fromJson({'type': 'CONTACT', 'name': 'Priya', 'mode': 'CALL', 'url': 'tel:+919876543210', 'title': 'Call Priya'});
      expect(a.url, 'tel:+919876543210');
      expect(a.kind, 'CALL');
      expect(a.toJson()['url'], 'tel:+919876543210');
    });
  });
}
