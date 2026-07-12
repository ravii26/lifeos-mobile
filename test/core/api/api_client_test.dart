import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/api/api_client.dart';
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/core/api/token_store.dart';

/// A [HttpClientAdapter] that never touches the network — returns a
/// canned status/body and records the request it was given, so we can
/// assert on ApiClient's real envelope-unwrapping / error-mapping logic
/// (the same code path production traffic goes through) without a server.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, this.body});

  final int statusCode;
  final Object? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final text = body == null ? '' : jsonEncode(body);
    return ResponseBody.fromString(
      text,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Returns a fixed token without touching flutter_secure_storage's platform
/// channel (unavailable in plain `flutter_test` unit tests).
class _FakeTokenStore extends TokenStore {
  _FakeTokenStore(this._token);
  final String? _token;

  @override
  String? get current => _token;
}

Dio _dioWith(_FakeAdapter adapter) => Dio(BaseOptions())..httpClientAdapter = adapter;

void main() {
  group('ApiClient', () {
    test('unwraps the {success, message, data} envelope on success', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: {'success': true, 'message': 'ok', 'data': {'id': '1', 'title': 'Task'}},
      );
      final client = ApiClient(_FakeTokenStore(null), dio: _dioWith(adapter));

      final result = await client.get('/tasks/1');

      expect(result, {'id': '1', 'title': 'Task'});
    });

    test('injects the bearer token from TokenStore when present', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: {'data': null});
      final client = ApiClient(_FakeTokenStore('abc123'), dio: _dioWith(adapter));

      await client.get('/tasks');

      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer abc123');
    });

    test('omits the Authorization header when there is no token', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: {'data': null});
      final client = ApiClient(_FakeTokenStore(null), dio: _dioWith(adapter));

      await client.get('/tasks');

      expect(adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
    });

    test('maps a 404 error response to ApiException with the server message', () async {
      final adapter = _FakeAdapter(
        statusCode: 404,
        body: {'success': false, 'message': 'Task not found', 'errors': null},
      );
      final client = ApiClient(_FakeTokenStore(null), dio: _dioWith(adapter));

      await expectLater(
        client.get('/tasks/missing'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Task not found')
              .having((e) => e.isNotFound, 'isNotFound', isTrue),
        ),
      );
    });

    test('maps a 422 validation error response and preserves the errors list', () async {
      final adapter = _FakeAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Validation failed',
          'errors': ['title is required'],
        },
      );
      final client = ApiClient(_FakeTokenStore(null), dio: _dioWith(adapter));

      await expectLater(
        client.post('/tasks', body: {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isValidation, 'isValidation', isTrue)
              .having((e) => e.errors, 'errors', ['title is required']),
        ),
      );
    });

    test('calls onUnauthorized when the server returns 401', () async {
      final adapter = _FakeAdapter(
        statusCode: 401,
        body: {'success': false, 'message': 'Unauthorized'},
      );
      final client = ApiClient(_FakeTokenStore('expired-token'), dio: _dioWith(adapter));
      var unauthorizedCalled = false;
      client.onUnauthorized = () => unauthorizedCalled = true;

      await expectLater(client.get('/me'), throwsA(isA<ApiException>()));
      expect(unauthorizedCalled, isTrue);
    });

    test('drops null query parameters instead of sending them as "null"', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: {'data': []});
      final client = ApiClient(_FakeTokenStore(null), dio: _dioWith(adapter));

      await client.get('/tasks', query: {'status': null, 'page': 2});

      expect(adapter.lastRequest!.queryParameters, {'page': 2});
    });
  });
}
