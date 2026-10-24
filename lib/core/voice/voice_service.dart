import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'resumable_download.dart';
import 'sherpa_worker.dart';
import 'speech_chunks.dart';
import 'voice_catalog.dart';
import 'wav.dart';

/// How Ally speaks. The chosen offline voice (made on the phone by the voice engine) is used when
/// it is installed; anything that goes wrong falls back to the phone's own voice, so Ally never
/// goes silent. Stopping is immediate: every call carries a token that [stop] invalidates.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  static const _kVoice = 'voice.id'; // '' or missing = the phone's voice

  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  final AudioPlayer _player = AudioPlayer();
  SherpaWorker? _worker;
  String? _workerFor;
  int _token = 0;
  Completer<void>? _playing;

  /// What the last spoken reply used, for the voice screen ("Natural voice" or "Phone voice").
  String lastEngine = '';

  // ---- choosing ------------------------------------------------------------

  Future<String?> chosenId() async {
    try {
      final id = (await SharedPreferences.getInstance()).getString(_kVoice);
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  Future<void> choose(String? id) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_kVoice, id ?? '');
    } catch (_) {}
    // A different voice starts fresh next time.
    _closeWorker();
  }

  // ---- files ---------------------------------------------------------------

  Future<Directory> _base() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/voices');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _dirOf(VoiceOption v) async => Directory('${(await _base()).path}/${v.pkg}');

  Future<bool> isInstalled(VoiceOption v) async {
    final d = await _dirOf(v);
    for (final f in v.requiredFiles) {
      if (!await File('${d.path}/$f').exists()) return false;
    }
    return Directory('${d.path}/espeak-ng-data').exists();
  }

  // ---- downloading ---------------------------------------------------------
  // The download belongs to the service, not to the screen: leaving the screen does not stop it,
  // it picks up where it left off after a dropped connection (or a restart of the app), and a
  // finished download is kept until the unpacking has worked.

  final ValueNotifier<InstallState> installState = ValueNotifier(const InstallState());
  CancelToken? _installCancel;

  bool get installing => installState.value.stage == InstallStage.downloading || installState.value.stage == InstallStage.unpacking;

  Future<File> _archiveOf(VoiceOption v) async {
    final dir = Directory('${(await _base()).path}/_downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${v.pkg}.tar.bz2');
  }

  /// Bytes of this voice already downloaded (a partial or a complete archive), for "Resume".
  Future<int> downloadedBytes(VoiceOption v) async {
    final f = await _archiveOf(v);
    final part = File('${f.path}.part');
    if (await f.exists()) return f.length();
    if (await part.exists()) return part.length();
    return 0;
  }

  void _setInstall(InstallState s) => installState.value = s;

  /// Starts (or resumes) the download and unpacking of [v]. Returns at once; follow [installState].
  void startInstall(VoiceOption v) {
    if (installing) return;
    _installCancel = CancelToken();
    _runInstall(v, _installCancel!);
  }

  /// Stops the download. What was downloaded is kept, so the next start resumes.
  void cancelInstall() => _installCancel?.cancel('stopped');

  Future<void> _runInstall(VoiceOption v, CancelToken cancel) async {
    _setInstall(InstallState(voiceId: v.id, stage: InstallStage.downloading, label: 'Starting the download'));
    try {
      final archive = await _archiveOf(v);
      if (!await archive.exists()) {
        await _download(v, File('${archive.path}.part'), archive, cancel);
      }
      _setInstall(InstallState(voiceId: v.id, stage: InstallStage.unpacking, progress: 0.9, label: 'Unpacking. This takes a minute or two; keep the app open.'));
      final from = archive.path;
      final to = (await _base()).path;
      await Isolate.run(() => extractFileToDisk(from, to));
      if (!await isInstalled(v)) throw StateError('The voice files were incomplete.');
      await archive.delete();
      await choose(v.id);
      _setInstall(InstallState(voiceId: v.id, stage: InstallStage.done, progress: 1, label: 'Ready'));
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _setInstall(InstallState(voiceId: v.id, stage: InstallStage.idle, label: 'Stopped. Tap Resume to carry on.'));
      } else {
        debugPrint('Ally voice: download failed: $e');
        _setInstall(InstallState(voiceId: v.id, stage: InstallStage.failed, error: "The download couldn't finish (no connection?). What was downloaded is kept; tap Resume to carry on."));
      }
    } catch (e) {
      debugPrint('Ally voice: install failed: $e');
      // A bad archive would fail the same way forever, so it is thrown away; the next try starts fresh.
      try {
        final a = await _archiveOf(v);
        if (await a.exists()) await a.delete();
        final d = await _dirOf(v);
        if (await d.exists()) await d.delete(recursive: true);
      } catch (_) {}
      _setInstall(InstallState(voiceId: v.id, stage: InstallStage.failed, error: "Couldn't unpack the voice ($e). Tap Download to try again."));
    }
  }

  // The download itself is in resumable_download.dart (tested against a connection that drops).
  Future<void> _download(VoiceOption v, File part, File finished, CancelToken cancel) {
    return downloadResumable(
      url: v.url,
      part: part,
      finished: finished,
      cancel: cancel,
      onProgress: (got, total, failures) {
        if (total > 0) {
          _setInstall(InstallState(
            voiceId: v.id,
            stage: InstallStage.downloading,
            progress: got / total * 0.85,
            label: 'Downloading ${(got / 1048576).round()} of ${(total / 1048576).round()} MB${failures > 0 ? ' (resumed)' : ''}',
          ));
        }
      },
      onRetry: (failures, have, total) => _setInstall(InstallState(
        voiceId: v.id,
        stage: InstallStage.downloading,
        progress: total > 0 ? have / total * 0.85 : 0,
        label: 'Connection dropped. Trying again in a moment ($failures of 10)',
      )),
    );
  }

  Future<void> remove(VoiceOption v) async {
    if (_workerFor == v.id) _closeWorker();
    final d = await _dirOf(v);
    if (await d.exists()) await d.delete(recursive: true);
    final a = await _archiveOf(v);
    if (await a.exists()) await a.delete();
    final p = File('${a.path}.part');
    if (await p.exists()) await p.delete();
  }

  // ---- speaking ------------------------------------------------------------

  Future<void> speak(String text) async {
    final chunks = speechChunks(text);
    if (chunks.isEmpty) return;
    final mine = ++_token;
    final v = voiceById(await chosenId());
    if (v != null && await isInstalled(v)) {
      try {
        await _speakNeural(v, chunks, mine);
        lastEngine = 'Natural voice (${v.label})';
        return;
      } catch (e) {
        debugPrint('Ally voice: ${v.label} failed, using the phone voice instead: $e');
        _closeWorker();
        if (mine != _token) return;
      }
    }
    await _speakSystem(chunks.join(' '), mine);
  }

  Future<void> stop() async {
    _token++;
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    final p = _playing;
    if (p != null && !p.isCompleted) p.complete();
  }

  Future<void> _speakSystem(String text, int mine) async {
    if (!_ttsReady) {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.5);
      _ttsReady = true;
    }
    if (mine != _token) return;
    lastEngine = 'Phone voice';
    await _tts.speak(text);
  }

  Future<SherpaWorker> _workerFor_(VoiceOption v) async {
    if (_worker != null && _workerFor == v.id) return _worker!;
    _closeWorker();
    final d = await _dirOf(v);
    final config = <String, String>{
      'kind': v.kind.name,
      'model': '${d.path}/${v.model}',
      'tokens': '${d.path}/tokens.txt',
      'dataDir': '${d.path}/espeak-ng-data',
      if (v.kind == VoiceKind.kokoro) 'voices': '${d.path}/voices.bin',
      'threads': '4',
    };
    final w = await SherpaWorker.start(config);
    _worker = w;
    _workerFor = v.id;
    return w;
  }

  void _closeWorker() {
    _worker?.dispose();
    _worker = null;
    _workerFor = null;
  }

  // One sentence is being made while the previous one plays, so there is no gap between them.
  Future<void> _speakNeural(VoiceOption v, List<String> chunks, int mine) async {
    final worker = await _workerFor_(v);
    final cache = await getTemporaryDirectory();
    Future<File> make(int i) async {
      final r = await worker.say(chunks[i], speaker: v.speaker);
      final f = File('${cache.path}/ally_voice_${i % 2}.wav');
      await f.writeAsBytes(encodeWav(r.samples, r.sampleRate), flush: true);
      return f;
    }

    var next = make(0);
    for (var i = 0; i < chunks.length; i++) {
      final file = await next;
      if (mine != _token) return;
      // Chunk i+1 is made into the other file while this one plays.
      if (i + 1 < chunks.length) next = make(i + 1);
      await _play(file.path, mine);
      if (mine != _token) return;
    }
  }

  Future<void> _play(String path, int mine) async {
    final done = Completer<void>();
    _playing = done;
    final sub = _player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _player.play(DeviceFileSource(path));
      await done.future;
    } finally {
      await sub.cancel();
    }
  }

  // ---- measuring -----------------------------------------------------------

  /// Makes one sentence with [v] and reports how fast, without playing it. Used by the voice
  /// screen to show whether a voice is quick enough on this phone.
  Future<SynthResult> measure(VoiceOption v, {String text = 'Good morning. You have a short walk planned before office, then ten minutes of practice.'}) async {
    final worker = await _workerFor_(v);
    final first = await worker.say(text, speaker: v.speaker); // the first run includes warm-up
    final second = await worker.say(text, speaker: v.speaker);
    debugPrint('Ally voice benchmark ${v.label}: first ${first.ms} ms, then ${second.ms} ms for ${second.audioSeconds.toStringAsFixed(1)} s of speech (${second.realTimeFactor.toStringAsFixed(2)}x real time)');
    return second;
  }
}

enum InstallStage { idle, downloading, unpacking, done, failed }

/// Progress of the voice download, shown on the voice screen. [progress] is 0..1.
class InstallState {
  final String? voiceId;
  final InstallStage stage;
  final double progress;
  final String label;
  final String? error;
  const InstallState({this.voiceId, this.stage = InstallStage.idle, this.progress = 0, this.label = '', this.error});
}
