import 'json.dart';

/// A life Area the AI proposed from the user's own words, not yet created.
class OnboardingArea {
  final String name;
  final String type; // PRIMARY | MAINTENANCE
  final String icon;
  final String color;

  const OnboardingArea({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });

  factory OnboardingArea.fromJson(Json j) => OnboardingArea(
        name: asString(j['name']),
        type: asString(j['type'], 'PRIMARY'),
        icon: asString(j['icon'], 'target'),
        color: asString(j['color'], '#c5f23f'),
      );
}

/// A proposed starter Goal/Habit/Task, tagged to one of the proposed
/// (or existing) area names above — not yet created.
class OnboardingAction {
  final String itemType; // GOAL | HABIT | TASK
  final String title;
  final String? detail;
  final String areaName;
  final String? frequency;
  final int? targetMinutes;
  final String? priority;
  final String? dueDate;

  const OnboardingAction({
    required this.itemType,
    required this.title,
    this.detail,
    required this.areaName,
    this.frequency,
    this.targetMinutes,
    this.priority,
    this.dueDate,
  });

  factory OnboardingAction.fromJson(Json j) => OnboardingAction(
        itemType: asString(j['itemType'], 'TASK'),
        title: asString(j['title']),
        detail: asStringOrNull(j['detail']),
        areaName: asString(j['areaName']),
        frequency: asStringOrNull(j['frequency']),
        targetMinutes: j['targetMinutes'] == null ? null : asInt(j['targetMinutes']),
        priority: asStringOrNull(j['priority']),
        dueDate: asStringOrNull(j['dueDate']),
      );
}

/// The result of `POST /onboarding/extract` — a proposed starter setup the
/// user reviews before anything is actually created.
class OnboardingExtraction {
  final List<OnboardingArea> areas;
  final List<OnboardingAction> actions;

  const OnboardingExtraction({this.areas = const [], this.actions = const []});

  factory OnboardingExtraction.fromJson(Json j) => OnboardingExtraction(
        areas: (j['areas'] as List? ?? const [])
            .map((e) => OnboardingArea.fromJson(Json.from(e as Map)))
            .toList(),
        actions: (j['actions'] as List? ?? const [])
            .map((e) => OnboardingAction.fromJson(Json.from(e as Map)))
            .toList(),
      );
}
