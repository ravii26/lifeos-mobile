import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'offline_store.dart';
import 'token_store.dart';

/// Thrown when an action was saved to the offline queue instead of sent.
/// Callers treat it as success-pending: update the screen optimistically.
class QueuedOfflineException extends ApiException {
  QueuedOfflineException() : super("Saved offline. It'll sync when you're back online.");
}

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

  final OfflineStore offline = OfflineStore();

  /// True while the last read came from the offline cache.
  bool servingFromCache = false;
  bool _flushing = false;

  ApiClient(this._tokens, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              // Render free-tier instances sleep when idle and take
              // ~30-50s to wake, so the first request after inactivity is
              // slow. Generous timeouts avoid a spurious "took too long".
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              headers: {'Content-Type': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokens.current;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// GET → returns the `data` field (decoded JSON). Screens that matter keep
  /// working offline: on a network failure the last good answer is returned.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final q = _clean(query);
    try {
      final data = await _send(() => _dio.get(path, queryParameters: q));
      servingFromCache = false;
      if (OfflineStore.shouldCache(path)) await offline.saveRead(path, q, data);
      flushQueue();
      return data;
    } on ApiException catch (e) {
      if (e.statusCode == null && OfflineStore.shouldCache(path)) {
        final cached = await offline.readCached(path, q);
        if (cached != null) {
          servingFromCache = true;
          return cached.data;
        }
      }
      rethrow;
    }
  }

  /// [queueOffline]: for small actions (Done, finish a task, log a habit),
  /// a network failure queues the call for later instead of losing it.
  Future<dynamic> post(String path, {Object? body, bool queueOffline = false}) =>
      _sendOrQueue('post', path, body, queueOffline, () => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, {Object? body, bool queueOffline = false}) =>
      _sendOrQueue('patch', path, body, queueOffline, () => _dio.patch(path, data: body));

  Future<dynamic> _sendOrQueue(String method, String path, Object? body, bool queueOffline,
      Future<Response> Function() call) async {
    try {
      final data = await _send(call);
      flushQueue();
      return data;
    } on ApiException catch (e) {
      // No status code = the request never reached the server.
      if (queueOffline && e.statusCode == null && body is! FormData) {
        await offline.enqueue(QueuedAction(method, path, body, DateTime.now()));
        throw QueuedOfflineException();
      }
      rethrow;
    }
  }

  /// Replays actions taken offline, in order. Stops at the first network
  /// failure (still offline); drops an action the server rejects (4xx) so one
  /// bad item can't block the rest forever.
  Future<int> flushQueue() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final items = await offline.queue();
      if (items.isEmpty) return 0;
      final remaining = [...items];
      for (final item in items) {
        try {
          await _send(() => item.method == 'patch'
              ? _dio.patch(item.path, data: item.body)
              : _dio.post(item.path, data: item.body));
          remaining.removeAt(0);
          sent++;
        } on ApiException catch (e) {
          if (e.statusCode == null) break; // still offline
          remaining.removeAt(0); // rejected; skip it
        }
      }
      await offline.replaceQueue(remaining);
      return sent;
    } finally {
      _flushing = false;
    }
  }

  Future<dynamic> delete(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => _dio.delete(path, data: body, queryParameters: _clean(query)));

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
      final errs =
          (data['errors'] as List?)?.map((x) => x.toString()).toList() ??
          const <String>[];
      return ApiException(msg, statusCode: status, errors: errs);
    }

    final fallback = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'The server took too long to respond.',
      DioExceptionType.connectionError =>
        "You're offline, or the server is waking up. Try again in a moment.",
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
