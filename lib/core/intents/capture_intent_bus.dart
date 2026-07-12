import 'dart:async';

/// A capture that should be opened in the Capture sheet, originating from
/// somewhere other than the sheet's own UI — the OS share sheet, the
/// home-screen widget's mic button, or an assistant shortcut.
class PendingCaptureIntent {
  final String? text;
  final String? imagePath;
  final String? imageMime;
  final bool startVoice;

  const PendingCaptureIntent({
    this.text,
    this.imagePath,
    this.imageMime,
    this.startVoice = false,
  });
}

/// Bridges intents that can arrive before `HomeShell` (and its `LifeCubit`)
/// exist yet — e.g. a share or a `lifeos://capture` link delivered at cold
/// start — to the moment the Capture sheet can actually be opened.
///
/// `DeepLinkService` and `ShareIntentService` push onto this bus; `HomeShell`
/// is the only listener, since it's the one place `CaptureSheet` can be
/// opened with its required `LifeCubit` in scope (see `DeepLinkService`'s
/// doc comment for why the root navigator can't do this directly).
class CaptureIntentBus {
  final _controller = StreamController<PendingCaptureIntent>.broadcast();

  /// Set when an intent arrives with no listener attached yet; consumed and
  /// cleared by the first `HomeShell` that mounts and checks it.
  PendingCaptureIntent? pending;

  Stream<PendingCaptureIntent> get stream => _controller.stream;

  void push(PendingCaptureIntent intent) {
    pending = intent;
    _controller.add(intent);
  }

  /// Called by `HomeShell` once it has consumed `pending` at mount time.
  void consumePending() => pending = null;
}
