import '../../core/api/api_client.dart';
import '../models/area.dart';
import '../models/calendar_block.dart';
import '../models/capture.dart';
import '../models/habit.dart';
import '../models/json.dart';
import '../models/resource.dart';
import '../models/review.dart';
import '../models/task.dart';
import '../models/user_settings.dart';
import '../models/vault_item.dart';

/// Aggregates the domain endpoints the mobile screens use.
/// Kept as one repository for now; can be split per-feature later.
class LifeRepository {
  final ApiClient _api;
  LifeRepository(this._api);

  // ---- Areas ----
  Future<List<Area>> areas() async {
    final data = await _api.get('/areas');
    return (data as List).map((e) => Area.fromJson(e as Json)).toList();
  }

  // ---- Tasks ----
  Future<List<Task>> tasks({String? areaId, String? status}) async {
    final data =
        await _api.get('/tasks', query: {'areaId': areaId, 'status': status});
    return (data as List).map((e) => Task.fromJson(e as Json)).toList();
  }

  Future<Task> createTask({
    required String title,
    String? areaId,
    String priority = 'MEDIUM',
    DateTime? dueDate,
  }) async {
    final data = await _api.post('/tasks', body: {
      'title': title,
      if (areaId != null) 'areaId': areaId,
      'priority': priority,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
    });
    return Task.fromJson(data as Json);
  }

  Future<Task> completeTask(String id) async {
    final data = await _api.patch('/tasks/$id/complete');
    return Task.fromJson(data as Json);
  }

  Future<void> deleteTask(String id) => _api.delete('/tasks/$id');

  // ---- Habits ----
  Future<List<Habit>> habits({bool? activeOnly}) async {
    final data = await _api
        .get('/habits', query: {'isActive': activeOnly == true ? true : null});
    return (data as List).map((e) => Habit.fromJson(e as Json)).toList();
  }

  Future<void> logHabit(String id,
      {bool completed = true, int? count, int? minutes}) {
    return _api.post('/habits/$id/log', body: {
      'completed': completed,
      if (count != null) 'count': count,
      if (minutes != null) 'minutes': minutes,
    });
  }

  // ---- Captures (brain dump) ----
  Future<List<Capture>> captures({bool? processed}) async {
    final data = await _api.get('/captures', query: {'processed': processed});
    return (data as List).map((e) => Capture.fromJson(e as Json)).toList();
  }

  Future<Capture> createCapture(String text) async {
    final data = await _api.post('/captures', body: {'text': text});
    return Capture.fromJson(data as Json);
  }

  Future<void> convertCapture(String id,
      {String? areaId, String? topicId, String? priority}) {
    return _api.post('/captures/$id/convert', body: {
      if (areaId != null) 'areaId': areaId,
      if (topicId != null) 'topicId': topicId,
      if (priority != null) 'priority': priority,
    });
  }

  Future<void> dismissCapture(String id) => _api.delete('/captures/$id');

  // ---- Calendar ----
  Future<List<CalendarBlock>> calendar({DateTime? from, DateTime? to}) async {
    final data = await _api.get('/calendar', query: {
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
    });
    return (data as List)
        .map((e) => CalendarBlock.fromJson(e as Json))
        .toList();
  }

  // ---- Reviews ----
  Future<List<Review>> reviews() async {
    final data = await _api.get('/reviews');
    return (data as List).map((e) => Review.fromJson(e as Json)).toList();
  }

  Future<List<ReviewInsight>> reviewInsights(String reviewId) async {
    final data = await _api.get('/reviews/$reviewId/insights');
    return (data as List)
        .map((e) => ReviewInsight.fromJson(e as Json))
        .toList();
  }

  Future<void> updateInsight(String insightId,
      {String? status, String? userNote}) {
    return _api.patch('/reviews/insights/$insightId', body: {
      if (status != null) 'status': status,
      if (userNote != null) 'userNote': userNote,
    });
  }

  // ---- Vault ----
  Future<List<VaultItem>> vault({String? vaultType}) async {
    final data = await _api.get('/vault', query: {'vaultType': vaultType});
    return (data as List).map((e) => VaultItem.fromJson(e as Json)).toList();
  }

  Future<void> markVaultUsed(String id) => _api.post('/vault/$id/used');

  // ---- Learn (resources) ----
  Future<List<Resource>> resources({String? status}) async {
    final data = await _api.get('/resources', query: {'status': status});
    return (data as List).map((e) => Resource.fromJson(e as Json)).toList();
  }

  // ---- Settings ----
  Future<UserSettings> settings() async {
    final data = await _api.get('/settings');
    return UserSettings.fromJson(data as Json);
  }

  Future<UserSettings> updateSettings(
      {String? vibe, String? accent, String? font, String? startTab}) async {
    final data = await _api.patch('/settings', body: {
      if (vibe != null) 'vibe': vibe,
      if (accent != null) 'accent': accent,
      if (font != null) 'font': font,
      if (startTab != null) 'startTab': startTab,
    });
    return UserSettings.fromJson(data as Json);
  }

  // ---- Focus sessions ----
  Future<String> startFocus({String? taskId, String? habitId}) async {
    final data = await _api.post('/focus', body: {
      'startedAt': DateTime.now().toIso8601String(),
      if (taskId != null) 'taskId': taskId,
      if (habitId != null) 'habitId': habitId,
    });
    return asString((data as Json)['id']);
  }

  Future<void> stopFocus(String id, {int? durationMinutes}) {
    return _api.patch('/focus/$id/stop', body: {
      'endedAt': DateTime.now().toIso8601String(),
    });
  }
}
