import 'json.dart';

/// One "get to know you" question from the server, with its tappable answers.
class KnowQuestion {
  final String id;
  final String text;
  final String why;
  final List<String> options;
  final bool allowText;
  final String? hint;
  const KnowQuestion({required this.id, required this.text, required this.why, this.options = const [], this.allowText = false, this.hint});

  factory KnowQuestion.fromJson(Json j) => KnowQuestion(
        id: asString(j['id']),
        text: asString(j['text']),
        why: asString(j['why']),
        options: ((j['options'] as List?) ?? const []).map((e) => e.toString()).toList(),
        allowText: asBool(j['allowText']),
        hint: asStringOrNull(j['hint']),
      );
}

class KnowCardData {
  final KnowQuestion? question; // null = nothing to ask right now
  final int answered;
  final int total;
  const KnowCardData({this.question, this.answered = 0, this.total = 0});

  factory KnowCardData.fromJson(Json j) => KnowCardData(
        question: j['question'] is Json ? KnowQuestion.fromJson(j['question'] as Json) : null,
        answered: (j['answered'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class KnowReply {
  final String message;
  final bool retry; // the answer could not be read: ask again
  const KnowReply(this.message, {this.retry = false});

  factory KnowReply.fromJson(Json j) => KnowReply(asString(j['message']), retry: asBool(j['retry']));
}
