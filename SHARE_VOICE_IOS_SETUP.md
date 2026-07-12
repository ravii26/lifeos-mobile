# iOS share sheet + Siri capture — manual setup (Xcode/macOS required)

Same situation as `WIDGET_IOS_SETUP.md`: everything that can be done from a
text editor is already in place —
`ios/LifeOSShareExtension/ShareViewController.swift`, its `Info.plist` and
`.entitlements`, the `AppGroupId` + `ShareMedia-` URL scheme added to
`ios/Runner/Info.plist`, `ios/Runner/CaptureIntent.swift` (Siri shortcut), and
the mic button added to `ios/LifeOSWidget/LifeOSWidget.swift`. Adding new
Xcode targets and wiring build settings can't be done by hand-editing
`project.pbxproj`. Do this once, on a Mac, ideally right after (or alongside)
the `WIDGET_IOS_SETUP.md` steps since both share the App Group.

## 1. Enable Swift Package Manager

`receive_sharing_intent` ships as a Swift Package only (no CocoaPods podspec):

```sh
flutter config --enable-swift-package-manager
flutter pub get
```

Flutter wires the package into the **Runner** target automatically.

## 2. Add the Share Extension target

File → New → Target → **Share Extension**. Name it `LifeOSShareExtension`
(matches the folder already checked in). Xcode creates a starter group with
its own Swift file, storyboard, and `Info.plist` — **delete those generated
files** and instead add the real ones:

- Drag in `ios/LifeOSShareExtension/ShareViewController.swift`
- Replace the generated `Info.plist` with `ios/LifeOSShareExtension/Info.plist`
- Set the target's entitlements file to
  `ios/LifeOSShareExtension/LifeOSShareExtension.entitlements`

## 3. Give the Share Extension target access to the plugin module

The `import receive_sharing_intent` in `ShareViewController.swift` needs the
plugin's Swift Package linked into the extension, not just `Runner`:

- Select the **LifeOSShareExtension** target → **General** tab.
- Under **Frameworks and Libraries** → **+** → choose
  **`FlutterGeneratedPluginSwiftPackage`** (from the `receive_sharing_intent`
  package) and add it.
- Go to **Build Phases** of the **Runner** target and move **"Embed Foundation
  Extension"** above **"Thin Binary"** — required or the extension fails to
  find the module at build time.

## 4. Enable App Groups on the new target

Both `Runner` and `LifeOSShareExtension` targets → **Signing & Capabilities**
→ **+ Capability** → **App Groups** → add
`group.com.example.lifeosMobile.widget` — the same App Group already used by
`LifeOSWidget` (see `WIDGET_IOS_SETUP.md` step 3). Reuse it; there's no need
for a second group.

If `com.example.lifeosMobile` isn't your real bundle ID prefix, you'll have
already renamed this group for the widget — use that same renamed value here
too, in `LifeOSShareExtension/Info.plist`'s `AppGroupId` key and
`LifeOSShareExtension.entitlements`, plus `ios/Runner/Info.plist`'s
`AppGroupId` key.

## 5. Add `CaptureIntent.swift` to the Runner target

Drag `ios/Runner/CaptureIntent.swift` into the **Runner** group in Xcode and
confirm target membership is **Runner** (it's a plain `AppIntent`, not a
separate extension — App Shortcuts defined in the main app target are enough
for a basic Siri phrase). Requires **iOS 16+** as the deployment target.

## 6. Bump the deployment target (if not already done for the widget)

WidgetKit needs 14+, the mic button's distinct tap target and Siri both need
**16 or 17** — `WIDGET_IOS_SETUP.md` already recommends this. If you did that
step already, nothing more to do here.

## 7. Build and test

`flutter pub get`, then build/run from **Xcode** (not `flutter run`, the
first time). Test each entry point:

- **Share sheet**: from Safari, share a URL → LifeOS should appear as a
  target → tapping it opens the app with the Capture sheet pre-filled with
  the link. Repeat from Photos with an image.
- **Widget mic button**: tap the new mic icon on the home-screen widget →
  app opens straight into Capture, already listening (iOS 17+; pre-17 it
  falls back to the whole-widget tap, same as the habit checkbox).
- **Siri**: Settings → Siri & Search → "Add to LifeOS" should be discoverable
  as a shortcut once the app has launched at least once post-build; or say
  "Add to LifeOS" directly.

## Known v1 limitations (by design, not bugs)

- Only the **first** shared item is used if multiple items are shared at
  once — Capture reviews one item at a time, matching every other capture
  entry point.
- Video and arbitrary file shares aren't accepted — the Share Extension's
  `NSExtensionActivationRule` only advertises text/URL/image, same scope as
  the Android `SEND` intent-filters.
- Pre-iOS 17, the widget mic button isn't a distinct tap target (same
  limitation as the habit checkbox — see `WIDGET_IOS_SETUP.md`).
