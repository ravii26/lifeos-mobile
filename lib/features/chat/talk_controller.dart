import 'package:flutter/foundation.dart';

enum TalkState { off, listening, thinking, speaking }

/// Talk mode: Ally listens, answers aloud, then listens again, until you stop it or it hears
/// nothing twice in a row. The pieces that touch the microphone, the server and the speaker are
/// passed in, so the loop itself can be tested without a phone.
class TalkController extends ChangeNotifier {
  TalkController({
    required this.listenOnce,
    required this.cancelListening,
    required this.ask,
    required this.speak,
    required this.stopSpeaking,
  });

  /// Listens until a pause and returns what was said (null or empty = nothing heard). Partial
  /// text is reported through the callback so it can be shown as it is recognised.
  final Future<String?> Function(void Function(String partial) onPartial) listenOnce;
  final Future<void> Function() cancelListening;

  /// Sends what was said to Ally as a spoken-style message and returns the reply text.
  final Future<String?> Function(String said) ask;
  final Future<void> Function(String text) speak;
  final Future<void> Function() stopSpeaking;

  TalkState state = TalkState.off;
  String heard = ''; // what was recognised most recently
  String? note; // why it stopped, in plain words
  bool missed = false; // the last round heard nothing; the bar asks to say it again

  bool _active = false;
  bool get active => _active;

  // The loop can still be finishing when the screen goes away; it must not notify a dead listener.
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(TalkState s) {
    state = s;
    notifyListeners();
  }

  void _partial(String p) {
    heard = p;
    notifyListeners();
  }

  Future<void> start() async {
    if (_active) return;
    _active = true;
    note = null;
    heard = '';
    missed = false;
    var silent = 0;
    try {
      while (_active) {
        _set(TalkState.listening);
        final said = (await listenOnce(_partial))?.trim() ?? '';
        if (!_active) break;
        if (said.isEmpty) {
          missed = true;
          if (++silent >= 3) {
            note = "I didn't hear anything, so I stopped listening.";
            break;
          }
          continue;
        }
        silent = 0;
        missed = false;
        heard = said;
        _set(TalkState.thinking);
        final reply = await ask(said);
        if (!_active) break;
        if (reply == null || reply.trim().isEmpty) {
          note = "I couldn't get an answer. Check your connection and try again.";
          break;
        }
        _set(TalkState.speaking);
        await speak(reply);
      }
    } catch (e) {
      note = "Talk mode stopped: $e";
    } finally {
      _active = false;
      state = TalkState.off;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _active = false;
    await stopSpeaking();
    await cancelListening();
  }
}
