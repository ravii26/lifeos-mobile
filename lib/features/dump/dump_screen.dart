import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/dump_result.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../places/now_cubit.dart' show placesRefresh;
import '../season/season_setup_screen.dart';
import '../shrink/shrink_screen.dart';

/// Opens "My head is full" (canvas board 7).
Future<void> openDump(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const DumpScreen()));

/// Say everything → Ally splits and sorts it by code → the honest time check
/// → make it fit (Shrink) or pick what this season is about. Every new thing
/// is a to-do, and one Undo takes the whole dump back.
class DumpScreen extends StatefulWidget {
  const DumpScreen({super.key});

  @override
  State<DumpScreen> createState() => _DumpScreenState();
}

class _DumpScreenState extends State<DumpScreen> {
  final _repo = getIt<LifeRepository>();
  final _text = TextEditingController();
  final _speech = SpeechToText();
  bool _listening = false;
  String _dictBase = '';
  bool _sending = false;
  DumpResult? _result;

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  void _snack(String m, {String? undoId}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        action: undoId == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await _repo.undo(undoId);
                  placesRefresh.value++;
                },
              ),
      ));

  // On-device dictation, the same as the capture sheet: no upload.
  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      _snack("Voice isn't available on this phone. Typing works too.");
      return;
    }
    _dictBase = _text.text.isEmpty ? '' : '${_text.text.trimRight()} ';
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _text.text = '$_dictBase${r.recognizedWords}';
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 5),
    );
  }

  Future<void> _sort() async {
    final t = _text.text.trim();
    if (t.length < 3) return;
    if (_listening) await _toggleMic();
    setState(() => _sending = true);
    try {
      final r = await _repo.dump(t);
      if (!mounted) return;
      placesRefresh.value++;
      setState(() {
        _result = r;
        _sending = false;
      });
      if (r.added > 0) _snack('Added ${r.added} ${r.added == 1 ? 'thing' : 'things'} to your list.', undoId: r.activityId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: G.bg,
        appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
        body: SafeArea(top: false, child: _result == null ? _say() : _sorted(_result!)),
      );

  Widget _say() => ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
        Text('My head is full', style: G.text(38, w: FontWeight.w600, height: 1.08, letterSpacing: -0.9)),
        const SizedBox(height: 8),
        Text('Say everything. Messy is fine, Hinglish is fine. I will sort it out.', style: G.text(18, color: G.muted, height: 1.38)),
        const SizedBox(height: 18),
        TextField(
          controller: _text,
          minLines: 7,
          maxLines: 14,
          maxLength: 4000,
          style: G.text(18, height: 1.4),
          decoration: InputDecoration(
            hintText: 'e.g. need to fix the geyser, call mom kal, DSA shuru karna hai, gym, pay the bill…',
            hintStyle: G.text(17, color: G.faint, height: 1.4),
            filled: true,
            fillColor: G.inset,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: G.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: G.line)),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: GPill(_listening ? 'Listening… tap to stop' : 'Speak instead', onTap: _toggleMic),
          ),
        ]),
        const SizedBox(height: 12),
        GPill(_sending ? 'Sorting it out…' : 'Sort it out',
            primary: true, onTap: _sending || _text.text.trim().length < 3 ? null : _sort),
      ]);

  Widget _group(String title, String help, List<DumpThing> things) {
    if (things.isEmpty) return const SizedBox.shrink();
    String due(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: G.text(12, w: FontWeight.w600, color: G.muted, letterSpacing: 0.6)),
        Text(help, style: G.text(14, color: G.faint)),
        const SizedBox(height: 6),
        for (final t in things)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Expanded(child: Text(t.title, style: G.text(17, height: 1.3))),
                if (t.due != null) Text(due(t.due!), style: G.text(14, color: G.accent)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _sorted(DumpResult r) => ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
        Text('Sorted.', style: G.text(38, w: FontWeight.w600, height: 1.08, letterSpacing: -0.9)),
        const SizedBox(height: 8),
        Text(
          [
            if (r.added > 0) '${r.added} ${r.added == 1 ? 'thing is' : 'things are'} out of your head and saved.',
            if (r.alreadyThere > 0) '${r.alreadyThere} ${r.alreadyThere == 1 ? 'was' : 'were'} already on your list.',
          ].join(' '),
          style: G.text(18, color: G.muted, height: 1.38),
        ),
        const SizedBox(height: 18),
        _group('Has a date', 'Ally reminds you before it', r.dated),
        _group('This week', 'You said soon', r.thisWeek),
        _group('Can wait', 'Saved, no rush', r.later),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: r.fits ? G.surfaceHigh : G.accent, borderRadius: BorderRadius.circular(24)),
          child: Text(r.line, style: G.text(18, color: r.fits ? G.ink : G.onInk, height: 1.38)),
        ),
        const SizedBox(height: 16),
        if (!r.fits) ...[
          GPill('Make it fit: keep, park or let go', primary: true, onTap: () => openShrink(context)),
          const SizedBox(height: 8),
        ],
        if (!r.hasSeason) ...[
          GPill('Pick what this season is about', primary: r.fits, onTap: () async {
            await openSeasonSetup(context);
            placesRefresh.value++;
          }),
          const SizedBox(height: 8),
        ],
        GPill('Done', onTap: () => Navigator.of(context).pop()),
      ]);
}
