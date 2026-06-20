import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/note.dart';
import '../../data/models/notebook.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/life_repository.dart';
import '../shell/life_cubit.dart' show LoadStatus;

class KnowledgeState extends Equatable {
  final LoadStatus status;
  final List<Topic> topics;
  final List<Notebook> notebooks;
  final List<Note> notes;
  final String? selectedTopicId; // null = all topics
  final String? error;

  const KnowledgeState({
    this.status = LoadStatus.initial,
    this.topics = const [],
    this.notebooks = const [],
    this.notes = const [],
    this.selectedTopicId,
    this.error,
  });

  bool _inTopic(String topicId) =>
      selectedTopicId == null || selectedTopicId == topicId;

  List<Notebook> get visibleNotebooks =>
      notebooks.where((n) => _inTopic(n.topicId)).toList();

  /// Notes not filed in any notebook, within the current topic filter.
  List<Note> get looseNotes => notes
      .where((n) => n.notebookId == null && _inTopic(n.topicId))
      .toList();

  List<Note> notesIn(String notebookId) =>
      notes.where((n) => n.notebookId == notebookId).toList();

  int noteCount(String notebookId) =>
      notes.where((n) => n.notebookId == notebookId).length;

  Topic? topicById(String? id) {
    if (id == null) return null;
    for (final t in topics) {
      if (t.id == id) return t;
    }
    return null;
  }

  KnowledgeState copyWith({
    LoadStatus? status,
    List<Topic>? topics,
    List<Notebook>? notebooks,
    List<Note>? notes,
    String? selectedTopicId,
    bool clearTopic = false,
    String? error,
  }) =>
      KnowledgeState(
        status: status ?? this.status,
        topics: topics ?? this.topics,
        notebooks: notebooks ?? this.notebooks,
        notes: notes ?? this.notes,
        selectedTopicId:
            clearTopic ? null : (selectedTopicId ?? this.selectedTopicId),
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, topics, notebooks, notes, selectedTopicId, error];
}

class KnowledgeCubit extends Cubit<KnowledgeState> {
  final LifeRepository _repo;
  KnowledgeCubit(this._repo) : super(const KnowledgeState());

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        _repo.topics(),
        _repo.notebooks(),
        _repo.notes(),
      ]);
      emit(state.copyWith(
        status: LoadStatus.ready,
        topics: results[0] as List<Topic>,
        notebooks: results[1] as List<Notebook>,
        notes: results[2] as List<Note>,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  void selectTopic(String? topicId) {
    if (topicId == null) {
      emit(state.copyWith(clearTopic: true));
    } else {
      emit(state.copyWith(selectedTopicId: topicId));
    }
  }

  Future<void> createTopic({
    required String title,
    required String areaId,
    String? description,
  }) async {
    try {
      await _repo.createTopic(
          title: title, areaId: areaId, description: description);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> createNotebook({
    required String title,
    required String topicId,
    String? description,
    List<String>? tags,
  }) async {
    try {
      await _repo.createNotebook(
          title: title,
          topicId: topicId,
          description: description,
          tags: tags);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> updateNotebook(
    String id, {
    String? title,
    String? description,
    List<String>? tags,
  }) async {
    try {
      await _repo.updateNotebook(id,
          title: title, description: description, tags: tags);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> deleteNotebook(String id) async {
    emit(state.copyWith(
        notebooks: state.notebooks.where((n) => n.id != id).toList()));
    try {
      await _repo.deleteNotebook(id);
      await load();
    } on ApiException catch (_) {
      await load();
    }
  }

  Future<void> createNote({
    required String title,
    required String content,
    required String topicId,
    String? notebookId,
    String noteType = 'CONCEPT',
    List<String>? tags,
  }) async {
    try {
      await _repo.createNote(
          title: title,
          content: content,
          topicId: topicId,
          notebookId: notebookId,
          noteType: noteType,
          tags: tags);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    String? notebookId,
    String? noteType,
    List<String>? tags,
  }) async {
    try {
      await _repo.updateNote(id,
          title: title,
          content: content,
          notebookId: notebookId,
          noteType: noteType,
          tags: tags);
      await load();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> deleteNote(String id) async {
    emit(state.copyWith(notes: state.notes.where((n) => n.id != id).toList()));
    try {
      await _repo.deleteNote(id);
    } on ApiException catch (_) {
      await load();
    }
  }
}
