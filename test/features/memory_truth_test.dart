import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/chat.dart';

void main() {
  Map<String, dynamic> json(Map<String, dynamic> extra) => {
        'id': '1',
        'content': 'Works at Infosys',
        'kind': 'FACT',
        'createdAt': '2026-11-01T00:00:00.000Z',
        'source': 'SAID',
        ...extra,
      };

  test('a memory with no end is current, and older replies still read', () {
    final m = MemoryItem.fromJson(json({}));
    expect(m.isCurrent, isTrue);
    expect(m.quote, isNull);
    expect(m.endedAt, isNull);
  });

  test('keeps your exact words', () {
    expect(MemoryItem.fromJson(json({'quote': 'joined Infosys'})).quote, 'joined Infosys');
  });

  test('an end in the past means no longer true', () {
    expect(MemoryItem.fromJson(json({'endedAt': '2026-01-01T00:00:00.000Z'})).isCurrent, isFalse);
  });

  test('an end still ahead means true until then', () {
    final later = DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String();
    expect(MemoryItem.fromJson(json({'endedAt': later})).isCurrent, isTrue);
  });
}
