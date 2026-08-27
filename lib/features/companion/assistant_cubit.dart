import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';

enum ChatRole { user, assistant }

class ChatTurn extends Equatable {
  final ChatRole role;
  final String text;
  const ChatTurn(this.role, this.text);

  @override
  List<Object?> get props => [role, text];
}

class AssistantState extends Equatable {
  final List<ChatTurn> turns;
  final bool loading;

  const AssistantState({this.turns = const [], this.loading = false});

  AssistantState copyWith({List<ChatTurn>? turns, bool? loading}) =>
      AssistantState(turns: turns ?? this.turns, loading: loading ?? this.loading);

  @override
  List<Object?> get props => [turns, loading];
}

/// Phase 1 rough pass: no persisted history — each sheet open starts a fresh
/// conversation, mirroring the web overlay's stateless design. Mirrors
/// [DecisionsCubit]'s shape/pattern for consistency with the rest of the app.
class AssistantCubit extends Cubit<AssistantState> {
  final LifeRepository _repo;
  AssistantCubit(this._repo) : super(const AssistantState());

  Future<void> send(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || state.loading) return;
    
    final history = state.turns.map((turn) => {
      'role': turn.role == ChatRole.user ? 'user' : 'assistant',
      'text': turn.text,
    }).toList();

    emit(state.copyWith(
      turns: [...state.turns, ChatTurn(ChatRole.user, trimmed)],
      loading: true,
    ));
    try {
      final answer = await _repo.assistantAsk(trimmed, history);
      emit(state.copyWith(
        turns: [...state.turns, ChatTurn(ChatRole.assistant, answer)],
        loading: false,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        turns: [...state.turns, ChatTurn(ChatRole.assistant, "Couldn't reach the assistant: ${e.message}")],
        loading: false,
      ));
    }
  }
}
