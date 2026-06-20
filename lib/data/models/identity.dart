import 'json.dart';

/// One record per user (GET/PUT /identity). All fields optional — filled in
/// gradually. PUT upserts the whole thing.
class Identity {
  final String? personality;
  final List<String> values;
  final List<String> strengths;
  final List<String> weaknesses;
  final String? purpose;
  final String? thisYearGoal;
  final String? bigPicture;
  final String? lifeVision;

  const Identity({
    this.personality,
    this.values = const [],
    this.strengths = const [],
    this.weaknesses = const [],
    this.purpose,
    this.thisYearGoal,
    this.bigPicture,
    this.lifeVision,
  });

  static const empty = Identity();

  bool get isEmpty =>
      (personality?.isEmpty ?? true) &&
      values.isEmpty &&
      strengths.isEmpty &&
      weaknesses.isEmpty &&
      (purpose?.isEmpty ?? true) &&
      (thisYearGoal?.isEmpty ?? true) &&
      (bigPicture?.isEmpty ?? true) &&
      (lifeVision?.isEmpty ?? true);

  factory Identity.fromJson(Json? j) {
    if (j == null) return empty;
    return Identity(
      personality: asStringOrNull(j['personality']),
      values: asStringList(j['values']),
      strengths: asStringList(j['strengths']),
      weaknesses: asStringList(j['weaknesses']),
      purpose: asStringOrNull(j['purpose']),
      thisYearGoal: asStringOrNull(j['thisYearGoal']),
      bigPicture: asStringOrNull(j['bigPicture']),
      lifeVision: asStringOrNull(j['lifeVision']),
    );
  }
}
