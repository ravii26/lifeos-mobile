import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/area.dart';
import '../../data/models/capture.dart';
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
  final String? error;

  const LifeState({
    this.status = LoadStatus.initial,
    this.areas = const [],
    this.tasks = const [],
    this.habits = const [],
    this.captures = const [],
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

  LifeState copyWith({
    LoadStatus? status,
    List<Area>? areas,
    List<Task>? tasks,
    List<Habit>? habits,
    List<Capture>? captures,
    String? error,
  }) =>
      LifeState(
        status: status ?? this.status,
        areas: areas ?? this.areas,
        tasks: tasks ?? this.tasks,
        habits: habits ?? this.habits,
        captures: captures ?? this.captures,
        error: error,
      );

  @override
  List<Object?> get props => [status, areas, tasks, habits, captures, error];
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
      ]);
      final habits = results[2] as List<Habit>;
      emit(state.copyWith(
        status: LoadStatus.ready,
        areas: results[0] as List<Area>,
        tasks: results[1] as List<Task>,
        habits: habits,
        captures: results[3] as List<Capture>,
      ));
      // Best-effort: keep local habit reminders in sync with the backend.
      NotificationService.instance.syncHabitReminders(habits);
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  Future<void> refresh() => load();

  Future<void> completeTask(String id) async {
    try {
      await _repo.completeTask(id);
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

  Future<void> addTask(
      {required String title, String? areaId, String priority = 'MEDIUM'}) async {
    try {
      await _repo.createTask(
          title: title,
          areaId: areaId,
          priority: priority,
          dueDate: DateTime.now());
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
  Future<void> saveHabit({
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
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> deleteHabit(String id) async {
    emit(state.copyWith(
        habits: state.habits.where((h) => h.id != id).toList()));
    try {
      await _repo.deleteHabit(id);
      NotificationService.instance.syncHabitReminders(state.habits);
    } on ApiException catch (_) {
      await refresh();
    }
  }

  Future<void> logHabit(Habit h) async {
    try {
      await _repo.logHabit(h.id,
          completed: true,
          count: h.kind == 'count' ? h.todayCount + 1 : null,
          minutes: h.kind == 'timer' ? h.todayMinutes : null);
      final habits = await _repo.habits();
      emit(state.copyWith(habits: habits));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> addCapture(String text) async {
    try {
      await _repo.createCapture(text);
      final captures = await _repo.captures(processed: false);
      emit(state.copyWith(captures: captures));
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
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

  Future<void> convertCapture(String id, {String? areaId}) async {
    try {
      await _repo.convertCapture(id, areaId: areaId);
      await refresh();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
