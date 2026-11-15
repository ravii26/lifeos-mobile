import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/chat.dart';

/// How each thing Ally did in chat is said: one icon and one line. Shared by
/// the old chat and the new Talk.

String repeatLabel(String rule) {
  const days = {'MO': 'Mon', 'TU': 'Tue', 'WE': 'Wed', 'TH': 'Thu', 'FR': 'Fri', 'SA': 'Sat', 'SU': 'Sun'};
  final parts = {for (final p in rule.split(';')) p.split('=').first: p.contains('=') ? p.split('=').last : ''};
  switch (parts['FREQ']) {
    case 'DAILY':
      return 'every day';
    case 'MONTHLY':
      return 'every month';
    case 'WEEKLY':
      final d = (parts['BYDAY'] ?? '').split(',').where((x) => x.isNotEmpty).map((x) => days[x] ?? x);
      return d.isEmpty ? 'every week' : 'every ${d.join(', ')}';
  }
  return 'repeats';
}

/// (icon, one-line description) of something Ally did.
(IconData, String) describeAction(ChatAction a) {
  String time(DateTime t) => DateFormat('h:mm a').format(t);
  return switch (a.type) {
    'TASK_ADDED' => (Icons.add_task_rounded, 'To-do: ${a.text}'),
    'REMEMBERED' => (Icons.bookmark_add_outlined, 'Remembered: ${a.text}'),
    'FORGOT' => (Icons.bookmark_remove_outlined, 'Forgot: ${a.text}'),
    'NUDGE_SET' => (
        Icons.notifications_active_outlined,
        a.time == null
            ? '${a.kind == 'MORNING' ? 'Morning heads-up' : 'Nightly nudge'} turned off'
            : '${a.kind == 'MORNING' ? 'Morning heads-up' : 'Nightly nudge'} at ${a.time}'
      ),
    'TASK_COMPLETED' => (Icons.check_circle_rounded, 'Completed: ${a.text}'),
    'HABIT_LOGGED' => (Icons.check_circle_rounded, 'Logged: ${a.text}'),
    'HABIT_ADDED' => (
        Icons.repeat_rounded,
        'Habit: ${a.text}${a.detail == null ? '' : ' (${a.detail!.toLowerCase()})'}'
      ),
    'PROJECT_ADDED' => (
        Icons.flag_outlined,
        'Project: ${a.text}'
            '${a.tasks > 0 ? ' · ${a.tasks} to-do${a.tasks == 1 ? '' : 's'}' : ''}'
            '${a.detail == null ? '' : ' · due ${DateFormat('EEE d MMM').format(DateTime.parse(a.detail!))}'}'
      ),
    'NOTE_ADDED' => (
        Icons.sticky_note_2_outlined,
        'Note ${a.text}${a.items.isEmpty ? '' : ': ${a.items.join(', ')}'}'
      ),
    'REMINDER_SET' => (
        Icons.alarm_rounded,
        'Reminder ${a.remindAt == null ? '' : DateFormat('EEE d MMM').format(a.remindAt!)} '
            '${a.remindAt == null ? '' : time(a.remindAt!)}'
            '${a.windowEnd == null ? '' : ' to ${time(a.windowEnd!)}'}'
            '${a.repeatRule == null ? '' : ', ${repeatLabel(a.repeatRule!)}'}: ${a.text}'
      ),
    'MODE_SET' => (
        Icons.bedtime_outlined,
        switch (a.kind) {
          'SICK' => 'Sick mode on',
          'BUSY' => 'Busy mode on${a.detail == null ? '' : ' until ${a.detail}'}',
          'TRAVEL' => 'Travel mode on',
          'HOLIDAY' => 'Holiday mode on',
          _ => 'Back to normal',
        }
      ),
    'NOTE_UPDATED' => (Icons.sticky_note_2_outlined, 'Updated note: ${a.text}'),
    'PROGRESS_LOGGED' => (Icons.trending_up_rounded, 'Logged: ${a.detail ?? a.text}'),
    'LOG_ADDED' => (Icons.edit_note_rounded, a.text),
    'CONTACT' => (a.kind == 'CALL' ? Icons.call_outlined : Icons.chat_outlined, a.text),
    'LIMIT_SET' => (Icons.speed_rounded, a.text),
    'LIMIT_USED' => (Icons.timelapse_rounded, a.detail ?? a.text),
    'TIMER_STARTED' => (Icons.timer_outlined, a.text),
    'TIMER_STOPPED' => (Icons.stop_circle_outlined, a.text),
    'COUNT_ADDED' => (Icons.add_circle_outline_rounded, '${a.text}: ${a.detail ?? ''}'),
    'BUSY_SET' => (
        Icons.event_busy_outlined,
        a.detail == null ? 'Free again' : 'Busy until ${time(DateTime.parse(a.detail!).toLocal())}: nothing from me till then'
      ),
    'PROJECT_STATUS' => (
        Icons.flag_outlined,
        switch (a.kind) {
          'PAUSED' => '${a.text} paused',
          'ABANDONED' => '${a.text} let go',
          'COMPLETED' => '${a.text} finished',
          _ => '${a.text} back on',
        }
      ),
    'SCHEDULE_SET' => (Icons.schedule_rounded, 'Day updated for ${a.items.join(', ')}'),
    'PREFERENCE_SET' => (Icons.tune_rounded, a.text),
    'LOW_ENERGY' => (Icons.bedtime_outlined, a.kind == 'ON' ? 'Low energy today: on' : 'Low energy today: off'),
    'ITEM_REMOVED' => (Icons.archive_outlined, '${a.text}: ${a.detail ?? 'removed'}'),
    'ITEM_UPDATED' => (Icons.edit_calendar_outlined, '${a.text}: ${a.detail ?? 'updated'}'),
    'UNDONE' => (Icons.undo_rounded, 'Undone: ${a.text}'),
    _ => (Icons.bolt_rounded, a.text),
  };
}

