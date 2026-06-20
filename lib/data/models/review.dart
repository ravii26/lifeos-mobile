import 'json.dart';

class Review {
  final String id;
  final String reviewType;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? summary;
  final List<String> highlights;
  final List<String> improvements;
  final List<ReviewInsight> insights;

  const Review({
    required this.id,
    required this.reviewType,
    this.periodStart,
    this.periodEnd,
    this.summary,
    this.highlights = const [],
    this.improvements = const [],
    this.insights = const [],
  });

  factory Review.fromJson(Json j) => Review(
        id: asString(j['id']),
        reviewType: asString(j['reviewType'], 'WEEKLY'),
        periodStart: asDate(j['periodStart']),
        periodEnd: asDate(j['periodEnd']),
        summary: asStringOrNull(j['summary']),
        highlights: asStringList(j['highlights']),
        improvements: asStringList(j['improvements']),
        insights: (j['insights'] as List?)
                ?.map((e) => ReviewInsight.fromJson(e as Json))
                .toList() ??
            const [],
      );
}

class ReviewInsight {
  final String id;
  final String status; // PENDING | IMPLEMENTED | STILL_WORKING | NOT_APPLICABLE
  final String? userNote;
  final String text;

  const ReviewInsight({
    required this.id,
    required this.status,
    this.userNote,
    required this.text,
  });

  factory ReviewInsight.fromJson(Json j) {
    final note = j['note'] as Map<String, dynamic>?;
    return ReviewInsight(
      id: asString(j['id']),
      status: asString(j['status'], 'PENDING'),
      userNote: asStringOrNull(j['userNote']),
      text: asString(note?['content'] ?? note?['title'] ?? j['text'],
          'Insight'),
    );
  }
}
