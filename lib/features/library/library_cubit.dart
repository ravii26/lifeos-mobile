import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/document.dart';
import '../../data/repositories/life_repository.dart';
import '../shell/life_cubit.dart' show LoadStatus;

/// Sentinel so copyWith can distinguish "leave unchanged" from "set to null".
const Object _keep = Object();

class LibraryState extends Equatable {
  final LoadStatus status;
  final List<LibraryDocument> documents;
  final String? error;

  // Ask
  final bool asking;
  final AskResult? answer;
  final String? askError;

  // Extraction / review
  final Set<String> expanded; // doc ids whose suggestions panel is open
  final Set<String> extracting; // doc ids currently extracting
  final Map<String, List<DocumentSuggestion>> suggestions; // docId -> list
  final Set<String> busySuggestions; // suggestion ids mid-accept/dismiss

  const LibraryState({
    this.status = LoadStatus.initial,
    this.documents = const [],
    this.error,
    this.asking = false,
    this.answer,
    this.askError,
    this.expanded = const {},
    this.extracting = const {},
    this.suggestions = const {},
    this.busySuggestions = const {},
  });

  LibraryState copyWith({
    LoadStatus? status,
    List<LibraryDocument>? documents,
    Object? error = _keep,
    bool? asking,
    Object? answer = _keep,
    Object? askError = _keep,
    Set<String>? expanded,
    Set<String>? extracting,
    Map<String, List<DocumentSuggestion>>? suggestions,
    Set<String>? busySuggestions,
  }) =>
      LibraryState(
        status: status ?? this.status,
        documents: documents ?? this.documents,
        error: error == _keep ? this.error : error as String?,
        asking: asking ?? this.asking,
        answer: answer == _keep ? this.answer : answer as AskResult?,
        askError: askError == _keep ? this.askError : askError as String?,
        expanded: expanded ?? this.expanded,
        extracting: extracting ?? this.extracting,
        suggestions: suggestions ?? this.suggestions,
        busySuggestions: busySuggestions ?? this.busySuggestions,
      );

  @override
  List<Object?> get props => [
        status,
        documents,
        error,
        asking,
        answer,
        askError,
        expanded,
        extracting,
        suggestions,
        busySuggestions,
      ];
}

/// Drives the Library screen: document list, Q&A, and the extract → review →
/// accept flow. Mirrors the web `features/library` behaviour.
class LibraryCubit extends Cubit<LibraryState> {
  final LifeRepository _repo;
  LibraryCubit(this._repo) : super(const LibraryState());

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final docs = await _repo.documents();
      emit(state.copyWith(status: LoadStatus.ready, documents: docs));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.error, error: e.message));
    }
  }

  Future<void> _reloadDocs() async {
    try {
      final docs = await _repo.documents();
      if (!isClosed) emit(state.copyWith(documents: docs));
    } catch (_) {
      // keep the current list; a transient reload failure isn't worth surfacing
    }
  }

  Future<String?> addDocument({String? title, required String text}) async {
    try {
      await _repo.createDocument(title: title, text: text);
      await _reloadDocs();
      _pollWhilePending(); // fire-and-forget: catch PENDING → READY
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  // Ingestion runs in the background, so re-poll a few times until nothing is
  // still indexing.
  Future<void> _pollWhilePending() async {
    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (isClosed) return;
      if (!state.documents.any((d) => d.isPending)) return;
      await _reloadDocs();
    }
  }

  Future<void> deleteDocument(String id) async {
    try {
      await _repo.deleteDocument(id);
      final expanded = {...state.expanded}..remove(id);
      final suggestions = {...state.suggestions}..remove(id);
      emit(state.copyWith(expanded: expanded, suggestions: suggestions));
      await _reloadDocs();
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> ask(String question, {String? documentId}) async {
    emit(state.copyWith(asking: true, askError: null));
    try {
      final r = await _repo.askLibrary(question, documentId: documentId);
      emit(state.copyWith(asking: false, answer: r));
    } on ApiException catch (e) {
      emit(state.copyWith(asking: false, askError: e.message));
    }
  }

  Future<void> toggleExpand(String docId) async {
    final next = {...state.expanded};
    if (next.contains(docId)) {
      next.remove(docId);
      emit(state.copyWith(expanded: next));
      return;
    }
    next.add(docId);
    emit(state.copyWith(expanded: next));
    if (!state.suggestions.containsKey(docId)) {
      await _loadSuggestions(docId);
    }
  }

  Future<void> _loadSuggestions(String docId) async {
    try {
      final list = await _repo.suggestions(docId);
      if (!isClosed) {
        emit(state.copyWith(suggestions: {...state.suggestions, docId: list}));
      }
    } catch (_) {}
  }

  Future<void> extract(String docId) async {
    emit(state.copyWith(extracting: {...state.extracting, docId}));
    try {
      final list = await _repo.extractActions(docId);
      emit(state.copyWith(
        suggestions: {...state.suggestions, docId: list},
        expanded: {...state.expanded, docId},
        extracting: {...state.extracting}..remove(docId),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        extracting: {...state.extracting}..remove(docId),
        error: e.message,
      ));
    }
  }

  /// Returns an error message on failure (for a snackbar), or null on success.
  Future<String?> accept(
    DocumentSuggestion s, {
    String? areaId,
    String? priority,
  }) async {
    emit(state.copyWith(busySuggestions: {...state.busySuggestions, s.id}));
    try {
      final updated =
          await _repo.acceptSuggestion(s.id, areaId: areaId, priority: priority);
      final list = [...(state.suggestions[s.documentId] ?? const [])];
      final idx = list.indexWhere((x) => x.id == s.id);
      if (idx >= 0) list[idx] = updated;
      emit(state.copyWith(
        suggestions: {...state.suggestions, s.documentId: list},
        busySuggestions: {...state.busySuggestions}..remove(s.id),
      ));
      return null;
    } on ApiException catch (e) {
      emit(state.copyWith(busySuggestions: {...state.busySuggestions}..remove(s.id)));
      return e.message;
    }
  }

  Future<void> dismiss(DocumentSuggestion s) async {
    emit(state.copyWith(busySuggestions: {...state.busySuggestions, s.id}));
    try {
      await _repo.dismissSuggestion(s.id);
      final list = [...(state.suggestions[s.documentId] ?? const [])]
        ..removeWhere((x) => x.id == s.id);
      emit(state.copyWith(
        suggestions: {...state.suggestions, s.documentId: list},
        busySuggestions: {...state.busySuggestions}..remove(s.id),
      ));
    } on ApiException {
      emit(state.copyWith(busySuggestions: {...state.busySuggestions}..remove(s.id)));
    }
  }
}
