import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../widget/widget_sync_service.dart';
import '../../data/repositories/life_repository.dart';
import '../../features/focus/focus_screen.dart';

/// Routes `lifeos://` links — currently only fired by the home-screen widget
/// (whole-widget tap → `lifeos://focus`; iOS habit-checkbox tap →
/// `lifeos://habit?id=...&action=toggle`, since iOS has no silent
/// background-action path the way Android's Glance widget does).
///
/// Scope note: this intentionally does not attempt to deep-link into
/// arbitrary in-app screens (tasks/goals/etc.) — those live inside
/// `HomeShell`'s own `LifeCubit`-scoped subtree, and pushing them from the
/// root navigator would leave them without that provider. `focus` is safe to
/// push directly because `FocusScreen` reads `LifeRepository` straight from
/// `getIt`, not through a Cubit.
class DeepLinkService {
  final _appLinks = AppLinks();
  final GlobalKey<NavigatorState> navigatorKey;
  DeepLinkService(this.navigatorKey);

  Future<void> init() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) await _handle(initial);
    _appLinks.uriLinkStream.listen(_handle);
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'lifeos') return;
    switch (uri.host) {
      case 'focus':
        navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => const FocusScreen()));
        break;
      case 'habit':
        if (uri.queryParameters['action'] == 'toggle') {
          final id = uri.queryParameters['id'];
          if (id != null) await _toggleHabit(id);
        }
        break;
      default:
        // 'open'/'now'/unknown hosts: bringing the app to the foreground
        // (which the OS already did to deliver this link) is enough for v1.
        break;
    }
  }

  Future<void> _toggleHabit(String id) async {
    try {
      final repo = getIt<LifeRepository>();
      final habits = await repo.habits();
      final matches = habits.where((h) => h.id == id);
      if (matches.isEmpty) return;
      final h = matches.first;
      await repo.logHabit(id, completed: !h.todayDone);
      await getIt<WidgetSyncService>().refreshFromNetwork();
    } catch (_) {
      // best-effort — the app's normal load() on foreground will reconcile
    }
  }
}
