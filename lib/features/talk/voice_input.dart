import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// The language chosen on the listening bar. English and Hinglish both use the
/// Indian English recogniser (Ally reads Hinglish typed in Latin letters);
/// Hindi uses the Hindi one.
enum VoiceLang {
  english('English', 'en_IN'),
  hinglish('Hinglish', 'en_IN'),
  hindi('हिन्दी', 'hi_IN');

  final String label;
  final String locale;
  const VoiceLang(this.label, this.locale);

  static const _key = 'talk_voice_lang';

  static Future<VoiceLang> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_key);
      return VoiceLang.values.firstWhere((l) => l.name == v, orElse: () => VoiceLang.english);
    } catch (_) {
      return VoiceLang.english;
    }
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, name);
    } catch (_) {}
  }
}

/// Speech on the phone, for Talk: dictation into the box (fixable before
/// sending), and one turn of listening for hands-free talk. Nothing is
/// recorded or uploaded as audio. An interface so screens can be tested.
abstract class VoiceInput {
  /// Starts dictation; [onWords] gets everything heard so far. Completes when
  /// listening has started (false when speech is not available).
  Future<bool> dictate({required String locale, required void Function(String words) onWords, required void Function() onEnd});
  Future<void> stop();
  Future<void> cancel();

  /// One hands-free turn: listens until a pause and returns what was said.
  Future<String?> listenOnce({required String locale, required void Function(String partial) onPartial});
}

class PhoneVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  bool _ready = false;
  void Function(String status)? _onStatus;
  void Function(String message)? _onError;

  Future<bool> _ensure() async {
    if (_ready) return true;
    _ready = await _speech.initialize(onStatus: (s) => _onStatus?.call(s), onError: (e) => _onError?.call(e.errorMsg));
    return _ready;
  }

  @override
  Future<bool> dictate({required String locale, required void Function(String words) onWords, required void Function() onEnd}) async {
    if (!await _ensure()) return false;
    _onStatus = (s) {
      if (s == 'done' || s == 'notListening') onEnd();
    };
    _onError = (_) => onEnd();
    await _speech.listen(
      onResult: (r) => onWords(r.recognizedWords),
      listenOptions: SpeechListenOptions(partialResults: true, localeId: locale, listenFor: const Duration(minutes: 3), pauseFor: const Duration(seconds: 8)),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  // The plugin's own pause timer cut people off before the phone's offline
  // recogniser produced a word, so the end of a turn is measured here: up to
  // 9 s for the first words, then about 2 s of quiet after the last word.
  @override
  Future<String?> listenOnce({required String locale, required void Function(String partial) onPartial}) async {
    if (!await _ensure()) throw 'Voice recognition is not available on this phone.';
    if (_speech.isListening) await _speech.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final done = Completer<String?>();
    var last = '';
    var started = false;
    var began = DateTime.now();
    var lastWords = DateTime.now();
    Timer? watch;
    void finish() {
      watch?.cancel();
      if (!done.isCompleted) done.complete(last);
    }

    watch = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final now = DateTime.now();
      final quiet = last.isNotEmpty && now.difference(lastWords) > const Duration(milliseconds: 2200);
      final nothing = last.isEmpty && started && now.difference(began) > const Duration(seconds: 9);
      if (quiet || nothing) {
        watch?.cancel();
        _speech.stop();
      }
    });
    _onStatus = (s) {
      if (s == 'listening') {
        started = true;
        began = DateTime.now();
      }
      if (!started) return;
      if (s == 'done' || s == 'notListening') Future<void>.delayed(const Duration(milliseconds: 1300), finish);
    };
    _onError = (msg) {
      if (msg == 'error_permission') {
        watch?.cancel();
        if (!done.isCompleted) done.completeError('Ally does not have permission to use the microphone. Turn it on in Android settings.');
      } else {
        Future<void>.delayed(const Duration(milliseconds: 300), finish);
      }
    };
    try {
      await _speech.listen(
        onResult: (r) {
          last = r.recognizedWords;
          lastWords = DateTime.now();
          onPartial(last);
          if (r.finalResult) finish();
        },
        listenOptions: SpeechListenOptions(partialResults: true, listenFor: const Duration(seconds: 60), pauseFor: const Duration(seconds: 15), localeId: locale),
      );
    } catch (e) {
      watch.cancel();
      throw 'The microphone could not start ($e).';
    }
    return done.future;
  }
}
