import 'package:flutter/material.dart';

import '../../core/voice/voice_catalog.dart';
import '../../core/voice/voice_service.dart';
import '../guide/guide_style.dart';

/// You > Ally's voice: the phone's own voice, or a more natural voice that is downloaded once
/// and then works with no internet. Hear it, and check it is fast enough on this phone.
/// The download lives in [VoiceService], so leaving this screen does not stop it.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final _voice = VoiceService.instance;
  String? _chosen; // null = the phone's voice
  final Map<String, bool> _installed = {};
  final Map<String, int> _partial = {}; // bytes already downloaded of a voice that is not installed yet
  String? _speedNote;
  String? _error;
  bool _checking = false;
  bool _speaking = false;

  static const _sample = 'Good morning. You have office at ten, and a short walk planned before it. Shall we start?';

  @override
  void initState() {
    super.initState();
    _voice.installState.addListener(_onInstall);
    _load();
  }

  @override
  void dispose() {
    _voice.installState.removeListener(_onInstall);
    _voice.stop();
    super.dispose();
  }

  // A finished or stopped download changes what is installed and what can be resumed.
  void _onInstall() {
    final st = _voice.installState.value.stage;
    if (st == InstallStage.done || st == InstallStage.failed || st == InstallStage.idle) _load();
  }

  Future<void> _load() async {
    final id = await _voice.chosenId();
    final installed = <String, bool>{for (final v in voiceOptions) v.id: await _voice.isInstalled(v)};
    final partial = <String, int>{for (final v in voiceOptions) v.id: await _voice.downloadedBytes(v)};
    if (!mounted) return;
    setState(() {
      _chosen = installed[id] == true ? id : null;
      _installed
        ..clear()
        ..addAll(installed);
      _partial
        ..clear()
        ..addAll(partial);
    });
  }

  Future<void> _use(String? id) async {
    await _voice.choose(id);
    setState(() {
      _chosen = id;
      _speedNote = null;
    });
  }

  Future<void> _remove(VoiceOption v) async {
    await _voice.remove(v);
    if (_chosen == v.id) await _voice.choose(null);
    await _load();
  }

  Future<void> _hear() async {
    if (_speaking) {
      await _voice.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _voice.speak(_sample);
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _checkSpeed(VoiceOption v) async {
    setState(() {
      _checking = true;
      _speedNote = null;
      _error = null;
    });
    try {
      final r = await _voice.measure(v);
      final f = r.realTimeFactor;
      final verdict = f < 0.5 ? 'Plenty fast.' : f < 1 ? 'Fast enough.' : 'Too slow for smooth talking.';
      if (mounted) {
        setState(() => _speedNote =
            'Made ${r.audioSeconds.toStringAsFixed(1)} s of speech in ${(r.ms / 1000).toStringAsFixed(1)} s (${f.toStringAsFixed(2)}x real time). $verdict');
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't run this voice: $e");
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: const GTopBar("Ally's voice", subtitle: 'How Ally sounds when it talks', showBack: true),
      body: ValueListenableBuilder<InstallState>(
        valueListenable: _voice.installState,
        builder: (context, install, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'Natural voices are downloaded once (use Wi-Fi) and then work with no internet. The download carries on if you leave this screen, and resumes if the connection drops. If a voice fails, Ally uses the phone voice.',
              style: G.text(13, color: G.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            const GHeading('Choose a voice'),
            _row(
              title: 'Phone voice',
              sub: "Your phone's built-in voice. Always works. You can pick a better one in Android's text-to-speech settings.",
              selected: _chosen == null,
              trailing: _chosen == null ? null : TextButton(onPressed: () => _use(null), child: Text('Use', style: G.text(14, w: FontWeight.w700))),
            ),
            for (final v in voiceOptions) _voiceRow(v, install),
            const SizedBox(height: 16),
            GButton(_speaking ? 'Stop' : 'Hear it', onTap: _hear),
            if (_speedNote != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_speedNote!, style: G.text(13, color: G.muted, height: 1.4))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: G.text(13, color: G.muted, height: 1.4))),
            if (_voice.lastEngine.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text('Last spoken with: ${_voice.lastEngine}', style: G.label(size: 11, color: G.faint))),
          ],
        ),
      ),
    );
  }

  Widget _voiceRow(VoiceOption v, InstallState install) {
    final installed = _installed[v.id] == true;
    final mine = install.voiceId == v.id;
    final running = mine && (install.stage == InstallStage.downloading || install.stage == InstallStage.unpacking);
    final failed = mine && install.stage == InstallStage.failed;
    final selected = _chosen == v.id;
    final partialMb = ((_partial[v.id] ?? 0) / 1048576).round();

    Widget? below;
    if (running) {
      below = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: install.stage == InstallStage.unpacking || install.progress == 0 ? null : install.progress, color: G.accent, backgroundColor: G.lineSoft),
          const SizedBox(height: 4),
          Text(install.label, style: G.label(size: 11, color: G.faint)),
        ]),
      );
    } else if (failed) {
      below = Padding(padding: const EdgeInsets.only(top: 6), child: Text(install.error ?? 'It did not finish.', style: G.text(13, color: G.muted, height: 1.4)));
    } else if (!installed && partialMb > 0) {
      below = Padding(padding: const EdgeInsets.only(top: 6), child: Text('$partialMb MB already downloaded.', style: G.label(size: 11, color: G.faint)));
    }

    Widget trailing;
    if (running) {
      trailing = install.stage == InstallStage.downloading
          ? TextButton(onPressed: _voice.cancelInstall, child: Text('Stop', style: G.text(14, color: G.muted)))
          : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (!installed) {
      final label = failed || partialMb > 0 ? 'Resume' : 'Download';
      trailing = TextButton(
        onPressed: _voice.installing ? null : () => _voice.startInstall(v),
        child: Text(label, style: G.text(14, w: FontWeight.w700)),
      );
    } else {
      trailing = PopupMenuButton<String>(
        onSelected: (a) {
          if (a == 'use') _use(v.id);
          if (a == 'speed') _checkSpeed(v);
          if (a == 'remove') _remove(v);
        },
        itemBuilder: (_) => [
          if (!selected) const PopupMenuItem(value: 'use', child: Text('Use this voice')),
          PopupMenuItem(value: 'speed', enabled: !_checking, child: Text(_checking ? 'Checking…' : 'Check speed')),
          const PopupMenuItem(value: 'remove', child: Text('Remove download')),
        ],
        icon: Icon(Icons.more_horiz, color: G.faint),
      );
    }

    return _row(title: v.label, sub: '${v.blurb} About ${v.mb} MB.', selected: selected, below: below, trailing: trailing);
  }

  Widget _row({required String title, required String sub, required bool selected, Widget? trailing, Widget? below}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: G.lineSoft, width: 0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: selected ? G.accent : G.faint),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: G.text(15, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub, style: G.text(13, color: G.muted, height: 1.4)),
              if (below != null) below,
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      );
}
