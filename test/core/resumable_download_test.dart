import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/voice/resumable_download.dart';

/// A tiny file server that understands Range and can cut the connection part-way, like a flaky
/// network does. It records every Range header it was asked for.
class _FlakyServer {
  _FlakyServer(this.bytes, {required this.dropAfter, this.supportsRange = true});
  final Uint8List bytes;
  final int? dropAfter; // cut the first full request after this many bytes
  final bool supportsRange;
  final ranges = <String?>[];
  late HttpServer server;
  var requests = 0;

  Future<String> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests++;
      final range = req.headers.value('range');
      ranges.add(range);
      var from = 0;
      if (supportsRange && range != null) {
        from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        if (from >= bytes.length) {
          req.response.statusCode = 416;
          await req.response.close();
          return;
        }
        req.response.statusCode = 206;
      }
      final body = bytes.sublist(from);
      req.response.headers.contentLength = body.length;
      final cut = requests == 1 && dropAfter != null ? dropAfter! : null;
      try {
        if (cut != null) {
          // Promise the whole file, send part of it, then close: the server aborts the connection,
          // which is what the phone sees when the network drops mid-download.
          req.response.add(body.sublist(0, cut));
          await req.response.flush();
          try {
            await req.response.close();
          } catch (_) {}
        } else {
          req.response.add(body);
          await req.response.close();
        }
      } catch (_) {}
    });
    return 'http://127.0.0.1:${server.port}/voice.tar.bz2';
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ally_dl_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Uint8List data(int n) => Uint8List.fromList(List.generate(n, (i) => (i * 31 + 7) % 251));

  test('carries on from the saved bytes after the connection drops, and the file is exact', () async {
    final bytes = data(3 * 1024 * 1024);
    final server = _FlakyServer(bytes, dropAfter: 1024 * 1024);
    final url = await server.start();
    final part = File('${dir.path}/v.part');
    final done = File('${dir.path}/v.tar.bz2');
    var retries = 0;
    await downloadResumable(url: url, part: part, finished: done, waitFor: (_) => Duration.zero, onRetry: (f, have, total) => retries++);
    await server.stop();

    expect(retries, 1);
    expect(done.readAsBytesSync(), bytes);
    expect(part.existsSync(), false);
    // The second request asked only for the rest, not for everything again.
    expect(server.ranges.first, isNull);
    expect(server.ranges.length, 2);
    expect(server.ranges[1], startsWith('bytes='));
    expect(int.parse(RegExp(r'bytes=(\d+)-').firstMatch(server.ranges[1]!)!.group(1)!), greaterThan(0));
  });

  test('a download stopped earlier is finished next time from where it was', () async {
    final bytes = data(2 * 1024 * 1024);
    final server = _FlakyServer(bytes, dropAfter: null);
    final url = await server.start();
    final part = File('${dir.path}/v.part');
    final done = File('${dir.path}/v.tar.bz2');
    part.writeAsBytesSync(bytes.sublist(0, 700000)); // left over from an earlier try
    await downloadResumable(url: url, part: part, finished: done, waitFor: (_) => Duration.zero);
    await server.stop();

    expect(done.readAsBytesSync(), bytes);
    expect(server.ranges.single, 'bytes=700000-');
  });

  test('a server without Range support restarts cleanly instead of corrupting the file', () async {
    final bytes = data(1024 * 1024);
    final server = _FlakyServer(bytes, dropAfter: null, supportsRange: false);
    final url = await server.start();
    final part = File('${dir.path}/v.part');
    final done = File('${dir.path}/v.tar.bz2');
    part.writeAsBytesSync(bytes.sublist(0, 1000)); // pretend an earlier try
    await downloadResumable(url: url, part: part, finished: done, waitFor: (_) => Duration.zero);
    await server.stop();

    expect(done.readAsBytesSync(), bytes);
  });

  test('gives up after too many drops in a row, keeping what it has', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final socket = await req.response.detachSocket(writeHeaders: false);
      socket.destroy(); // never answers properly
    });
    final part = File('${dir.path}/v.part');
    final done = File('${dir.path}/v.tar.bz2');
    await expectLater(
      downloadResumable(url: 'http://127.0.0.1:${server.port}/x', part: part, finished: done, maxFailures: 2, waitFor: (_) => Duration.zero),
      throwsA(anything),
    );
    await server.close(force: true);
    expect(done.existsSync(), false);
  });
}
