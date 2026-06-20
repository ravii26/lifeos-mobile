import 'json.dart';

class CalendarBlock {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String blockType;
  final String? areaId;
  final bool isActual;

  const CalendarBlock({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.blockType,
    this.areaId,
    required this.isActual,
  });

  /// Fractional start hour (e.g. 9.5 = 9:30am) used by the day timeline.
  double get startHour => startTime.hour + startTime.minute / 60;
  double get endHour => endTime.hour + endTime.minute / 60;

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
      );
}
