import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';

void main() {
  group('ApiException', () {
    test('isUnauthorized is true only for 401', () {
      expect(const ApiException('nope', statusCode: 401).isUnauthorized, isTrue);
      expect(const ApiException('nope', statusCode: 404).isUnauthorized, isFalse);
      expect(const ApiException('nope').isUnauthorized, isFalse);
    });

    test('isNotFound is true only for 404', () {
      expect(const ApiException('nope', statusCode: 404).isNotFound, isTrue);
      expect(const ApiException('nope', statusCode: 401).isNotFound, isFalse);
    });

    test('isValidation is true only for 422', () {
      expect(const ApiException('bad', statusCode: 422).isValidation, isTrue);
      expect(const ApiException('bad', statusCode: 500).isValidation, isFalse);
    });

    test('defaults to an empty errors list', () {
      expect(const ApiException('nope').errors, isEmpty);
    });

    test('carries the given errors list', () {
      final err = const ApiException('bad', statusCode: 422, errors: ['title is required']);
      expect(err.errors, ['title is required']);
    });

    test('toString includes the status code and message', () {
      expect(
        const ApiException('Task not found', statusCode: 404).toString(),
        'ApiException(404): Task not found',
      );
    });
  });
}
