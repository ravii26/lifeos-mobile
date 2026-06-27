import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/modules/module_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/life_repository.dart';

class AppearanceState extends Equatable {
  final AppAccent accent;
  final String font; // inter | mono | serif
  final String vibe; // calm | focused | energetic
  final bool light; // theme mode
  final String density; // compact | cozy | comfy

  /// Raw optional-module keys enabled by the user. Empty == all optional on.
  final List<String> rawModules;

  const AppearanceState({
    this.accent = AppAccent.chartreuse,
    this.font = 'inter',
    this.vibe = 'focused',
    this.light = false,
    this.density = 'comfy',
    this.rawModules = const [],
  });

  /// Effective set of enabled module keys (core modules always included).
  Set<String> get enabled => resolveEnabled(rawModules);

  bool isEnabled(ModuleId id) => enabled.contains(id.name);

  /// Text scale multiplier applied app-wide for the density setting.
  double get textScale => switch (density) {
        'compact' => 0.9,
        'cozy' => 0.97,
        _ => 1.05,
      };

  AppearanceState copyWith({
    AppAccent? accent,
    String? font,
    String? vibe,
    bool? light,
    String? density,
    List<String>? rawModules,
  }) =>
      AppearanceState(
        accent: accent ?? this.accent,
        font: font ?? this.font,
        vibe: vibe ?? this.vibe,
        light: light ?? this.light,
        density: density ?? this.density,
        rawModules: rawModules ?? this.rawModules,
      );

  @override
  List<Object?> get props =>
      [accent, font, vibe, light, density, rawModules];
}

/// Holds appearance prefs. Accent/font/vibe persist to the backend /settings;
/// theme mode + density are device-local (no backend field) via secure storage.
/// Accent + mode drive the live [AppColors] palette and the MaterialApp theme.
class AppearanceCubit extends Cubit<AppearanceState> {
  final LifeRepository _repo;
  final _local = const FlutterSecureStorage();

  AppearanceCubit(this._repo) : super(const AppearanceState());

  static const _kMode = 'pref_theme_mode';
  static const _kDensity = 'pref_density';

  Future<void> load() async {
    var next = const AppearanceState();
    // device-local prefs first (so the UI is correct even if offline)
    try {
      final mode = await _local.read(key: _kMode);
      final density = await _local.read(key: _kDensity);
      next = next.copyWith(
        light: mode == 'light',
        density: density ?? 'comfy',
      );
    } catch (_) {}
    // backend-backed prefs
    try {
      final s = await _repo.settings();
      next = next.copyWith(
        accent: AppAccent.fromHex(s.accent),
        font: s.font,
        vibe: s.vibe,
        rawModules: s.enabledModules,
      );
    } catch (_) {}
    _emit(next);
  }

  /// Toggle an optional module on/off and persist the new set to the backend.
  /// Core modules are never toggled.
  Future<void> toggleModule(String key, bool on) async {
    if (Modules.coreKeys.contains(key)) return;
    // Materialize the current effective optional set, then add/remove.
    final current = {
      ...state.enabled.where(Modules.optionalKeys.contains),
    };
    if (on) {
      current.add(key);
    } else {
      current.remove(key);
    }
    // Persist in registry order for stable, readable payloads.
    final next = Modules.optionalKeys.where(current.contains).toList();
    emit(state.copyWith(rawModules: next));
    _save(() => _repo.updateSettings(enabledModules: next));
  }

  Future<void> setAccent(AppAccent accent) async {
    _emit(state.copyWith(accent: accent));
    final hex = '#${accent.color.toARGB32().toRadixString(16).substring(2)}';
    _save(() => _repo.updateSettings(accent: hex));
  }

  Future<void> setFont(String font) async {
    _emit(state.copyWith(font: font));
    _save(() => _repo.updateSettings(font: font));
  }

  Future<void> setVibe(String vibe) async {
    _emit(state.copyWith(vibe: vibe));
    _save(() => _repo.updateSettings(vibe: vibe));
  }

  Future<void> setLight(bool light) async {
    _emit(state.copyWith(light: light));
    _save(() => _local.write(key: _kMode, value: light ? 'light' : 'dark'));
  }

  Future<void> setDensity(String density) async {
    _emit(state.copyWith(density: density));
    _save(() => _local.write(key: _kDensity, value: density));
  }

  /// Applies the palette for the current state, then emits so the tree rebuilds.
  void _emit(AppearanceState s) {
    AppColors.apply(light: s.light, accent: s.accent);
    emit(s);
  }

  Future<void> _save(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {}
  }
}
