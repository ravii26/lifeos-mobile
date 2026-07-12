import 'package:flutter/material.dart';

/// Single source of truth for LifeOS modules.
///
/// Every navigation surface (More sheet, bottom nav, Home cards, capture
/// routing, What-now, Graph) reads this list filtered by the user's
/// `enabledModules` instead of hardcoding its own list. Core modules are
/// structurally load-bearing and cannot be turned off.
enum ModuleId {
  // ---- core (always on) ----
  areas,
  tasks,
  capture,
  // ---- optional ----
  habits,
  goals,
  projects,
  calendar,
  knowledge,
  vault,
  focus,
  review,
  learn,
  library,
  identity,
  behaviour,
  graph,
  decisions,
}

class ModuleDef {
  final ModuleId id;
  final String label;
  final String desc;
  final IconData icon;
  final bool core;

  const ModuleDef(this.id, this.label, this.desc, this.icon, {this.core = false});

  String get key => id.name;
}

class Modules {
  Modules._();

  static const all = <ModuleDef>[
    ModuleDef(ModuleId.areas, 'Areas', 'Life areas & scoring',
        Icons.grid_view_rounded,
        core: true),
    ModuleDef(ModuleId.tasks, 'Tasks', 'To-dos & today', Icons.check_circle,
        core: true),
    ModuleDef(ModuleId.capture, 'Capture', 'Brain-dump inbox', Icons.bolt,
        core: true),
    ModuleDef(ModuleId.habits, 'Habits', 'Recurring habits & reminders',
        Icons.repeat_rounded),
    ModuleDef(ModuleId.goals, 'Goals', "What you're aiming at",
        Icons.flag_outlined),
    ModuleDef(ModuleId.projects, 'Projects', 'Bodies of work in motion',
        Icons.account_tree_outlined),
    ModuleDef(ModuleId.calendar, 'Calendar', 'Time-blocked day',
        Icons.calendar_today_outlined),
    ModuleDef(ModuleId.knowledge, 'Notebooks', 'Topics, notebooks & notes',
        Icons.menu_book_outlined),
    ModuleDef(ModuleId.vault, 'Vault', 'Wins, quotes & protocols',
        Icons.lock_outline),
    ModuleDef(ModuleId.focus, 'Focus', 'Immersive timer',
        Icons.center_focus_strong_outlined),
    ModuleDef(ModuleId.review, 'Weekly Review', 'Reflect & integrate insights',
        Icons.refresh),
    ModuleDef(ModuleId.learn, 'Learn', 'Courses, notes & resources',
        Icons.school_outlined),
    ModuleDef(ModuleId.library, 'Library',
        'Ask & extract from your documents', Icons.auto_stories_outlined),
    ModuleDef(ModuleId.identity, 'Identity', 'Purpose, values & vision',
        Icons.self_improvement),
    // Toggling these three never actually gated their telemetry/fetches, only
    // nav visibility — a false impression of control, so they're always-on
    // until real gating is built.
    ModuleDef(ModuleId.behaviour, 'Behaviour', 'Your activity signals',
        Icons.insights_outlined,
        core: true),
    ModuleDef(ModuleId.graph, 'Graph', 'How everything connects',
        Icons.hub_outlined,
        core: true),
    ModuleDef(ModuleId.decisions, 'What now', 'Your next best move',
        Icons.auto_awesome_outlined,
        core: true),
  ];

  static final _byKey = {for (final m in all) m.key: m};

  static ModuleDef? byKey(String key) => _byKey[key];

  /// Keys of modules that are always on and never shown as toggles.
  static final coreKeys =
      all.where((m) => m.core).map((m) => m.key).toSet();

  /// Keys of the optional (user-toggleable) modules.
  static final optionalKeys =
      all.where((m) => !m.core).map((m) => m.key).toList();

  /// Default enabled set: every optional module on. Represented as the empty
  /// list on the wire (empty == "all optional enabled") so brand-new accounts
  /// and older clients behave identically.
  static const String wireAllOn = '';
}

/// Resolves a raw `enabledModules` list from the backend into the effective
/// set of enabled module keys. An empty list means "all optional modules on".
Set<String> resolveEnabled(List<String> raw) {
  final enabled = <String>{...Modules.coreKeys};
  if (raw.isEmpty) {
    enabled.addAll(Modules.optionalKeys);
  } else {
    enabled.addAll(raw.where(Modules.optionalKeys.contains));
  }
  return enabled;
}
