import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/voice/speech_chunks.dart';
import 'package:lifeos_mobile/core/voice/wav.dart';

void main() {
  group('speechChunks', () {
    test('one sentence per chunk, short ones joined to the next', () {
      expect(speechChunks('Good morning. You have office at ten. Before that, a short walk.'),
          ['Good morning. You have office at ten.', 'Before that, a short walk.']);
    });
    test('drops links, markdown and symbols that are read out badly', () {
      expect(speechChunks('**Done.** See https://example.com/x for more # notes'), ['Done. See for more notes']);
    });
    test('line breaks become sentence breaks', () {
      expect(speechChunks('Today:\nGym at seven\nRead at nine'), ['Today: Gym at seven.', 'Read at nine']);
    });
    test('an overlong sentence is cut at a comma, never mid-word', () {
      final long = 'First, ${'word ' * 30}second, ${'word ' * 30}end';
      final parts = speechChunks(long, maxChars: 100);
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(p.length, lessThanOrEqualTo(101));
        expect(p.endsWith('wor'), false);
      }
    });
    test('nothing to say gives nothing', () {
      expect(speechChunks('   '), isEmpty);
      expect(speechChunks('https://example.com'), isEmpty);
    });
  });

  group('encodeWav', () {
    test('a valid 16-bit mono header and clamped samples', () {
      final wav = encodeWav(Float32List.fromList([0, 0.5, -0.5, 2, -2]), 22050);
      final b = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(b.getUint32(24, Endian.little), 22050);
      expect(b.getUint16(34, Endian.little), 16);
      expect(b.getUint32(40, Endian.little), 10);
      expect(wav.length, 44 + 10);
      expect(b.getInt16(44, Endian.little), 0);
      expect(b.getInt16(46, Endian.little), 16384);
      expect(b.getInt16(50, Endian.little), 32767); // 2.0 clamped
      expect(b.getInt16(52, Endian.little), -32767); // -2.0 clamped
    });
  });
}
