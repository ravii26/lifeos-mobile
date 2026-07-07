# iOS home-screen widget — manual setup (Xcode/macOS required)

Everything that can be done from a text editor is already in place:
`ios/LifeOSWidget/*.swift`, its `Info.plist` and `.entitlements`,
`ios/Runner/Runner.entitlements`, the `lifeos://` URL scheme in
`ios/Runner/Info.plist`, and the `HomeWidgetBackgroundWorker` wiring in
`ios/Runner/AppDelegate.swift`.

What's left requires Xcode's UI — a new target can't be added by hand-editing
`project.pbxproj` without risking Flutter's own regeneration of that file.
Do this once, on a Mac:

## 1. Raise the deployment target

WidgetKit needs iOS 14+ (the `ToggleHabitIntent` interactive action needs 17+,
but the widget still renders read-only on 14-16). Runner is currently on iOS 13.
In Xcode: select the Runner project → each target → **General** →
**Minimum Deployments** → set to at least **14.0** (recommend 16 or 17 so the
interactive habit-toggle button works out of the box for most users).

## 2. Add the widget extension target

File → New → Target → **Widget Extension**. Name it `LifeOSWidget`
(must match exactly — it's referenced by the `iOSName` the Dart side passes
to `HomeWidget.updateWidget()`). Uncheck "Include Configuration Intent".
Xcode creates a starter `LifeOSWidget/` group with its own Swift file and
Info.plist — **delete those generated files** and instead add the real ones:

- Drag in `ios/LifeOSWidget/LifeOSWidgetBundle.swift`
- Drag in `ios/LifeOSWidget/LifeOSWidget.swift`
- Drag in `ios/LifeOSWidget/ToggleHabitIntent.swift` — **check target
  membership for BOTH `Runner` and `LifeOSWidget`** (App Intents that use
  `ForegroundContinuableIntent` need to compile into the containing app
  target too, not just the extension — same pattern `home_widget`'s own
  example uses).
- Replace the generated `Info.plist` for the new target with
  `ios/LifeOSWidget/Info.plist`
- Set the new target's entitlements file to `ios/LifeOSWidget/LifeOSWidget.entitlements`
  (target → Signing & Capabilities → if no App Groups capability is listed
  yet, add one with the **+ Capability** button first — see step 3)

## 3. Enable App Groups on both targets

Both `Runner` and `LifeOSWidget` targets → **Signing & Capabilities** →
**+ Capability** → **App Groups** → add
`group.com.example.lifeosMobile.widget` (the entitlements files already list
this ID — Xcode should detect and offer to reuse it once you add the
capability and point it at the existing `.entitlements` file, or check the
box next to the group after adding one).

This must be an App Group your Apple Developer account/team actually owns —
if `com.example.lifeosMobile` isn't your real bundle ID prefix, change the
group id consistently in all three places it's hardcoded:
`ios/Runner/Runner.entitlements`, `ios/LifeOSWidget/LifeOSWidget.entitlements`,
and `kWidgetAppGroupId` in `lib/core/widget/widget_sync_service.dart`
(and the matching string literal in `LifeOSWidget.swift`/`ToggleHabitIntent.swift`).

## 4. Build

`flutter pub get` first (pulls in `home_widget`'s iOS Swift Package), then
build/run from Xcode (not `flutter run`, the first time — Xcode needs to
resolve the new target and Swift Package dependency graph). Add the widget
from the iOS widget gallery (long-press home screen → + → search "LifeOS")
to verify it renders and that tapping a habit checkbox — on iOS 17+ — doesn't
open the app.

## Known v1 limitations (by design, not bugs)

- **iOS 14-16**: habit-checkbox tap opens the app and the app performs the
  toggle immediately (`DeepLinkService._toggleHabit`), it doesn't happen
  silently in the background — the `ForegroundContinuableIntent` background
  path needs iOS 17+.
- **No periodic background refresh** on iOS (unlike Android's hourly
  WorkManager task) — the widget refreshes when the app runs, plus
  WidgetKit's own opportunistic timeline reloads. This is a deliberate scope
  cut, not a missing feature — see the plan for why.
