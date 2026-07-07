import AppIntents
import Foundation
import home_widget

/// Habit-checkbox tap (iOS 17+): runs the same headless Dart callback
/// Android's widget uses (`widgetBackgroundCallback` in
/// widget_sync_service.dart) via home_widget's background worker — no app
/// UI opens. Requires `HomeWidgetBackgroundWorker.setPluginRegistrantCallback`
/// to be wired in Runner/AppDelegate.swift (already done).
@available(iOS 17, *)
struct ToggleHabitIntent: AppIntent {
  static var title: LocalizedStringResource = "Toggle Habit"

  @Parameter(title: "Habit ID")
  var habitId: String

  init() {}

  init(habitId: String) {
    self.habitId = habitId
  }

  func perform() async throws -> some IntentResult {
    let uri = "lifeos-widget://toggle-habit?id=\(habitId)"
    await HomeWidgetBackgroundWorker.run(
      url: URL(string: uri),
      appGroup: "group.com.example.lifeosMobile.widget"
    )
    return .result()
  }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension ToggleHabitIntent: ForegroundContinuableIntent {}
