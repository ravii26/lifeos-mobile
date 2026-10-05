import Flutter
import UIKit
import home_widget
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets the home-screen widget's iOS 17+ habit-checkbox AppIntent
    // (LifeOSWidget/ToggleHabitIntent.swift) run the same headless Dart
    // callback Android's widget uses (see widgetBackgroundCallback in
    // widget_sync_service.dart), instead of only deep-linking into the app.
    if #available(iOS 17, *) {
      HomeWidgetBackgroundWorker.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }
    }
    // Lets the nightly nudge's Done / Minimum / Not tonight buttons run their
    // Dart handler (nightlyNotificationBackground) while the app is closed.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
