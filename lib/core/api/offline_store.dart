import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps Ally usable without internet:
///  - a cache of the last successful answer for the screens you look at
///    (today's pick, tasks, habits, reminders…), shown when offline;
///  - a queue of small actions taken offline (Done / Minimum / Skip, finishing
///    a task, logging a habit), replayed in order once the server is reachable.
class OfflineStore {
  static const _cachePrefix = 'offline_cache_v1:';
  static const _queueKey = 'offline_queue_v1';

  /// Reads worth caching. Chat and AI calls are never cached.
  static const cachedPaths = [
    '/guide/tonight',
    '/guide/history',
    '/tasks',
    '/habits',
    '/areas',
    '/assistant/reminders',
    '/assistant/memories',
    '/settings',
  ];

  static bool shouldCache(String path) => cachedPaths.any((p) => path == p || path.startsWith('$p?'));

  static String _key(String path, Map<String, dynamic>? query) {
    if (query == null || query.isEmpty) return '$_cachePrefix$path';
    final keys = query.keys.toList()..sort();
    return '$_cachePrefix$path?${keys.map((k) => '$k=${query[k]}').join('&')}';
  }

  Future<void> saveRead(String path, Map<String, dynamic>? query, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(path, query), jsonEncode({'at': DateTime.now().toIso8601String(), 'data': data}));
    } catch (_) {
      // Cache is a convenience; never break the request over it.
    }
  }

  /// The last good answer for this read, or null.
  Future<({dynamic data, DateTime at})?> readCached(String path, Map<String, dynamic>? query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(path, query));
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (data: j['data'], at: DateTime.parse(j['at'] as String));
    } catch (_) {
      return null;
    }
  }

  Future<List<QueuedAction>> queue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(QueuedAction.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<QueuedAction> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode([for (final i in items) i.toJson()]));
  }

  Future<void> enqueue(QueuedAction action) async => _write([...await queue(), action]);

  Future<void> replaceQueue(List<QueuedAction> items) => _write(items);

  /// Signing out must not leave one person's cache or queue for the next.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_cachePrefix) || k == _queueKey).toList()) {
      await prefs.remove(k);
    }
  }
}

class QueuedAction {
  final String method; // post | patch
  final String path;
  final Object? body;
  final DateTime queuedAt;

  QueuedAction(this.method, this.path, this.body, this.queuedAt);

  Map<String, dynamic> toJson() => {'m': method, 'p': path, 'b': body, 'at': queuedAt.toIso8601String()};

  factory QueuedAction.fromJson(Map<String, dynamic> j) =>
      QueuedAction(j['m'] as String, j['p'] as String, j['b'], DateTime.parse(j['at'] as String));
}
