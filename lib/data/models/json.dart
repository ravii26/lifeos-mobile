/// Small JSON coercion helpers shared by model `fromJson` constructors.
/// The API is consistent, but these guard against nulls / type drift.
typedef Json = Map<String, dynamic>;

String asString(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

String? asStringOrNull(dynamic v) => v?.toString();

int asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// Like [asDouble] but preserves null — used where null is meaningful
/// (e.g. an unclassified capture has `confidence: null`, not 0).
double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<String> asStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}
