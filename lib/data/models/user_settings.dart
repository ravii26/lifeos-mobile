import 'json.dart';

class UserSettings {
  final String vibe; // calm | focused | energetic
  final String accent; // hex #rrggbb
  final String font; // inter | mono | serif
  final String startTab; // today | areas | dump
  final List<String> enabledModules; // optional-module keys; [] == all on

  const UserSettings({
    this.vibe = 'focused',
    this.accent = '#c5f23f',
    this.font = 'inter',
    this.startTab = 'today',
    this.enabledModules = const [],
  });

  UserSettings copyWith(
          {String? vibe,
          String? accent,
          String? font,
          String? startTab,
          List<String>? enabledModules}) =>
      UserSettings(
        vibe: vibe ?? this.vibe,
        accent: accent ?? this.accent,
        font: font ?? this.font,
        startTab: startTab ?? this.startTab,
        enabledModules: enabledModules ?? this.enabledModules,
      );

  factory UserSettings.fromJson(Json j) => UserSettings(
        vibe: asString(j['vibe'], 'focused'),
        accent: asString(j['accent'], '#c5f23f'),
        font: asString(j['font'], 'inter'),
        startTab: asString(j['startTab'], 'today'),
        enabledModules: (j['enabledModules'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
