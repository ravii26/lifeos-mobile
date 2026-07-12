// If you get a "no such module 'receive_sharing_intent'" build error, go to
// Build Phases of the Runner target and move "Embed Foundation Extension"
// above "Thin Binary" — see SHARE_VOICE_IOS_SETUP.md.
import receive_sharing_intent

/// Handles "Share" from any app (Safari, Photos, WhatsApp, ...) into LifeOS.
///
/// `shouldAutoRedirect() == true` (the default, made explicit here) means no
/// compose UI is shown: the shared content is written to the shared App
/// Group storage and the extension redirects straight into the host app,
/// which `ShareIntentService` (Dart side) then picks up via
/// `ReceiveSharingIntent.instance.getInitialMedia()`/`getMediaStream()` and
/// turns into a `PendingCaptureIntent` — same destination as the widget mic
/// button and the assistant shortcut (`lifeos://capture`), just pre-filled
/// with the shared text/link/image instead of starting voice dictation.
class ShareViewController: RSIShareViewController {
  override func shouldAutoRedirect() -> Bool { true }
}
