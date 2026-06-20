import 'json.dart';

class CalendarBlock {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String blockType;
  final String? areaId;
  final bool isActual;
  final String? notes;

  // Recurrence
  final String? recurrenceRule;
  final bool isRecurring;
  // Set only on virtual occurrences expanded from a recurring template.
  // [recurringBlockId] = the template's id; [occurrenceDate] = the original
  // (pre-override) start instant — the key used to edit/skip one occurrence.
  final String? recurringBlockId;
  final DateTime? occurrenceDate;

  const CalendarBlock({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.blockType,
    this.areaId,
    required this.isActual,
    this.notes,
    this.recurrenceRule,
    this.isRecurring = false,
    this.recurringBlockId,
    this.occurrenceDate,
  });

  /// Fractional start hour (e.g. 9.5 = 9:30am) used by the day timeline.
  double get startHour => startTime.hour + startTime.minute / 60;
  double get endHour => endTime.hour + endTime.minute / 60;

  /// True when this is one instance expanded from a recurring template.
  bool get isOccurrence => recurringBlockId != null && occurrenceDate != null;

  /// The id of the underlying series template (itself if not an occurrence).
  String get seriesId => recurringBlockId ?? id;

  factory CalendarBlock.fromJson(Json j) => CalendarBlock(
        id: asString(j['id']),
        title: asString(j['title']),
        startTime: asDate(j['startTime']) ?? DateTime.now(),
        endTime: asDate(j['endTime']) ??
            (asDate(j['startTime']) ?? DateTime.now())
                .add(const Duration(hours: 1)),
        blockType: asString(j['blockType'], 'FOCUS'),
        areaId: asStringOrNull(j['areaId']),
        isActual: asBool(j['isActual']),
        notes: asStringOrNull(j['notes']),
        recurrenceRule: asStringOrNull(j['recurrenceRule']),
        isRecurring: asBool(j['isRecurring']),
        recurringBlockId: asStringOrNull(j['recurringBlockId']),
        occurrenceDate: asDate(j['occurrenceDate']),
      );
}
