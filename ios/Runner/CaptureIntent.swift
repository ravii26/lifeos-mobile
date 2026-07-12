import AppIntents
import UIKit

/// Siri / Shortcuts entry point for voice capture ("Hey Siri, add to
/// LifeOS…" or the Shortcuts app). Defined directly in the Runner target
/// (no separate extension needed for a basic App Shortcut) — Xcode still
/// has to add this file to the target's membership, see
/// SHARE_VOICE_IOS_SETUP.md.
///
/// `openAppWhenRun` brings LifeOS to the foreground and runs `perform()`
/// in-process, so opening `lifeos://capture?voice=1` here is picked up by
/// the same `app_links`/`DeepLinkService` path the widget mic button and
/// Android's assistant shortcut use — no new native bridging required.
@available(iOS 16.0, *)
struct CaptureIntent: AppIntent {
  static var title: LocalizedStringResource = "Add to LifeOS"
  static var description = IntentDescription(
    "Opens LifeOS straight into voice capture, so you can add something to your dump by speaking.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    if let url = URL(string: "lifeos://capture?voice=1") {
      UIApplication.shared.open(url)
    }
    return .result()
  }
}

@available(iOS 16.0, *)
struct LifeOSShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: CaptureIntent(),
      phrases: [
        "Add to \(.applicationName)",
        "Add to my \(.applicationName) dump",
        "Quick capture in \(.applicationName)",
      ],
      shortTitle: "Add to LifeOS",
      systemImageName: "mic.fill"
    )
  }
}
