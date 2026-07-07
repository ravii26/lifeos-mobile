import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../di/service_locator.dart';
import '../../data/models/decision.dart';
import '../../data/models/habit.dart';
import '../../data/repositories/life_repository.dart';
import 'active_focus_store.dart';
import 'widget_snapshot.dart';

const _snapshotKey = 'lifeos_widget_snapshot';

/// Shared App Group id (iOS) between Runner and the widget extension. Must
/// match the group id enabled on both targets in Xcode — see
/// WIDGET_IOS_SETUP.md.
const kWidgetAppGroupId = 'group.com.example.lifeosMobile.widget';

/// Android Glance widget receiver's fully-qualified class name (must match
/// the manifest `<receiver android:name>` entry) and iOS WidgetKit kind
/// string (must match the `kind:` in the Swift widget's configuration).
const _androidWidgetQualifiedName =
    'com.example.lifeos_mobile.widget.LifeOSWidgetReceiver';
const _iosWidgetName = 'LifeOSWidget';
const _periodicTaskName = 'lifeos_widget_refresh';

/// Keeps the home-screen widget's data fresh. Instances live in two places:
/// the main app isolate (pushes data as the UI loads/changes) and the
/// headless background isolates spawned by home_widget/workmanager (which
/// construct their own instance after `setupLocator()`).
class WidgetSyncService {
  static WidgetSyncService? instance;

  final LifeRepository _repo;
  WidgetSyncService(this._repo) {
    instance = this;
  }

  Future<void> init() async {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    // Periodic background refresh is Android-only for v1 — iOS's background
    // execution budget makes a plain WorkManager-style periodic task
    // unreliable there, and would need its own BGTaskScheduler setup.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().initialize(widgetRefreshCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _periodicTaskName,
        _periodicTaskName,
        frequency: const Duration(hours: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
  }

  /// Cheap, no-network update after LifeCubit loads/changes habits.
  Future<void> pushHabits(List<Habit> habits) async {
    final current = await _readCurrent() ?? WidgetSnapshot.empty();
    await _save(current.copyWith(
      updatedAt: DateTime.now(),
      habits: _topHabits(habits),
    ));
  }

  /// Cheap, no-network update after DecisionsCubit refreshes "what now".
  Future<void> pushNextAction(PrimaryAction? action) async {
    final current = await _readCurrent() ?? WidgetSnapshot.empty();
    await _save(current.copyWith(
      updatedAt: DateTime.now(),
      nextActionType: action?.type,
      nextActionRefId: action?.refId,
      nextActionTitle: action?.title,
    ));
  }

  /// Called from AppearanceCubit whenever the palette/accent changes, so the
  /// widget re-skins itself like the rest of the app instead of showing a
  /// hardcoded guess at the theme.
  Future<void> pushTheme({
    required int bgColor,
    required int textColor,
    required int mutedTextColor,
    required int accentColor,
    required int accentInkColor,
  }) async {
    final current = await _readCurrent() ?? WidgetSnapshot.empty();
    await _save(current.copyWith(
      updatedAt: DateTime.now(),
      bgColor: bgColor,
      textColor: textColor,
      mutedTextColor: mutedTextColor,
      accentColor: accentColor,
      accentInkColor: accentInkColor,
    ));
  }

  /// Called from LifeRepository.startFocus/stopFocus.
  Future<void> pushFocusState({required bool active, String? label}) async {
    final current = await _readCurrent() ?? WidgetSnapshot.empty();
    await _save(current.copyWith(
      updatedAt: DateTime.now(),
      focusActive: active,
      focusLabel: active ? label : null,
      focusStartedAt: active ? DateTime.now() : null,
    ));
  }

  /// Full refetch — used by the hourly background refresh and right after a
  /// widget-triggered habit toggle (habit stats/streaks may have changed).
  Future<void> refreshFromNetwork() async {
    final habits = await _repo.habits();
    DecisionResult? decision;
    try {
      decision = await _repo.decisionsNow();
    } catch (_) {
      // best-effort; keep whatever next-action was already cached
    }
    final focus = await ActiveFocusStore().read();
    final current = await _readCurrent() ?? WidgetSnapshot.empty();
    await _save(current.copyWith(
      updatedAt: DateTime.now(),
      focusActive: focus != null,
      focusLabel: focus?.label,
      focusStartedAt: focus?.startedAt,
      nextActionType: decision?.primaryAction?.type,
      nextActionRefId: decision?.primaryAction?.refId,
      nextActionTitle: decision?.primaryAction?.title,
      habits: _topHabits(habits),
    ));
  }

  /// Wipes cached data on sign-out so a different user signing in on the
  /// same device never sees the previous user's habits/tasks on the widget.
  Future<void> clear() => _save(WidgetSnapshot.empty());

  /// Invoked from the widget's habit-checkbox tap (Android background
  /// isolate). Only supports BOOLEAN habits for v1 — count/timer habits
  /// still require opening the app.
  Future<void> toggleHabit(String habitId) async {
    final current = await _readCurrent();
    final cached = current?.habits.where((h) => h.id == habitId).firstOrNull;
    final wasDone = cached?.done ?? false;
    await _repo.logHabit(habitId, completed: !wasDone);
    await refreshFromNetwork();
  }

  Future<WidgetSnapshot?> _readCurrent() async {
    final raw = await HomeWidget.getWidgetData<String>(_snapshotKey);
    return WidgetSnapshot.decode(raw);
  }

  Future<void> _save(WidgetSnapshot snapshot) async {
    await HomeWidget.saveWidgetData(_snapshotKey, snapshot.encode());
    await HomeWidget.updateWidget(
      qualifiedAndroidName: _androidWidgetQualifiedName,
      iOSName: _iosWidgetName,
    );
  }

  List<WidgetHabit> _topHabits(List<Habit> habits) {
    final active = habits.where((h) => h.isActive && h.kind == 'boolean').toList()
      ..sort((a, b) => (a.todayDone ? 1 : 0) - (b.todayDone ? 1 : 0));
    return active
        .take(4)
        .map((h) => WidgetHabit(id: h.id, title: h.title, done: h.todayDone))
        .toList();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Entry point for widget-tap actions (e.g. the habit checkbox). Runs in a
/// headless Flutter engine spawned by the `home_widget` Android plugin — it
/// has no access to the main isolate's `getIt`, so it wires up its own copy.
@pragma('vm:entry-point')
void widgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != 'toggle-habit') return;
  final id = uri.queryParameters['id'];
  if (id == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  try {
    await getIt<WidgetSyncService>().toggleHabit(id);
  } catch (_) {
    // best-effort; the widget will show stale state until the next refresh
  }
}

/// Entry point for the hourly WorkManager refresh (Android only).
@pragma('vm:entry-point')
void widgetRefreshCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await setupLocator();
    try {
      await getIt<WidgetSyncService>().refreshFromNetwork();
    } catch (_) {
      // network unavailable or token expired — widget stays on last-known data
    }
    return true;
  });
}
