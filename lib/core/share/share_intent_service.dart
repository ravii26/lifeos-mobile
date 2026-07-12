import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../intents/capture_intent_bus.dart';

/// Bridges the OS share sheet ("Share" from any app) into a
/// `PendingCaptureIntent` on `CaptureIntentBus`. Mirrors `DeepLinkService`'s
/// init pattern: check for a cold-start share first, then listen for
/// shares delivered while the app is already running.
///
/// Only the first shared item is used — multi-item batch sharing isn't
/// supported by Capture today, and reviewing one item at a time in the
/// Capture sheet before it's sent matches the rest of the capture flow.
class ShareIntentService {
  final CaptureIntentBus _bus;
  ShareIntentService(this._bus);

  Future<void> init() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      _handle(initial);
      ReceiveSharingIntent.instance.reset();
    }
    ReceiveSharingIntent.instance.getMediaStream().listen(_handle);
  }

  void _handle(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final f = files.first;
    switch (f.type) {
      case SharedMediaType.text:
      case SharedMediaType.url:
        _bus.push(PendingCaptureIntent(text: f.path));
        break;
      case SharedMediaType.image:
        _bus.push(PendingCaptureIntent(
          imagePath: f.path,
          imageMime: f.mimeType ?? 'image/jpeg',
        ));
        break;
      default:
        // video/file: not a supported capture media type yet.
        break;
    }
  }
}
