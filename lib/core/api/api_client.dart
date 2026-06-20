import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// Thin wrapper over Dio that:
///  - injects the bearer token,
///  - unwraps the LifeOS `{ success, message, data }` envelope,
///  - normalizes errors into [ApiException],
///  - notifies a listener on 401 so the app can sign out.
class ApiClient {
  final Dio _dio;
  final TokenStore _tokens;

  /// Invoked when the server returns 401 on an authenticated call.
  void Function()? onUnauthorized;

  ApiClient(this._tokens, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _tokens.current;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  /// GET → returns the `data` field (decoded JSON).
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  Future<dynamic> _send(Future<Response> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map && body['data'] != null) return body['data'];
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) onUnauthorized?.call();

    final data = e.response?.data;
    if (data is Map) {
      final msg = (data['message'] as String?) ?? 'Request failed';
      final errs = (data['errors'] as List?)
              ?.map((x) => x.toString())
              .toList() ??
          const <String>[];
      return ApiException(msg, statusCode: status, errors: errs);
    }

    final fallback = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'The server took too long to respond.',
      DioExceptionType.connectionError =>
        'Cannot reach the server. Is the backend running?',
      _ => e.message ?? 'Network error',
    };
    return ApiException(fallback, statusCode: status);
  }

  /// Drops null query params so we don't send `?status=null`.
  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out.isEmpty ? null : out;
  }
}
