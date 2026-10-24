import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

/// Counts, limits, spending, sleep and weight in one place (Phase D). Everything is a
/// plain number: no streaks, no red. Adding is a sentence ("spent 250 on lunch"),
/// the same words as in chat; removing an entry has Undo.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _repo = getIt<LifeRepository>();
  final _say = TextEditingController();
  Json? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _say.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.logOverview();
      if (mounted) setState(() {
        _data = d;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _plus(String habitId) async {
    try {
      final r = await _repo.addCount(habitId);
      _toast(asString(r['line'], 'Counted.'));
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _send() async {
    final text = _say.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final reply = await _repo.chat(text, const []);
      _say.clear();
      _toast(reply.reply);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Json entry) async {
    try {
      final undo = await _repo.removeLogEntry('${entry['id']}');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Entry removed'),
        action: undo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await _repo.undo(undo);
                  _load();
                },
              ),
      ));
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  static String _inr(num n) => '₹${NumberFormat.decimalPattern('en_IN').format(n.round())}';
  static String _one(num n) => (n.round() == n ? n.round() : (n * 10).round() / 10).toString();

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        width: double.infinity,
        decoration: BoxDecoration(
          color: G.card,
          border: Border.all(color: G.lineSoft, width: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: G.label(size: 11, color: G.faint, w: FontWeight.w600)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final counts = (d?['counts'] as List? ?? const []).whereType<Json>().toList();
    final limits = (d?['limits'] as List? ?? const []).whereType<Json>().toList();
    final money = d?['money'] as Json?;
    final sleep = d?['sleep'] as Json?;
    final weight = d?['weight'] as Json?;
    final recent = (d?['recent'] as List? ?? const []).whereType<Json>().toList();
    final categories = (money?['byCategory'] as List? ?? const []).whereType<Json>().toList();

    return Scaffold(
      backgroundColor: G.bg,
      appBar: const GTopBar('Log and limits', subtitle: 'Numbers you told Ally', showBack: true),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: G.inset, border: Border.all(color: G.lineSoft, width: 0.5), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _say,
                    onSubmitted: (_) => _send(),
                    style: G.text(14),
                    decoration: InputDecoration(
                      hintText: 'Say it: spent 250 on lunch · slept 7 hours · weight 74',
                      hintStyle: G.label(size: 12, color: G.faint),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(onPressed: _busy ? null : _send, icon: Icon(Icons.send_rounded, color: G.accent, size: 20)),
              ]),
            ),
            const SizedBox(height: 14),
            if (_error != null) Text(_error!, style: G.text(14, color: G.carried)),
            if (d == null && _error == null) Center(child: Padding(padding: const EdgeInsets.all(30), child: CircularProgressIndicator(color: G.accent, strokeWidth: 1.5))),
            if (d != null) ...[
              if (counts.isNotEmpty)
                _section('TODAY', [
                  for (final c in counts)
                    Row(children: [
                      Expanded(child: Text(c['target'] == null ? '${c['title']}: ${c['count']}' : '${c['title']}: ${c['count']} of ${c['target']}', style: G.text(14, w: FontWeight.w500))),
                      IconButton(onPressed: () => _plus('${c['id']}'), icon: Icon(Icons.add_circle_outline_rounded, color: G.good), tooltip: '+1'),
                    ]),
                ]),
              if (limits.isNotEmpty)
                _section('LIMITS', [
                  for (final l in limits) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${l['line']}', style: G.text(14, height: 1.35))),
                ]),
              _section('MONEY THIS MONTH', [
                Text(asInt(money?['entries']) == 0 ? 'Nothing logged yet.' : _inr(asDouble(money?['monthTotal'])), style: G.text(22, w: FontWeight.w600)),
                for (final c in categories.take(4))
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c['category']}  ${_inr(asDouble(c['total']))}', style: G.text(13, color: G.muted))),
              ]),
              _section('SLEEP, LAST 7 DAYS', [
                Text(
                  asInt(sleep?['nights']) == 0
                      ? 'Nothing logged yet.'
                      : 'Average ${_one(asDouble(sleep?['average']))} h over ${sleep?['nights']} nights. Latest ${_one(asDouble(sleep?['latest']))} h.',
                  style: G.text(14, height: 1.35),
                ),
              ]),
              _section('WEIGHT', [
                Text(
                  weight?['latest'] == null
                      ? 'Nothing logged yet.'
                      : '${_one(asDouble(weight?['latest']))} kg'
                          '${asInt(weight?['readings']) > 1 ? ', ${(asDouble(weight?['latest']) - asDouble(weight?['first'])) <= 0 ? 'down' : 'up'} ${_one((asDouble(weight?['latest']) - asDouble(weight?['first'])).abs())} kg since ${weight?['firstDate']}' : ''}',
                  style: G.text(14, height: 1.35),
                ),
              ]),
              if (recent.isNotEmpty)
                _section('LATEST ENTRIES', [
                  for (final e in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${e['date']}  ${e['series']}  ${e['series'] == 'money' ? _inr(asDouble(e['value'])) : '${_one(asDouble(e['value']))} ${e['unit']}'}${e['label'] != null ? '  ${e['label']}' : ''}',
                            style: G.text(13, color: G.muted),
                          ),
                        ),
                        IconButton(visualDensity: VisualDensity.compact, tooltip: 'Remove', onPressed: () => _remove(e), icon: Icon(Icons.close_rounded, size: 16, color: G.faint)),
                      ]),
                    ),
                ]),
            ],
          ],
        ),
      ),
    );
  }
}
