import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_exception.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/life_repository.dart';

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final bool sending;
  final String? error;
  // Set when the assistant hands off to the save → action flow.
  final String? openSave;

  const ChatState({
    this.messages = const [],
    this.sending = false,
    this.error,
    this.openSave,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
    String? openSave,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        error: error,
        openSave: openSave,
      );

  @override
  List<Object?> get props => [messages, sending, error, openSave];
}

/// One chat that also acts. History lives on this device (last 60 messages)
/// and the last 10 go to the server for context.
class ChatCubit extends Cubit<ChatState> {
  final LifeRepository _repo;
  static const _prefsKey = 'chat_history_v1';
  static const _keep = 60;

  ChatCubit(this._repo) : super(const ChatState()) {
    _restore();
    _syncReminders();
  }

  Future<void> _restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
      emit(state.copyWith(messages: list));
    } catch (_) {
      // a corrupt history just starts fresh
    }
  }

  Future<void> _persist(List<ChatMessage> list) async {
    try {
      final keep = list.length > _keep ? list.sublist(list.length - _keep) : list;
      await (await SharedPreferences.getInstance())
          .setString(_prefsKey, jsonEncode([for (final m in keep) m.toJson()]));
    } catch (_) {}
  }

  // Reminders set on another device, or before a reinstall, still fire here.
  Future<void> _syncReminders() async {
    try {
      await NotificationService.instance.syncReminders(await _repo.reminders());
    } catch (_) {}
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;
    final history = state.messages;
    final withUser = [...history, ChatMessage(fromUser: true, text: message)];
    emit(state.copyWith(messages: withUser, sending: true));
    try {
      final reply = await _repo.chat(message, history);
      for (final a in reply.actions) {
        if (a.type == 'REMINDER_SET' && a.id != null && a.remindAt != null) {
          await NotificationService.instance.scheduleReminder(a.id!, a.text, a.remindAt!);
        } else if (a.type == 'NUDGE_SET') {
          // The Tonight screen reloads after any action and reschedules from these.
          a.kind == 'MORNING'
              ? await NotificationService.instance.setMorningTime(a.time)
              : await NotificationService.instance.setNightlyTime(a.time);
        }
      }
      final save = reply.actions.where((a) => a.type == 'OPEN_SAVE').firstOrNull;
      final list = [
        ...withUser,
        ChatMessage(
          fromUser: false,
          text: reply.reply,
          role: reply.role,
          actions: reply.actions.where((a) => a.type != 'OPEN_SAVE').toList(),
        ),
      ];
      emit(state.copyWith(messages: list, sending: false, openSave: save?.text));
      await _persist(list);
    } on ApiException catch (e) {
      if (e.statusCode == null) {
        // Offline or the server is waking: keep the message and send it later.
        _pending.add(message);
        final list = [
          ...withUser,
          const ChatMessage(fromUser: false, text: "You're offline right now. I'll answer this as soon as you're back."),
        ];
        emit(state.copyWith(messages: list, sending: false));
        await _persist(list);
        return;
      }
      emit(state.copyWith(sending: false, error: e.message));
    }
  }

  final List<String> _pending = [];

  /// Sends messages written while offline (called when the app comes back).
  Future<void> retryPending() async {
    while (_pending.isNotEmpty && !state.sending) {
      final next = _pending.removeAt(0);
      // Drop the "you're offline" placeholder and the duplicate user line.
      final msgs = [...state.messages];
      final i = msgs.lastIndexWhere((m) => m.fromUser && m.text == next);
      if (i >= 0) {
        msgs.removeAt(i);
        if (i < msgs.length && !msgs[i].fromUser && msgs[i].text.startsWith("You're offline")) msgs.removeAt(i);
      }
      emit(state.copyWith(messages: msgs));
      await send(next);
    }
  }

  /// Undo one thing Ally did (a task, reminder, memory, nudge…).
  Future<void> undoAction(int messageIndex, int actionIndex) async {
    final m = state.messages[messageIndex];
    final a = m.actions[actionIndex];
    if (a.activityId == null || a.undone) return;
    try {
      await _repo.undo(a.activityId!);
      if (a.type == 'REMINDER_SET' && a.id != null) {
        await NotificationService.instance.cancelReminder(a.id!);
      }
      final actions = [...m.actions]..[actionIndex] = a.markUndone();
      final msgs = [...state.messages]
        ..[messageIndex] = ChatMessage(fromUser: m.fromUser, text: m.text, actions: actions, role: m.role);
      emit(state.copyWith(messages: msgs));
      await _persist(msgs);
    } on ApiException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  void saveHandled() => emit(state.copyWith());

  Future<void> clear() async {
    emit(const ChatState());
    await _persist(const []);
  }
}
