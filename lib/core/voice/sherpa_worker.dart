import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Speech made by the voice engine: float samples plus how long the engine took.
class SynthResult {
  final Float32List samples;
  final int sampleRate;
  final int ms;
  const SynthResult(this.samples, this.sampleRate, this.ms);

  double get audioSeconds => samples.length / sampleRate;

  /// Seconds of work per second of speech; under 1 means it speaks faster than real time.
  double get realTimeFactor => audioSeconds == 0 ? 0 : (ms / 1000) / audioSeconds;
}

/// Runs the voice engine in its own isolate: making speech takes real time, and doing it on the
/// screen's thread would freeze the app. Settings travel as a plain string map.
class SherpaWorker {
  SherpaWorker._(this._isolate, this._send, this._receive);
  final Isolate _isolate;
  final SendPort _send;
  final ReceivePort _receive;
  final _pending = <int, Completer<SynthResult>>{};
  int _next = 0;
  bool _closed = false;

  static Future<SherpaWorker> start(Map<String, String> config) async {
    final receive = ReceivePort();
    final ready = Completer<SendPort>();
    SherpaWorker? worker;
    receive.listen((m) {
      if (m is! List) return;
      switch (m[0]) {
        case 'ready':
          ready.complete(m[1] as SendPort);
        case 'error':
          if (!ready.isCompleted) ready.completeError(StateError(m[1] as String));
        case 'audio':
          final c = worker?._pending.remove(m[1] as int);
          final bytes = (m[2] as TransferableTypedData).materialize().asFloat32List();
          c?.complete(SynthResult(bytes, m[3] as int, m[4] as int));
        case 'fail':
          worker?._pending.remove(m[1] as int)?.completeError(StateError(m[2] as String));
      }
    });
    final isolate = await Isolate.spawn(_main, [receive.sendPort, config]);
    final send = await ready.future.timeout(const Duration(seconds: 90), onTimeout: () {
      isolate.kill(priority: Isolate.immediate);
      throw StateError('The voice took too long to start.');
    });
    return worker = SherpaWorker._(isolate, send, receive);
  }

  Future<SynthResult> say(String text, {int speaker = 0, double speed = 1.0}) {
    if (_closed) return Future.error(StateError('The voice was closed.'));
    final id = _next++;
    final c = Completer<SynthResult>();
    _pending[id] = c;
    _send.send(['say', id, text, speaker, speed]);
    return c.future;
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _send.send('dispose');
    for (final c in _pending.values) {
      c.completeError(StateError('The voice was closed.'));
    }
    _pending.clear();
    _receive.close();
    Future.delayed(const Duration(seconds: 1), () => _isolate.kill(priority: Isolate.beforeNextEvent));
  }
}

sherpa.OfflineTtsConfig _configFor(Map<String, String> c) {
  final threads = int.tryParse(c['threads'] ?? '') ?? 2;
  if (c['kind'] == 'kokoro') {
    return sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(model: c['model']!, voices: c['voices']!, tokens: c['tokens']!, dataDir: c['dataDir']!),
        numThreads: threads,
        debug: false,
        provider: 'cpu',
      ),
      maxNumSenetences: 1,
    );
  }
  return sherpa.OfflineTtsConfig(
    model: sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(model: c['model']!, tokens: c['tokens']!, dataDir: c['dataDir']!),
      numThreads: threads,
      debug: false,
      provider: 'cpu',
    ),
    maxNumSenetences: 1,
  );
}

// The isolate's entry point. Bindings must be loaded again in every isolate that uses the engine.
void _main(List<Object?> args) {
  final out = args[0] as SendPort;
  final config = Map<String, String>.from(args[1] as Map);
  final inbox = ReceivePort();
  sherpa.OfflineTts? tts;
  try {
    sherpa.initBindings();
    tts = sherpa.OfflineTts(_configFor(config));
    out.send(['ready', inbox.sendPort]);
  } catch (e) {
    out.send(['error', e.toString()]);
    return;
  }
  inbox.listen((m) {
    if (m is List && m[0] == 'say') {
      final id = m[1] as int;
      try {
        final watch = Stopwatch()..start();
        final audio = tts!.generate(text: m[2] as String, sid: m[3] as int, speed: m[4] as double);
        out.send(['audio', id, TransferableTypedData.fromList([audio.samples]), audio.sampleRate, watch.elapsedMilliseconds]);
      } catch (e) {
        out.send(['fail', id, e.toString()]);
      }
    } else if (m == 'dispose') {
      tts?.free();
      inbox.close();
    }
  });
}
