import 'package:shared_preferences/shared_preferences.dart';

/// Persists "is a focus session currently active" independent of any screen's
/// lifecycle, so the home-screen widget can reflect it even if the user
/// backgrounds/kills the app mid-session.
class ActiveFocusStore {
  static const _idKey = 'active_focus_session_id';
  static const _startedAtKey = 'active_focus_started_at';
  static const _labelKey = 'active_focus_label';

  Future<void> start(String sessionId, {String? label}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, sessionId);
    await prefs.setString(_startedAtKey, DateTime.now().toIso8601String());
    if (label != null) {
      await prefs.setString(_labelKey, label);
    } else {
      await prefs.remove(_labelKey);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_startedAtKey);
    await prefs.remove(_labelKey);
  }

  /// Returns null if no session is active.
  Future<ActiveFocusSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    final startedAt = prefs.getString(_startedAtKey);
    if (id == null || startedAt == null) return null;
    return ActiveFocusSession(
      sessionId: id,
      startedAt: DateTime.parse(startedAt),
      label: prefs.getString(_labelKey),
    );
  }
}

class ActiveFocusSession {
  final String sessionId;
  final DateTime startedAt;
  final String? label;

  const ActiveFocusSession(
      {required this.sessionId, required this.startedAt, this.label});
}
