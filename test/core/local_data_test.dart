import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/session/local_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What account A leaves on the phone.
  const accountA = {
    'local_data_owner': 'user-a',
    'chat_history_v1': '[{"text":"my private chat"}]',
    'offline_cache_v1:/tasks?': '{"at":"2026-10-15T10:00:00.000","data":[{"title":"A task"}]}',
    'offline_queue_v1': '[]',
    'ally_first_run_seen': true,
    'guide_nightly_time': '21:30',
    'chat_voice_lang': 'en_IN', // a device preference, stays
  };

  test('a different account wipes the previous account\'s data first', () async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(accountA));
    await LocalData.claimFor('user-b');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_history_v1'), isNull);
    expect(prefs.getString('offline_cache_v1:/tasks?'), isNull);
    expect(prefs.getBool('ally_first_run_seen'), isNull);
    expect(prefs.getString('guide_nightly_time'), isNull);
    expect(prefs.getString('local_data_owner'), 'user-b');
    expect(prefs.getString('chat_voice_lang'), 'en_IN');
  });

  test('the same account keeps its data', () async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(accountA));
    await LocalData.claimFor('user-a');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chat_history_v1'), isNotNull);
    expect(prefs.getString('offline_cache_v1:/tasks?'), isNotNull);
  });

  test('signing out removes everything account-specific', () async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(accountA));
    await LocalData.wipe();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'chat_voice_lang'});
  });
}
