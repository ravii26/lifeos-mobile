import 'dart:convert';

/// What the home-screen widget renders. Kept small and pre-rendered (rather
/// than raw API models) so both the Android Glance widget and the iOS
/// WidgetKit timeline provider can read one flat JSON blob without knowing
/// anything about the LifeOS API shape.
class WidgetSnapshot {
  final DateTime updatedAt;
  final bool focusActive;
  final String? focusLabel;
  final DateTime? focusStartedAt;
  final String? nextActionType; // TASK | HABIT | GOAL | AREA_FOCUS | REVIEW
  final String? nextActionRefId;
  final String? nextActionTitle;
  final List<WidgetHabit> habits;

  /// ARGB32 ints (same packing as Flutter's `Color.toARGB32()` and Android's
  /// `Color` int constructor) so both native widgets render the app's actual
  /// live theme instead of a hardcoded guess. Defaults match AppColors' dark
  /// palette + default chartreuse accent for the pre-first-sync cold start.
  final int bgColor;
  final int textColor;
  final int mutedTextColor;
  final int accentColor;
  final int accentInkColor;

  const WidgetSnapshot({
    required this.updatedAt,
    this.focusActive = false,
    this.focusLabel,
    this.focusStartedAt,
    this.nextActionType,
    this.nextActionRefId,
    this.nextActionTitle,
    this.habits = const [],
    this.bgColor = 0xFF0A0B0D,
    this.textColor = 0xFFECEEF0,
    this.mutedTextColor = 0xFFA6ABB3,
    this.accentColor = 0xFFC5F23F,
    this.accentInkColor = 0xFF11160A,
  });

  factory WidgetSnapshot.empty() =>
      WidgetSnapshot(updatedAt: DateTime.fromMillisecondsSinceEpoch(0));

  WidgetSnapshot copyWith({
    DateTime? updatedAt,
    bool? focusActive,
    Object? focusLabel = _unset,
    Object? focusStartedAt = _unset,
    Object? nextActionType = _unset,
    Object? nextActionRefId = _unset,
    Object? nextActionTitle = _unset,
    List<WidgetHabit>? habits,
    int? bgColor,
    int? textColor,
    int? mutedTextColor,
    int? accentColor,
    int? accentInkColor,
  }) =>
      WidgetSnapshot(
        updatedAt: updatedAt ?? this.updatedAt,
        focusActive: focusActive ?? this.focusActive,
        focusLabel:
            identical(focusLabel, _unset) ? this.focusLabel : focusLabel as String?,
        focusStartedAt: identical(focusStartedAt, _unset)
            ? this.focusStartedAt
            : focusStartedAt as DateTime?,
        nextActionType: identical(nextActionType, _unset)
            ? this.nextActionType
            : nextActionType as String?,
        nextActionRefId: identical(nextActionRefId, _unset)
            ? this.nextActionRefId
            : nextActionRefId as String?,
        nextActionTitle: identical(nextActionTitle, _unset)
            ? this.nextActionTitle
            : nextActionTitle as String?,
        habits: habits ?? this.habits,
        bgColor: bgColor ?? this.bgColor,
        textColor: textColor ?? this.textColor,
        mutedTextColor: mutedTextColor ?? this.mutedTextColor,
        accentColor: accentColor ?? this.accentColor,
        accentInkColor: accentInkColor ?? this.accentInkColor,
      );

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt.toIso8601String(),
        'focusActive': focusActive,
        'focusLabel': focusLabel,
        'focusStartedAt': focusStartedAt?.toIso8601String(),
        'nextActionType': nextActionType,
        'nextActionRefId': nextActionRefId,
        'nextActionTitle': nextActionTitle,
        'habits': habits.map((h) => h.toJson()).toList(),
        'bgColor': bgColor,
        'textColor': textColor,
        'mutedTextColor': mutedTextColor,
        'accentColor': accentColor,
        'accentInkColor': accentInkColor,
      };

  factory WidgetSnapshot.fromJson(Map<String, dynamic> j) => WidgetSnapshot(
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        focusActive: j['focusActive'] as bool? ?? false,
        focusLabel: j['focusLabel'] as String?,
        focusStartedAt: j['focusStartedAt'] == null
            ? null
            : DateTime.parse(j['focusStartedAt'] as String),
        nextActionType: j['nextActionType'] as String?,
        nextActionRefId: j['nextActionRefId'] as String?,
        nextActionTitle: j['nextActionTitle'] as String?,
        habits: (j['habits'] as List? ?? const [])
            .map((e) => WidgetHabit.fromJson(e as Map<String, dynamic>))
            .toList(),
        bgColor: j['bgColor'] as int? ?? 0xFF0A0B0D,
        textColor: j['textColor'] as int? ?? 0xFFECEEF0,
        mutedTextColor: j['mutedTextColor'] as int? ?? 0xFFA6ABB3,
        accentColor: j['accentColor'] as int? ?? 0xFFC5F23F,
        accentInkColor: j['accentInkColor'] as int? ?? 0xFF11160A,
      );

  String encode() => jsonEncode(toJson());

  static WidgetSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return WidgetSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

const _unset = Object();

class WidgetHabit {
  final String id;
  final String title;
  final bool done;

  const WidgetHabit({required this.id, required this.title, required this.done});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory WidgetHabit.fromJson(Map<String, dynamic> j) => WidgetHabit(
        id: j['id'] as String,
        title: j['title'] as String,
        done: j['done'] as bool? ?? false,
      );
}
