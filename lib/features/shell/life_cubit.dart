import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/widget/widget_sync_service.dart';
import '../../data/models/area.dart';
import '../../data/models/capture.dart';
import '../../data/models/goal.dart';
import '../../data/models/project.dart';
import '../../data/models/habit.dart';
import '../../data/models/task.dart';
import '../../data/repositories/life_repository.dart';

enum LoadStatus { initial, loading, ready, error }

class LifeState extends Equatable {
  final LoadStatus status;
  final List<Area> areas;
  final List<Task> tasks;
  final List<Habit> habits;
  final List<Capture> captures;
  final List<Goal> goals;
  final List<Project> projects;
  final String? error;

  const LifeState({
    this.status = LoadStatus.initial,
    this.areas = const [],
    this.tasks = const [],
    this.habits = const [],
    this.captures = const [],
    this.goals = const [],
    this.projects = const [],
    this.error,
  });

  // Derived helpers used by screens ----------------------------------
  List<Task> get todayTasks {
    final now = DateTime.now();
    return openTasks.where((t) {
      final d = t.dueDate;
      return d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    }).toList();
  }

  List<Task> get openTasks => tasks.where((t) => !t.isDone).toList();
  List<Task> get doneTasks => tasks.where((t) => t.isDone).toList();
  List<Capture> get pendingCaptures =>
      captures.where((c) => !c.processed).toList();

  int get avgScore => areas.isEmpty
      ? 0
      : (areas.map((a) => a.score).reduce((a, b) => a + b) / areas.length)
          .round();

  Area? get weakestArea {
    if (areas.isEmpty) return null;
    final sorted = [...areas]..sort((a, b) => a.score.compareTo(b.score));
    return sorted.first;
  }

  Area? areaById(String? id) {
    if (id == null) return null;
    for (final a in areas) {
      if (a.id == id) return a;
    }
    return null;
  }

  Goal? goalById(String? id) {
    if (id == null) return null;
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  Project? projectById(String? id) {
    if (id == null) return null;
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  LifeState copyWith({
    LoadStatus? status,
    List<Area>? areas,
    List<Task>? tasks,
    List<Habit>? habits,
    List<Capture>? captures,
    List<Goal>? goals,
    List<Project>? projects,
    String? error,
  }) =>
      LifeState(
        status: status ?? this.status,
        areas: areas ?? this.areas,
        tasks: tasks ?? this.tasks,
        habits: habits ?? this.habits,
        captures: captures ?? this.captures,
        goals: goals ?? this.goals,
        projects: projects ?? this.projects,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, areas, tasks, habits, captures, goals, projects, error];
}

class LifeCubit extends Cubit<LifeState> {
  final LifeRepository _repo;
  LifeCubit(this._repo) : super(const LifeState());

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        _repo.areas(),
        _repo.tasks(),
        _repo.habits(),
        _repo.captures(processed: false),
        _repo.goals(withConfidence: false),
        _repo.projects(),
      ]);
      final habits = results[2] as List<Habit>;
      emit(state.copyWith(
        status: LoadStatus.ready,
        areas: results[0] as List<Area>,
        tasks: results[1] as List<Task>,
        habits: habits,
        captures: results[3] as List<Capture>,
        goals: results[4] as List<Goal>,
        projects: results[5] as List<Project>,
      ));
      // Best-effort: keep local habit reminders in sync with the backend.
      NotificationService.instance.syncHabitReminders(habits);
      _syncWidgetHabits(habits);
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  Future<void> refresh() => load();

  /// Best-effort: keeps the home-screen widget's habit checklist in sync.
  void _syncWidgetHabits(List<Habit> habits) {
    getIt<WidgetSyncService>().pushHabits(habits);
  }

  Future<void> completeTask(String id) async {
    try {
      final task = state.tasks.firstWhere((t) => t.id == id);
      if (task.isDone) {
        await _repo.updateTask(id, status: 'PENDING');
      } else {
        await _repo.completeTask(id);
      }
      final tasks = await _repo.tasks();
      emit(state.copyWith(tasks: tasks));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> deleteTask(String id) async {
    emit(state.copyWith(
        tasks: state.tasks.where((t) => t.id != id).toList()));
    try {
      await _repo.deleteTask(id);
    } on ApiException catch (_) {
      await refresh();
    }
  }

  Future<void> addTask({
    required String title,
    String? areaId,
    String? goalId,
    String? projectId,
    String priority = 'MEDIUM',
    DateTime? dueDate,
  }) async {
    try {
      await _repo.createTask(
          title: title,
          areaId: areaId,
          goalId: goalId,
          projectId: projectId,
          priority: priority,
          dueDate: dueDate ?? DateTime.now());
      final tasks = await _repo.tasks();
      emit(state.copyWith(tasks: tasks));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  // ---- Areas CRUD ----
  Future<void> saveArea({
    String? id,
    required String name,
    required String type,
    required String color,
    required String icon,
  }) async {
    try {
      if (id == null) {
        await _repo.createArea(name: name, type: type, color: color, icon: icon);
      } else {
        await _repo.updateArea(id,
            name: name, type: type, color: color, icon: icon);
      }
      emit(state.copyWith(areas: await _repo.areas()));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> deleteArea(String id) async {
    emit(state.copyWith(
        areas: state.areas.where((a) => a.id != id).toList()));
    try {
      await _repo.deleteArea(id);
    } on ApiException catch (_) {
      await refresh();
    }
  }

  // ---- Habits CRUD ----
  /// Clears any surfaced error so the next failure re-triggers UI listeners.
  void clearError() {
    if (state.error != null) emit(state.copyWith(error: null));
  }

  Future<bool> saveHabit({
    String? id,
    required String title,
    required String areaId,
    required String habitType,
    int? targetCount,
    int? targetMinutes,
    String frequency = 'DAILY',
    String? reminderTime,
  }) async {
    try {
      if (id == null) {
        await _repo.createHabit(
            title: title,
            areaId: areaId,
            habitType: habitType,
            targetCount: targetCount,
            targetMinutes: targetMinutes,
            frequency: frequency,
            reminderTime: reminderTime);
      } else {
        await _repo.updateHabit(id,
            title: title,
            areaId: areaId,
            habitType: habitType,
            targetCount: targetCount,
            targetMinutes: targetMinutes,
            frequency: frequency,
            reminderTime: reminderTime ?? '');
      }
      final habits = await _repo.habits();
      emit(state.copyWith(habits: habits));
      NotificationService.instance.syncHabitReminders(habits);
      _syncWidgetHabits(habits);
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
      return false;
    }
  }

  Future<void> deleteHabit(String id) async {
    emit(state.copyWith(
        habits: state.habits.where((h) => h.id != id).toList()));
    try {
      await _repo.deleteHabit(id);
      NotificationService.instance.syncHabitReminders(state.habits);
      _syncWidgetHabits(state.habits);
    } on ApiException catch (_) {
      await refresh();
    }
  }

  Future<void> logHabit(Habit h) async {
    try {
      final wasDone = h.todayDone;
      if (h.kind == 'boolean') {
        await _repo.logHabit(h.id, completed: !wasDone);
      } else if (h.kind == 'count') {
        final nextCount = h.todayCount + 1;
        await _repo.logHabit(
          h.id,
          completed: nextCount >= h.targetCount,
          count: nextCount,
        );
      } else if (h.kind == 'timer') {
        final nextMinutes = h.todayMinutes + 15;
        await _repo.logHabit(
          h.id,
          completed: nextMinutes >= h.targetMinutes,
          minutes: nextMinutes,
        );
      }
      final habits = await _repo.habits();
      emit(state.copyWith(habits: habits));
      _syncWidgetHabits(habits);
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> updateHabitLog(Habit h, {required int count, required int minutes, required bool completed}) async {
    try {
      await _repo.logHabit(h.id, completed: completed, count: count, minutes: minutes);
      final habits = await _repo.habits();
      emit(state.copyWith(habits: habits));
      _syncWidgetHabits(habits);
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  /// Retroactively logs a missed day for [h] — e.g. "I did this yesterday but
  /// forgot to check it off."
  Future<void> backfillHabitLog(
    Habit h,
    DateTime date, {
    required bool completed,
    int? count,
    int? minutes,
  }) async {
    try {
      await _repo.logHabit(h.id,
          completed: completed, count: count, minutes: minutes, date: date);
      final habits = await _repo.habits();
      emit(state.copyWith(habits: habits));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> addCapture(String text) async {
    try {
      await _repo.createCapture(text);
      await _refreshCaptures();
      // Capture classification runs in the background on the server (~1-2s).
      // Poll a couple of times so the type + worth rating appear without the
      // user pulling to refresh. Best-effort: ignore failures, stop if any
      // pending capture is still unclassified after the last attempt.
      _pollCaptureClassification();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  /// Uploads a photo or voice note as a capture. The server transcribes and
  /// classifies it; we poll for the result like a text capture.
  Future<void> addMediaCapture(
    String filePath, {
    required String filename,
    required String mimeType,
    String? caption,
  }) async {
    try {
      await _repo.createMediaCapture(
        filePath,
        filename: filename,
        mimeType: mimeType,
        caption: caption,
      );
      await _refreshCaptures();
      _pollCaptureClassification();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> _refreshCaptures() async {
    final captures = await _repo.captures(processed: false);
    if (!isClosed) emit(state.copyWith(captures: captures));
  }

  /// Refetch the inbox a few times to pick up async AI classification.
  Future<void> _pollCaptureClassification() async {
    const delays = [
      Duration(milliseconds: 1500),
      Duration(milliseconds: 2500),
      Duration(milliseconds: 4000),
    ];
    for (final d in delays) {
      await Future<void>.delayed(d);
      if (isClosed) return;
      try {
        await _refreshCaptures();
      } catch (_) {
        return; // network blip — pull-to-refresh remains the fallback
      }
      final allClassified =
          state.pendingCaptures.every((c) => c.isClassified);
      if (allClassified) return;
    }
  }

  Future<void> dismissCapture(String id) async {
    emit(state.copyWith(
        captures: state.captures.where((c) => c.id != id).toList()));
    try {
      await _repo.dismissCapture(id);
    } on ApiException catch (_) {
      await refresh();
    }
  }

  /// Converts a capture into its target entity. Returns the destination type
  /// (TASK/HABIT/NOTE/RESOURCE/VAULT) on success, or null on failure (error is
  /// surfaced in state so the caller can show it).
  Future<String?> convertCapture(String id,
      {String? areaId, String? topicId}) async {
    try {
      await _repo.convertCapture(id, areaId: areaId, topicId: topicId);
      final type =
          state.captures.firstWhere((c) => c.id == id).type;
      await refresh();
      return type;
    } on StateError {
      await refresh();
      return null;
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
      return null;
    }
  }

  /// Override the AI classification, then reload the inbox.
  Future<void> reclassifyCapture(String id, String type) async {
    try {
      await _repo.reclassifyCapture(id, type);
      final captures = await _repo.captures(processed: false);
      emit(state.copyWith(captures: captures));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  /// Edits a task. The edit form always supplies the desired final state, so
  /// areaId/dueDate are set explicitly (null clears them).
  Future<bool> editTask(
    String id, {
    required String title,
    required String priority,
    String? status,
    String? areaId,
    String? goalId,
    String? projectId,
    DateTime? dueDate,
  }) async {
    try {
      await _repo.updateTask(
        id,
        title: title,
        priority: priority,
        status: status,
        areaId: areaId,
        goalId: goalId,
        projectId: projectId,
        dueDate: dueDate,
      );
      emit(state.copyWith(tasks: await _repo.tasks()));
      return true;
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
      return false;
    }
  }
}
