import 'json.dart';

class UserSettings {
  final String vibe; // calm | focused | energetic
  final String accent; // hex #rrggbb
  final String font; // inter | mono | serif
  final String startTab; // today | areas | dump

  const UserSettings({
    this.vibe = 'focused',
    this.accent = '#c5f23f',
    this.font = 'inter',
    this.startTab = 'today',
  });

  UserSettings copyWith(
          {String? vibe, String? accent, String? font, String? startTab}) =>
      UserSettings(
        vibe: vibe ?? this.vibe,
        accent: accent ?? this.accent,
        font: font ?? this.font,
        startTab: startTab ?? this.startTab,
      );

  factory UserSettings.fromJson(Json j) => UserSettings(
        vibe: asString(j['vibe'], 'focused'),
        accent: asString(j['accent'], '#c5f23f'),
        font: asString(j['font'], 'inter'),
        startTab: asString(j['startTab'], 'today'),
      );
}
