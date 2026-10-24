import 'dart:io';

import 'package:dio/dio.dart';

/// Downloads [url] into [part], then renames it to [finished]. If the connection drops, it asks for
/// the rest with an HTTP Range header and carries on from the bytes already saved, so a big file
/// never restarts from zero. Gives up after [maxFailures] drops in a row.
Future<void> downloadResumable({
  required String url,
  required File part,
  required File finished,
  CancelToken? cancel,
  void Function(int got, int total, int failures)? onProgress,
  void Function(int failures, int have, int total)? onRetry,
  int maxFailures = 10,
  Duration Function(int failures) waitFor = _defaultWait,
  Dio? dio,
}) async {
  final client = dio ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 60),
        followRedirects: true,
        maxRedirects: 6,
      ));
  var failures = 0;
  var total = 0;
  while (true) {
    final have = await part.exists() ? await part.length() : 0;
    IOSink? sink;
    try {
      final res = await client.get<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: have > 0 ? {'Range': 'bytes=$have-'} : null,
          validateStatus: (s) => s == 200 || s == 206 || s == 416,
        ),
      );
      if (res.statusCode == 416) {
        // The server says there is nothing left to send: what we have is the whole file.
        await part.rename(finished.path);
        return;
      }
      final resumed = res.statusCode == 206;
      var got = resumed ? have : 0;
      total = got + (int.tryParse(res.headers.value('content-length') ?? '') ?? 0);
      sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      await for (final chunk in res.data!.stream) {
        sink.add(chunk);
        got += chunk.length;
        onProgress?.call(got, total, failures);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (total > 0 && got < total) throw const SocketException('The connection closed early.');
      await part.rename(finished.path);
      return;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      failures++;
      if (failures > maxFailures) rethrow;
      onRetry?.call(failures, have, total);
      await Future<void>.delayed(waitFor(failures));
    }
  }
}

Duration _defaultWait(int failures) => Duration(seconds: failures < 5 ? 2 * failures : 10);
