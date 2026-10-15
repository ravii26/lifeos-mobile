import 'package:shared_preferences/shared_preferences.dart';

import '../api/offline_store.dart';
import '../notifications/notification_service.dart';

/// Everything this phone keeps for one account: offline copies of reads and
/// queued actions, the chat history, first-run and focus markers, nudge
/// times, and every scheduled notification. One person's data must never
/// show up in another person's account on the same phone.
class LocalData {
  static const _ownerKey = 'local_data_owner';

  // Per-account keys outside the offline cache. Device preferences (voice
  // language, appearance) are not here on purpose.
  static const _accountKeys = [
    'chat_history_v1',
    'ally_first_run_seen',
    'active_focus_session_id',
    'active_focus_started_at',
    'active_focus_label',
    'guide_nightly_time',
    'guide_morning_time',
    'ally_paused',
  ];

  /// Removes all of it. Used on sign-out.
  static Future<void> wipe() async {
    await OfflineStore().clear();
    final prefs = await SharedPreferences.getInstance();
    for (final k in _accountKeys) {
      await prefs.remove(k);
    }
    await prefs.remove(_ownerKey);
    await NotificationService.instance.cancelAll();
  }

  /// Called before an account opens. If the phone last held someone else's
  /// data (a sign-out that never finished, a request that wrote after it),
  /// it is wiped first, then the phone is marked as this account's.
  static Future<void> claimFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_ownerKey);
    if (owner != userId) {
      await wipe();
      await prefs.setString(_ownerKey, userId);
    }
  }
}
