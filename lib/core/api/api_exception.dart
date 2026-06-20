/// A normalized error surfaced from the LifeOS API or transport layer.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final List<String> errors;

  const ApiException(this.message, {this.statusCode, this.errors = const []});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
