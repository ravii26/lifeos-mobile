import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/widget/active_focus_store.dart';
import '../../core/widget/widget_sync_service.dart';
import '../models/area.dart';
import '../models/behavior_log.dart';
import '../models/calendar_block.dart';
import '../models/capture.dart';
import '../models/decision.dart';
import '../models/document.dart';
import '../models/goal.dart';
import '../models/graph_data.dart';
import '../models/habit.dart';
import '../models/identity.dart';
import '../models/json.dart';
import '../models/note.dart';
import '../models/notebook.dart';
import '../models/onboarding.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/topic.dart';
import '../models/review.dart';
import '../models/task.dart';
import '../models/user_settings.dart';
import '../models/vault_item.dart';

/// Aggregates the domain endpoints the mobile screens use.
/// Kept as one repository for now; can be split per-feature later.
/// Sentinel for "argument omitted" so callers can distinguish leave-unchanged
/// from explicitly clearing a nullable field (null).
const Object _unset = Object();

class LifeRepository {
  final ApiClient _api;
  final ActiveFocusStore _focusStore;
  LifeRepository(this._api, [ActiveFocusStore? focusStore])
      : _focusStore = focusStore ?? ActiveFocusStore();

  // ---- Areas ----
  Future<List<Area>> areas() async {
    final data = await _api.get('/areas');
    return (data as List).map((e) => Area.fromJson(e as Json)).toList();
  }

  Future<Area> createArea({
    required String name,
    String type = 'PRIMARY',
    required String color,
    String icon = 'target',
  }) async {
    final data = await _api.post('/areas', body: {
      'name': name,
      'type': type,
      'color': color,
      'icon': icon,
    });
    return Area.fromJson(data as Json);
  }

  Future<Area> updateArea(
    String id, {
    String? name,
    String? type,
    String? color,
    String? icon,
    bool? isActive,
  }) async {
    final data = await _api.patch('/areas/$id', body: {
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (isActive != null) 'isActive': isActive,
    });
    return Area.fromJson(data as Json);
  }

  Future<void> deleteArea(String id) => _api.delete('/areas/$id');

  // ---- Tasks ----
  Future<List<Task>> tasks({String? areaId, String? status}) async {
    final data =
        await _api.get('/tasks', query: {'areaId': areaId, 'status': status});
    return (data as List).map((e) => Task.fromJson(e as Json)).toList();
  }

  Future<Task> createTask({
    required String title,
    String? areaId,
    String? goalId,
    String? projectId,
    String priority = 'MEDIUM',
    DateTime? dueDate,
  }) async {
    final data = await _api.post('/tasks', body: {
      'title': title,
      if (areaId != null) 'areaId': areaId,
      if (goalId != null) 'goalId': goalId,
      if (projectId != null) 'projectId': projectId,
      'priority': priority,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
    });
    return Task.fromJson(data as Json);
  }

  Future<Task> updateTask(
    String id, {
    String? title,
    String? priority,
    String? status,
    Object? areaId = _unset, // pass null to clear, omit to leave unchanged
    Object? goalId = _unset,
    Object? projectId = _unset,
    Object? dueDate = _unset,
  }) async {
    final data = await _api.patch('/tasks/$id', body: {
      if (title != null) 'title': title,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (!identical(areaId, _unset)) 'areaId': areaId,
      if (!identical(goalId, _unset)) 'goalId': goalId,
      if (!identical(projectId, _unset)) 'projectId': projectId,
      if (!identical(dueDate, _unset))
        'dueDate': dueDate == null ? null : (dueDate as DateTime).toIso8601String(),
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

  /// [date] backfills a specific past day (upsert on habitId+date server-side);
  /// omit it to log today.
  Future<void> logHabit(String id,
      {bool completed = true, int? count, int? minutes, DateTime? date}) {
    return _api.post('/habits/$id/log', body: {
      'completed': completed,
      if (count != null) 'count': count,
      if (minutes != null) 'minutes': minutes,
      if (date != null) 'date': date.toIso8601String(),
    });
  }

  Future<Habit> createHabit({
    required String title,
    required String areaId,
    String habitType = 'BOOLEAN',
    int? targetCount,
    int? targetMinutes,
    String frequency = 'DAILY',
    String? reminderTime,
    String? description,
  }) async {
    final data = await _api.post('/habits', body: {
      'title': title,
      'areaId': areaId,
      'habitType': habitType,
      if (targetCount != null) 'targetCount': targetCount,
      if (targetMinutes != null) 'targetMinutes': targetMinutes,
      'frequency': frequency,
      if (reminderTime != null && reminderTime.isNotEmpty)
        'reminderTime': reminderTime,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return Habit.fromJson(data as Json);
  }

  Future<Habit> updateHabit(
    String id, {
    String? title,
    String? areaId,
    String? habitType,
    int? targetCount,
    int? targetMinutes,
    String? frequency,
    String? reminderTime,
    bool? isActive,
  }) async {
    final data = await _api.patch('/habits/$id', body: {
      if (title != null) 'title': title,
      if (areaId != null) 'areaId': areaId,
      if (habitType != null) 'habitType': habitType,
      if (targetCount != null) 'targetCount': targetCount,
      if (targetMinutes != null) 'targetMinutes': targetMinutes,
      if (frequency != null) 'frequency': frequency,
      // reminderTime is nullable on the backend: '' clears it.
      if (reminderTime != null)
        'reminderTime': reminderTime.isEmpty ? null : reminderTime,
      if (isActive != null) 'isActive': isActive,
    });
    return Habit.fromJson(data as Json);
  }

  Future<void> deleteHabit(String id) => _api.delete('/habits/$id');

  // ---- Goals ----
  Future<List<Goal>> goals(
      {String? areaId, String? status, bool withConfidence = true}) async {
    final data = await _api.get('/goals', query: {
      'areaId': areaId,
      'status': status,
      'withConfidence': withConfidence ? 'true' : null,
    });
    return (data as List).map((e) => Goal.fromJson(e as Json)).toList();
  }

  Future<Goal> createGoal({
    required String title,
    required String areaId,
    String? description,
    String priority = 'MEDIUM',
    DateTime? deadline,
  }) async {
    final data = await _api.post('/goals', body: {
      'title': title,
      'areaId': areaId,
      if (description != null && description.isNotEmpty)
        'description': description,
      'priority': priority,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    return Goal.fromJson(data as Json);
  }

  Future<Goal> updateGoal(
    String id, {
    String? title,
    String? description,
    String? areaId,
    String? priority,
    String? status,
    DateTime? deadline,
  }) async {
    final data = await _api.patch('/goals/$id', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (areaId != null) 'areaId': areaId,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    return Goal.fromJson(data as Json);
  }

  Future<void> deleteGoal(String id) => _api.delete('/goals/$id');

  /// Promote a goal into an active focus slot. When all slots are full the
  /// backend requires [parkGoalId] naming which active goal to park in its place.
  Future<void> activateGoal(String id, {String? parkGoalId}) =>
      _api.post('/goals/$id/activate',
          body: {if (parkGoalId != null) 'parkGoalId': parkGoalId});

  Future<void> parkGoal(String id) => _api.post('/goals/$id/park');

  // ---- Projects ----
  Future<List<Project>> projects(
      {String? areaId, String? goalId, String? status}) async {
    final data = await _api.get('/projects',
        query: {'areaId': areaId, 'goalId': goalId, 'status': status});
    return (data as List).map((e) => Project.fromJson(e as Json)).toList();
  }

  Future<Project> createProject({
    required String title,
    required String areaId,
    String? description,
    String? goalId,
    DateTime? deadline,
  }) async {
    final data = await _api.post('/projects', body: {
      'title': title,
      'areaId': areaId,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (goalId != null) 'goalId': goalId,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    return Project.fromJson(data as Json);
  }

  Future<Project> updateProject(
    String id, {
    String? title,
    String? description,
    String? areaId,
    String? goalId,
    String? status,
    DateTime? deadline,
  }) async {
    final data = await _api.patch('/projects/$id', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (areaId != null) 'areaId': areaId,
      if (goalId != null) 'goalId': goalId,
      if (status != null) 'status': status,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    return Project.fromJson(data as Json);
  }

  Future<void> deleteProject(String id) => _api.delete('/projects/$id');

  // ---- Topics ----
  Future<List<Topic>> topics({String? areaId}) async {
    final data = await _api.get('/topics', query: {'areaId': areaId});
    return (data as List).map((e) => Topic.fromJson(e as Json)).toList();
  }

  Future<Topic> createTopic({
    required String title,
    required String areaId,
    String? description,
    String masteryLevel = 'BEGINNER',
  }) async {
    final data = await _api.post('/topics', body: {
      'title': title,
      'areaId': areaId,
      if (description != null && description.isNotEmpty)
        'description': description,
      'masteryLevel': masteryLevel,
    });
    return Topic.fromJson(data as Json);
  }

  Future<Topic> updateTopic(
    String id, {
    String? title,
    String? description,
    String? areaId,
    String? masteryLevel,
  }) async {
    final data = await _api.patch('/topics/$id', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (areaId != null) 'areaId': areaId,
      if (masteryLevel != null) 'masteryLevel': masteryLevel,
    });
    return Topic.fromJson(data as Json);
  }

  Future<void> deleteTopic(String id) => _api.delete('/topics/$id');

  // ---- Notebooks ----
  Future<List<Notebook>> notebooks({String? topicId}) async {
    final data = await _api.get('/notebooks', query: {'topicId': topicId});
    return (data as List).map((e) => Notebook.fromJson(e as Json)).toList();
  }

  Future<Notebook> createNotebook({
    required String title,
    required String topicId,
    String? description,
    List<String>? tags,
  }) async {
    final data = await _api.post('/notebooks', body: {
      'title': title,
      'topicId': topicId,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    });
    return Notebook.fromJson(data as Json);
  }

  Future<Notebook> updateNotebook(
    String id, {
    String? title,
    String? description,
    List<String>? tags,
  }) async {
    final data = await _api.patch('/notebooks/$id', body: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
    });
    return Notebook.fromJson(data as Json);
  }

  Future<void> deleteNotebook(String id) => _api.delete('/notebooks/$id');

  // ---- Notes ----
  Future<List<Note>> notes(
      {String? topicId, String? notebookId, String? noteType}) async {
    final data = await _api.get('/notes', query: {
      'topicId': topicId,
      'notebookId': notebookId,
      'noteType': noteType,
    });
    return (data as List).map((e) => Note.fromJson(e as Json)).toList();
  }

  Future<Note> createNote({
    required String title,
    required String content,
    required String topicId,
    String? notebookId,
    String noteType = 'CONCEPT',
    List<String>? tags,
  }) async {
    final data = await _api.post('/notes', body: {
      'title': title,
      'content': content,
      'topicId': topicId,
      if (notebookId != null) 'notebookId': notebookId,
      'noteType': noteType,
      if (tags != null && tags.isNotEmpty) 'tags': tags,
    });
    return Note.fromJson(data as Json);
  }

  Future<Note> updateNote(
    String id, {
    String? title,
    String? content,
    String? notebookId,
    String? noteType,
    List<String>? tags,
  }) async {
    final data = await _api.patch('/notes/$id', body: {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (notebookId != null) 'notebookId': notebookId,
      if (noteType != null) 'noteType': noteType,
      if (tags != null) 'tags': tags,
    });
    return Note.fromJson(data as Json);
  }

  Future<void> deleteNote(String id) => _api.delete('/notes/$id');

  // ---- Captures (brain dump) ----
  Future<List<Capture>> captures({bool? processed}) async {
    final data = await _api.get('/captures', query: {'processed': processed});
    return (data as List).map((e) => Capture.fromJson(e as Json)).toList();
  }

  Future<Capture> createCapture(String text) async {
    final data = await _api.post('/captures', body: {'text': text});
    return Capture.fromJson(data as Json);
  }

  /// Uploads an image or voice recording as a capture (multipart). The server
  /// transcribes/describes it with the multimodal AI and classifies it just
  /// like a text dump. [mimeType] e.g. 'image/jpeg' or 'audio/wav'.
  Future<Capture> createMediaCapture(
    String filePath, {
    required String filename,
    required String mimeType,
    String? caption,
  }) async {
    final parts = mimeType.split('/');
    final form = FormData.fromMap({
      if (caption != null && caption.isNotEmpty) 'text': caption,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: DioMediaType(
          parts.first,
          parts.length > 1 ? parts[1] : 'octet-stream',
        ),
      ),
    });
    final data = await _api.post('/captures', body: form);
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

  /// Override the AI's classification (PATCH /captures/:id) before converting.
  Future<Capture> reclassifyCapture(String id, String type) async {
    final data = await _api.patch('/captures/$id', body: {'type': type});
    return Capture.fromJson(data as Json);
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

  Future<CalendarBlock> createBlock({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? blockType,
    String? areaId,
    String? notes,
    String? recurrenceRule,
  }) async {
    final data = await _api.post('/calendar', body: {
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      if (blockType != null) 'blockType': blockType,
      if (areaId != null) 'areaId': areaId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (recurrenceRule != null && recurrenceRule.isNotEmpty)
        'recurrenceRule': recurrenceRule,
    });
    return CalendarBlock.fromJson(data as Json);
  }

  Future<CalendarBlock> updateBlock(
    String id, {
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? blockType,
    String? areaId,
    // Pass '' to turn a recurring series back into a one-off (sends null).
    String? recurrenceRule,
  }) async {
    final data = await _api.patch('/calendar/$id', body: {
      if (title != null) 'title': title,
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime.toIso8601String(),
      if (blockType != null) 'blockType': blockType,
      if (areaId != null) 'areaId': areaId,
      if (recurrenceRule != null)
        'recurrenceRule': recurrenceRule.isEmpty ? null : recurrenceRule,
    });
    return CalendarBlock.fromJson(data as Json);
  }

  Future<void> deleteBlock(String id) => _api.delete('/calendar/$id');

  /// Create or update a single per-occurrence override on a recurring series.
  /// [occurrenceDate] must be the occurrence's original start instant.
  Future<void> upsertException(
    String seriesId, {
    required DateTime occurrenceDate,
    bool? isCancelled,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? blockType,
    String? notes,
  }) {
    return _api.put('/calendar/$seriesId/exceptions', body: {
      'occurrenceDate': occurrenceDate.toIso8601String(),
      if (isCancelled != null) 'isCancelled': isCancelled,
      if (title != null) 'title': title,
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime.toIso8601String(),
      if (blockType != null) 'blockType': blockType,
      if (notes != null) 'notes': notes,
    });
  }

  /// Remove an override so the occurrence reverts to the series default.
  Future<void> deleteException(String seriesId, DateTime occurrenceDate) {
    return _api.delete('/calendar/$seriesId/exceptions',
        query: {'occurrenceDate': occurrenceDate.toIso8601String()});
  }

  /// "This and following": split the series at [fromOccurrenceDate]; occurrences
  /// from there onward become a new series carrying the provided overrides.
  Future<void> splitSeries(
    String seriesId, {
    required DateTime fromOccurrenceDate,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? blockType,
    String? areaId,
    String? recurrenceRule,
  }) {
    return _api.post('/calendar/$seriesId/split', body: {
      'fromOccurrenceDate': fromOccurrenceDate.toIso8601String(),
      if (title != null) 'title': title,
      if (startTime != null) 'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime.toIso8601String(),
      if (blockType != null) 'blockType': blockType,
      if (areaId != null) 'areaId': areaId,
      if (recurrenceRule != null && recurrenceRule.isNotEmpty)
        'recurrenceRule': recurrenceRule,
    });
  }

  /// Overlapping occurrence pairs within a window. Returns raw pair maps.
  Future<List<dynamic>> calendarConflicts({DateTime? from, DateTime? to}) async {
    final data = await _api.get('/calendar/conflicts', query: {
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
    });
    return (data as List?) ?? const [];
  }

  // ---- Reviews ----
  Future<List<Review>> reviews() async {
    final data = await _api.get('/reviews');
    return (data as List).map((e) => Review.fromJson(e as Json)).toList();
  }

  /// Auto-drafted review pre-filled from the period's real data + an AI
  /// narrative (GET /reviews/draft?reviewType=).
  Future<ReviewDraft> reviewDraft(String reviewType) async {
    final data =
        await _api.get('/reviews/draft', query: {'reviewType': reviewType});
    return ReviewDraft.fromJson(data as Json);
  }

  /// Persist a review (POST /reviews). [aiInsights] carries the draft's AI
  /// narrative through so it's stored alongside the user's edits.
  Future<Review> createReview({
    required String reviewType,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? summary,
    String? highlights,
    String? improvements,
    String? userNote,
    Json? aiInsights,
  }) async {
    final data = await _api.post('/reviews', body: {
      'reviewType': reviewType,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      if (summary != null && summary.isNotEmpty) 'summary': summary,
      if (highlights != null && highlights.isNotEmpty) 'highlights': highlights,
      if (improvements != null && improvements.isNotEmpty)
        'improvements': improvements,
      if (userNote != null && userNote.isNotEmpty) 'userNote': userNote,
      if (aiInsights != null && aiInsights.isNotEmpty) 'aiInsights': aiInsights,
    });
    return Review.fromJson(data as Json);
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

  /// Edits a saved review's text fields (PATCH /reviews/:id). An empty
  /// string clears the field server-side (matches [updateVaultItem]'s
  /// `url` handling).
  Future<Review> updateReview(
    String id, {
    String? summary,
    String? highlights,
    String? improvements,
    String? userNote,
  }) async {
    final data = await _api.patch('/reviews/$id', body: {
      if (summary != null) 'summary': summary.isEmpty ? null : summary,
      if (highlights != null)
        'highlights': highlights.isEmpty ? null : highlights,
      if (improvements != null)
        'improvements': improvements.isEmpty ? null : improvements,
      if (userNote != null) 'userNote': userNote.isEmpty ? null : userNote,
    });
    return Review.fromJson(data as Json);
  }

  Future<void> deleteReview(String id) => _api.delete('/reviews/$id');

  // ---- Vault ----
  Future<List<VaultItem>> vault({String? vaultType}) async {
    final data = await _api.get('/vault', query: {'vaultType': vaultType});
    return (data as List).map((e) => VaultItem.fromJson(e as Json)).toList();
  }

  Future<void> markVaultUsed(String id) => _api.post('/vault/$id/used');

  /// Records that a vault item actually helped (POST /vault/:id/helpful).
  /// Feeds the coach's "resurface what helps" ranking.
  Future<void> markVaultHelpful(String id) => _api.post('/vault/$id/helpful');

  Future<VaultItem> createVaultItem({
    required String title,
    required String content,
    required String vaultType,
    String mediaType = 'TEXT',
    String? url,
    List<String>? triggerTags,
  }) async {
    final data = await _api.post('/vault', body: {
      'title': title,
      'content': content,
      'vaultType': vaultType,
      'mediaType': mediaType,
      if (url != null && url.isNotEmpty) 'url': url,
      if (triggerTags != null && triggerTags.isNotEmpty)
        'triggerTags': triggerTags,
    });
    return VaultItem.fromJson(data as Json);
  }

  Future<VaultItem> updateVaultItem(
    String id, {
    String? title,
    String? content,
    String? vaultType,
    String? mediaType,
    String? url,
    List<String>? triggerTags,
  }) async {
    final data = await _api.patch('/vault/$id', body: {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (vaultType != null) 'vaultType': vaultType,
      if (mediaType != null) 'mediaType': mediaType,
      if (url != null) 'url': url.isEmpty ? null : url,
      if (triggerTags != null) 'triggerTags': triggerTags,
    });
    return VaultItem.fromJson(data as Json);
  }

  Future<void> deleteVaultItem(String id) => _api.delete('/vault/$id');

  // ---- Learn (resources) ----
  Future<List<Resource>> resources({String? status}) async {
    final data = await _api.get('/resources', query: {'status': status});
    return (data as List).map((e) => Resource.fromJson(e as Json)).toList();
  }

  Future<Resource> createResource({
    required String title,
    required String topicId,
    required String resourceType,
    String? platform,
    String? url,
    String? notes,
    String status = 'NOT_STARTED',
  }) async {
    final data = await _api.post('/resources', body: {
      'title': title,
      'topicId': topicId,
      'resourceType': resourceType,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      if (url != null && url.isNotEmpty) 'url': url,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'status': status,
    });
    return Resource.fromJson(data as Json);
  }

  Future<Resource> updateResource(
    String id, {
    String? title,
    String? resourceType,
    String? platform,
    String? url,
    String? notes,
    String? status,
  }) async {
    final data = await _api.patch('/resources/$id', body: {
      if (title != null) 'title': title,
      if (resourceType != null) 'resourceType': resourceType,
      if (platform != null) 'platform': platform.isEmpty ? null : platform,
      if (url != null) 'url': url.isEmpty ? null : url,
      if (notes != null) 'notes': notes.isEmpty ? null : notes,
      if (status != null) 'status': status,
    });
    return Resource.fromJson(data as Json);
  }

  Future<void> deleteResource(String id) => _api.delete('/resources/$id');

  /// Logs lesson/minute progress on a resource (B8). [minutesConsumed] is
  /// added to the running total server-side, not set absolutely.
  Future<Resource> updateResourceProgress(
    String id, {
    int? lessonsCompleted,
    int? totalLessons,
    int? minutesConsumed,
    bool autoComplete = true,
  }) async {
    final data = await _api.patch('/resources/$id/progress', body: {
      if (lessonsCompleted != null) 'lessonsCompleted': lessonsCompleted,
      if (totalLessons != null) 'totalLessons': totalLessons,
      if (minutesConsumed != null) 'minutesConsumed': minutesConsumed,
      'autoComplete': autoComplete,
    });
    return Resource.fromJson(data as Json);
  }

  // ---- Decisions ("what now") ----
  Future<DecisionResult> decisionsNow() async {
    final data = await _api.get('/decisions/now');
    return DecisionResult.fromJson(data as Json);
  }

  // ---- Assistant ("Jarvis") ----
  // Same unified persona endpoint the web overlay calls — one message in,
  // one grounded reply out (either the decisions engine's briefing or a
  // knowledge/life-data answer, decided server-side).
  Future<String> assistantAsk(String message, [List<Map<String, String>>? history]) async {
    final data = await _api.post('/assistant/ask', body: {
      'message': message,
      if (history != null) 'history': history,
    });
    return (data as Json)['answer'] as String? ?? '';
  }

  // ---- Identity ----
  Future<Identity> identity() async {
    final data = await _api.get('/identity');
    return Identity.fromJson(data is Json ? data : null);
  }

  Future<Identity> saveIdentity({
    String? personality,
    List<String>? values,
    List<String>? strengths,
    List<String>? weaknesses,
    String? purpose,
    String? thisYearGoal,
    String? bigPicture,
    String? lifeVision,
  }) async {
    final data = await _api.put('/identity', body: {
      'personality': personality,
      if (values != null) 'values': values,
      if (strengths != null) 'strengths': strengths,
      if (weaknesses != null) 'weaknesses': weaknesses,
      'purpose': purpose,
      'thisYearGoal': thisYearGoal,
      'bigPicture': bigPicture,
      'lifeVision': lifeVision,
    });
    return Identity.fromJson(data is Json ? data : null);
  }

  // ---- Behavior ----
  Future<List<BehaviorLog>> behaviorLogs({String? eventType}) async {
    final data = await _api.get('/behavior', query: {'eventType': eventType});
    return (data as List).map((e) => BehaviorLog.fromJson(e as Json)).toList();
  }

  Future<void> recordBehavior(String eventType,
      {Map<String, dynamic>? metadata}) {
    return _api.post('/behavior', body: {
      'eventType': eventType,
      if (metadata != null) 'metadata': metadata,
    });
  }

  // ---- Knowledge graph ----
  Future<GraphData> graph() async {
    final data = await _api.get('/graph');
    return GraphData.fromJson(data as Json);
  }

  // ---- Settings ----
  Future<UserSettings> settings() async {
    final data = await _api.get('/settings');
    return UserSettings.fromJson(data as Json);
  }

  Future<UserSettings> updateSettings(
      {String? vibe,
      String? accent,
      String? font,
      String? startTab,
      List<String>? enabledModules}) async {
    final data = await _api.patch('/settings', body: {
      if (vibe != null) 'vibe': vibe,
      if (accent != null) 'accent': accent,
      if (font != null) 'font': font,
      if (startTab != null) 'startTab': startTab,
      if (enabledModules != null) 'enabledModules': enabledModules,
    });
    return UserSettings.fromJson(data as Json);
  }

  // ---- Focus sessions ----
  /// [label] is a display-only title (e.g. the task's title) persisted
  /// locally so the home-screen widget can show "Focusing: <label>" without
  /// an extra round trip.
  Future<String> startFocus(
      {String? taskId, String? habitId, String? label}) async {
    final data = await _api.post('/focus', body: {
      'startedAt': DateTime.now().toIso8601String(),
      if (taskId != null) 'taskId': taskId,
      if (habitId != null) 'habitId': habitId,
    });
    final id = asString((data as Json)['id']);
    await _focusStore.start(id, label: label);
    await WidgetSyncService.instance?.pushFocusState(active: true, label: label);
    return id;
  }

  Future<void> stopFocus(String id) async {
    await _api.patch('/focus/$id/stop', body: {
      'endedAt': DateTime.now().toIso8601String(),
    });
    await _focusStore.clear();
    await WidgetSyncService.instance?.pushFocusState(active: false);
  }

  // ---- Library (document ingest + RAG Q&A + action extraction) ----
  Future<List<LibraryDocument>> documents() async {
    final data = await _api.get('/documents');
    return (data as List)
        .map((e) => LibraryDocument.fromJson(Json.from(e as Map)))
        .toList();
  }

  Future<LibraryDocument> createDocument({
    String? title,
    required String text,
  }) async {
    final data = await _api.post('/documents', body: {
      if (title != null && title.isNotEmpty) 'title': title,
      'text': text,
    });
    return LibraryDocument.fromJson(data as Json);
  }

  Future<LibraryDocument> document(String id) async {
    final data = await _api.get('/documents/$id');
    return LibraryDocument.fromJson(data as Json);
  }

  Future<void> deleteDocument(String id) => _api.delete('/documents/$id');

  Future<AskResult> askLibrary(String question, {String? documentId}) async {
    final data = await _api.post('/documents/ask', body: {
      'question': question,
      if (documentId != null) 'documentId': documentId,
    });
    return AskResult.fromJson(data as Json);
  }

  Future<List<DocumentSuggestion>> extractActions(String documentId) async {
    final data = await _api.post('/documents/$documentId/extract');
    return (data as List)
        .map((e) => DocumentSuggestion.fromJson(Json.from(e as Map)))
        .toList();
  }

  Future<List<DocumentSuggestion>> suggestions(String documentId) async {
    final data = await _api.get('/documents/$documentId/suggestions');
    return (data as List)
        .map((e) => DocumentSuggestion.fromJson(Json.from(e as Map)))
        .toList();
  }

  Future<DocumentSuggestion> acceptSuggestion(
    String id, {
    String? areaId,
    String? priority,
  }) async {
    final data = await _api.post('/documents/suggestions/$id/accept', body: {
      if (areaId != null) 'areaId': areaId,
      if (priority != null) 'priority': priority,
    });
    return DocumentSuggestion.fromJson(data as Json);
  }

  Future<void> dismissSuggestion(String id) =>
      _api.post('/documents/suggestions/$id/dismiss');

  // ---- Onboarding (cold-start setup) ----
  /// Turns a few sentences about the user's life into a proposed starter
  /// setup — Areas plus Goals/Habits/Tasks under them. Stateless on the
  /// server; nothing is created until the caller submits the individual
  /// createArea/createGoal/createHabit/createTask calls itself.
  Future<OnboardingExtraction> extractOnboarding(String text) async {
    final data = await _api.post('/onboarding/extract', body: {'text': text});
    return OnboardingExtraction.fromJson(data as Json);
  }
}
