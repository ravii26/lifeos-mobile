import WidgetKit
import SwiftUI

/// Must match the App Group enabled on both the Runner and this extension's
/// target in Xcode, and `kWidgetAppGroupId` in widget_sync_service.dart.
private let appGroupId = "group.com.example.lifeosMobile.widget"
/// Key the Flutter app saves the snapshot JSON under (see `WidgetSyncService`).
private let snapshotKey = "lifeos_widget_snapshot"

/// Converts a packed ARGB32 int (same format as Flutter's `Color.toARGB32()`
/// and the ints AppColors sends) into a SwiftUI Color.
private func colorFromARGB(_ argb: Int?, default defaultArgb: Int) -> Color {
  let v = UInt32(bitPattern: Int32(truncatingIfNeeded: argb ?? defaultArgb))
  let r = Double((v >> 16) & 0xFF) / 255
  let g = Double((v >> 8) & 0xFF) / 255
  let b = Double(v & 0xFF) / 255
  return Color(red: r, green: g, blue: b)
}

// MARK: - Model (mirrors WidgetSnapshot in lib/core/widget/widget_snapshot.dart)

struct WidgetHabit: Decodable {
  let id: String
  let title: String
  let done: Bool
}

struct WidgetSnapshotData: Decodable {
  let focusActive: Bool?
  let focusLabel: String?
  let nextActionTitle: String?
  let habits: [WidgetHabit]?
  let bgColor: Int?
  let textColor: Int?
  let mutedTextColor: Int?
  let accentColor: Int?

  /// Reads the app's live theme (AppColors) out of the snapshot instead of a
  /// hardcoded guess, so the widget re-skins itself with whatever
  /// accent/mode the user picked in Settings. Defaults match AppColors' dark
  /// palette + default chartreuse accent for the pre-first-sync cold start.
  var bg: Color { colorFromARGB(bgColor, default: 0xFF0A0B0D) }
  var fg: Color { colorFromARGB(textColor, default: 0xFFECEEF0) }
  var fgMuted: Color { colorFromARGB(mutedTextColor, default: 0xFFA6ABB3) }
  var accent: Color { colorFromARGB(accentColor, default: 0xFFC5F23F) }

  static func load() -> WidgetSnapshotData? {
    guard let raw = UserDefaults(suiteName: appGroupId)?.string(forKey: snapshotKey),
      let data = raw.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshotData.self, from: data)
  }
}

/// Default theme used when no snapshot has synced yet (matches AppColors' dark palette).
private let defaultBg = colorFromARGB(nil, default: 0xFF0A0B0D)
private let defaultFg = colorFromARGB(nil, default: 0xFFECEEF0)
private let defaultFgMuted = colorFromARGB(nil, default: 0xFFA6ABB3)
private let defaultAccent = colorFromARGB(nil, default: 0xFFC5F23F)

// MARK: - Timeline

struct LifeOSEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshotData?
}

struct LifeOSProvider: TimelineProvider {
  func placeholder(in context: Context) -> LifeOSEntry {
    LifeOSEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (LifeOSEntry) -> Void) {
    completion(LifeOSEntry(date: Date(), snapshot: WidgetSnapshotData.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<LifeOSEntry>) -> Void) {
    let entry = LifeOSEntry(date: Date(), snapshot: WidgetSnapshotData.load())
    // The Flutter app calls WidgetCenter.reloadTimelines whenever it pushes
    // new data (via HomeWidget.updateWidget); this hourly fallback just
    // covers the case where the app hasn't been opened in a while.
    let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }
}

// MARK: - Views

struct LifeOSWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: LifeOSEntry

  private var focusActive: Bool { entry.snapshot?.focusActive ?? false }

  private var headerText: String {
    if focusActive {
      let label = entry.snapshot?.focusLabel ?? ""
      return label.isEmpty ? "Focus session active" : "Focusing: \(label)"
    }
    let next = entry.snapshot?.nextActionTitle ?? ""
    return next.isEmpty ? "Nothing queued" : "Next: \(next)"
  }

  private var headerUrl: URL {
    URL(string: focusActive ? "lifeos://focus" : "lifeos://now")!
  }

  private var bg: Color { entry.snapshot?.bg ?? defaultBg }
  private var fg: Color { entry.snapshot?.fg ?? defaultFg }
  private var accent: Color { entry.snapshot?.accent ?? defaultAccent }

  // .systemSmall has no habit list to fill the cell, so the header is
  // vertically centered rather than pinned to the top — leaving it there
  // stranded a lot of dead background beneath a short line of text.
  private var hasHabitList: Bool {
    family == .systemMedium && !(entry.snapshot?.habits?.isEmpty ?? true)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !hasHabitList {
        Spacer(minLength: 0)
      }
      HStack(alignment: .top, spacing: 8) {
        Text(headerText)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(focusActive ? accent : fg)
          .lineLimit(2)
        Spacer(minLength: 0)
        MicButton(accent: accent)
      }

      if hasHabitList, let habits = entry.snapshot?.habits {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(habits.prefix(4), id: \.id) { habit in
            HabitRow(habit: habit, snapshot: entry.snapshot)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(bg)
    .widgetURL(headerUrl)
  }
}

/// Mic button — opens the app straight into the Capture sheet, already
/// listening (`lifeos://capture?voice=1`, routed by `DeepLinkService`
/// through `CaptureIntentBus`). Same destination the shortcuts.xml-style
/// Assistant capability and `CaptureIntent.swift`'s Siri shortcut use on
/// Android/iOS respectively.
///
/// Like the habit-toggle button, a widget can only have more than one
/// distinct tap target from iOS 17 onward — pre-17 this `Link` falls back to
/// the same single whole-widget `widgetURL` everything else uses (a known
/// v1 limitation, see WIDGET_IOS_SETUP.md).
private struct MicButton: View {
  let accent: Color

  var body: some View {
    Link(destination: URL(string: "lifeos://capture?voice=1")!) {
      Image(systemName: "mic.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.black.opacity(0.75))
        .padding(6)
        .background(accent)
        .clipShape(Circle())
    }
  }
}

private struct HabitRow: View {
  let habit: WidgetHabit
  let snapshot: WidgetSnapshotData?

  var body: some View {
    if #available(iOSApplicationExtension 17, *) {
      Button(intent: ToggleHabitIntent(habitId: habit.id)) {
        rowContent
      }
      .buttonStyle(.plain)
    } else {
      // Pre-17: no silent background-action API, so this deep-links into the
      // app instead (DeepLinkService performs the toggle immediately on open).
      Link(destination: URL(string: "lifeos://habit?id=\(habit.id)&action=toggle")!) {
        rowContent
      }
    }
  }

  private var rowContent: some View {
    let accent = snapshot?.accent ?? defaultAccent
    let fg = snapshot?.fg ?? defaultFg
    let fgMuted = snapshot?.fgMuted ?? defaultFgMuted
    return HStack(spacing: 8) {
      Text(habit.done ? "✓" : "○")
        .foregroundColor(habit.done ? accent : fgMuted)
      Text(habit.title)
        .font(.system(size: 13))
        .foregroundColor(habit.done ? fgMuted : fg)
        .lineLimit(1)
    }
  }
}

// MARK: - Widget configuration

struct LifeOSWidget: Widget {
  // Must match the `iOSName` passed to HomeWidget.updateWidget() in Dart.
  let kind: String = "LifeOSWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: LifeOSProvider()) { entry in
      LifeOSWidgetView(entry: entry)
    }
    .configurationDisplayName("LifeOS")
    .description("Today's habits, focus session, and what's next.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
