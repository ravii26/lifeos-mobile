import 'dart:async';

import '../../data/repositories/life_repository.dart';
import '../di/service_locator.dart';
import 'notification_service.dart';

/// Keeps what Ally says on its own (ADR 0027) in step with the day: fetches
/// the server's agenda and schedules it. Called on open, after anything
/// changes (debounced), and hourly from the background job.
class AgendaSync {
  static Timer? _debounce;

  static Future<void> now() async {
    try {
      await NotificationService.instance.syncAgenda(await getIt<LifeRepository>().agenda());
    } catch (_) {
      // Offline or the server is waking: what's already scheduled stays.
    }
  }

  /// Many changes in a row (ticking three things) → one refresh.
  static void soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), now);
  }
}
