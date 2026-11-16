import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/json.dart';

/// GOAL | TASK | HABIT, said plainly.
String kindLabel(String kind) => switch (kind) {
      'GOAL' => 'Goal',
      'HABIT' => 'Routine',
      _ => 'To-do',
    };

class FrItem {
  String title;
  String kind;
  String areaName;

  /// A day (YYYY-MM-DD): a goal's deadline; for a to-do, on or by that day.
  String? due;

  /// For a to-do: ON | BY, and the hours of the day ("HH:MM").
  String? dueKind;
  String? windowFrom;
  String? windowTo;

  /// SAID = the person's own words ([said] is the part of the text it came
  /// from); IDEA = Ally's suggestion ([ideaFor] is what of theirs it is for,
  /// [reason] why it helps).
  final String origin;
  final String? said;
  final String? ideaFor;
  final String? reason;

  /// Kept? An idea can be unticked; it is then not set up.
  bool on;

  FrItem(this.title, this.kind, this.areaName,
      {this.due, this.dueKind, this.windowFrom, this.windowTo, this.origin = 'SAID', this.said, this.ideaFor, this.reason, this.on = true});

  bool get isIdea => origin == 'IDEA';

  factory FrItem.fromJson(Json j) => FrItem(
        asString(j['title']),
        asString(j['kind'], 'TASK'),
        asString(j['areaName'], 'Other'),
        due: asStringOrNull(j['due']),
        dueKind: asStringOrNull(j['dueKind']),
        windowFrom: asStringOrNull(j['windowFrom']),
        windowTo: asStringOrNull(j['windowTo']),
        origin: asString(j['origin'], 'SAID'),
        said: asStringOrNull(j['said']),
        ideaFor: asStringOrNull(j['ideaFor']),
        reason: asStringOrNull(j['reason']),
        on: j['on'] == null ? true : asBool(j['on']),
      );

  /// For the phone's copy of the draft.
  Json toJson() => {...toApply(), 'origin': origin, 'said': said, 'ideaFor': ideaFor, 'reason': reason, 'on': on};

  /// What is set up. "When" belongs to to-dos; it is sent only when there is one,
  /// so a server from before it existed is never asked about it.
  Json toApply() => {
        'title': title,
        'kind': kind,
        'areaName': areaName,
        'due': due,
        if (kind == 'TASK' && due != null && dueKind != null) 'dueKind': dueKind,
        if (kind == 'TASK' && windowFrom != null && windowTo != null) ...{'windowFrom': windowFrom, 'windowTo': windowTo},
      };
}

class FrArea {
  String name;
  String mode; // PUSH | MAINTAIN | EXPLORE | REST
  String reason;
  FrArea(this.name, this.mode, this.reason);

  factory FrArea.fromJson(Json j) => FrArea(asString(j['name']), asString(j['mode'], 'MAINTAIN'), asString(j['reason']));
  Json toJson() => {'name': name, 'mode': mode, 'reason': reason};
}

/// Where someone is in first run, kept on the phone so leaving midway loses nothing.
class FirstRunDraft {
  int step; // 0 what, 1 heard, 2 week, 3 modes, 4 plan, 5 save
  String text;
  List<FrItem> items;
  List<FrArea> areas;
  bool byCode;

  /// The answer from applying (areas with ids, goals), once applied.
  Json? applied;
  int freeMinutes;

  FirstRunDraft({this.step = 0, this.text = '', List<FrItem>? items, List<FrArea>? areas, this.byCode = false, this.applied, this.freeMinutes = 0})
      : items = items ?? [],
        areas = areas ?? [];

  static const _key = 'first_run_draft_v1';
  static String doneKey(String userId) => 'first_run_done_$userId';

  Json toJson() => {
        'step': step,
        'text': text,
        'items': [for (final i in items) i.toJson()],
        'areas': [for (final a in areas) a.toJson()],
        'byCode': byCode,
        'applied': applied,
        'freeMinutes': freeMinutes,
      };

  factory FirstRunDraft.fromJson(Json j) => FirstRunDraft(
        step: asInt(j['step']).clamp(0, 5),
        text: asString(j['text']),
        items: ((j['items'] as List?) ?? const []).whereType<Json>().map(FrItem.fromJson).toList(),
        areas: ((j['areas'] as List?) ?? const []).whereType<Json>().map(FrArea.fromJson).toList(),
        byCode: asBool(j['byCode']),
        applied: j['applied'] is Json ? j['applied'] as Json : null,
        freeMinutes: asInt(j['freeMinutes']),
      );

  static Future<FirstRunDraft> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) return FirstRunDraft.fromJson(jsonDecode(raw) as Json);
    } catch (_) {}
    return FirstRunDraft();
  }

  Future<void> save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }

  /// Takes the server's sort: items, and a mode for each area.
  void takeSort(Json j) {
    items = ((j['items'] as List?) ?? const []).whereType<Json>().map(FrItem.fromJson).toList();
    areas = ((j['areas'] as List?) ?? const []).whereType<Json>().map(FrArea.fromJson).toList();
    byCode = asBool(j['byCode']);
    tidyAreas();
  }

  /// Every item's area is in the list, and no area is left empty.
  void tidyAreas() {
    for (final i in items) {
      if (!areas.any((a) => a.name == i.areaName)) areas.add(FrArea(i.areaName, 'MAINTAIN', 'Kept steady with a small, regular dose.'));
    }
    areas.removeWhere((a) => !items.any((i) => i.areaName == a.name));
  }

  /// What will be set up: everything except ideas that were unticked.
  List<FrItem> get kept => [for (final i in items) if (i.on) i];

  void renameArea(String from, String to) {
    final name = to.trim();
    if (name.isEmpty || name == from) return;
    final into = areas.where((a) => a.name == name).firstOrNull;
    for (final i in items) {
      if (i.areaName == from) i.areaName = name;
    }
    if (into == null) {
      for (final a in areas) {
        if (a.name == from) a.name = name;
      }
    }
    tidyAreas();
  }

  void moveItem(FrItem item, String areaName) {
    final to = areaName.trim();
    final from = areas.where((a) => a.name == item.areaName).firstOrNull;
    final alone = items.where((i) => i.areaName == item.areaName).length == 1;
    // Moving an area's only item to a new area is a rename: it keeps the mode.
    if (from != null && alone && !areas.any((a) => a.name == to)) areas.add(FrArea(to, from.mode, from.reason));
    item.areaName = to;
    tidyAreas();
  }

  void removeItem(FrItem item) {
    items.remove(item);
    tidyAreas();
  }
}

/// A week's starting time for a mode, in minutes (the same rule as the server).
int startingMinutes(String mode) => mode == 'PUSH' ? 180 : (mode == 'REST' ? 0 : 60);

int neededMinutes(List<FrArea> areas) => areas.fold(0, (s, a) => s + startingMinutes(a.mode));

/// Push is for at most two areas at once.
const maxPush = 2;

/// Work days, hours, wake and sleep, as tap choices.
const workDayChoices = <(String, List<int>)>[
  ('Mon to Fri', [1, 2, 3, 4, 5]),
  ('Mon to Sat', [1, 2, 3, 4, 5, 6]),
  ('No fixed work days', []),
];
const workHourChoices = <(String, String?, String?)>[
  ('9 to 6', '09:00', '18:00'),
  ('10 to 7', '10:00', '19:00'),
  ('9 to 7', '09:00', '19:00'),
  ('It varies', null, null),
];
const wakeChoices = <(String, String)>[('6 am', '06:00'), ('7 am', '07:00'), ('8 am', '08:00')];
const sleepChoices = <(String, String)>[('10 pm', '22:00'), ('11 pm', '23:00'), ('11:30 pm', '23:30')];
