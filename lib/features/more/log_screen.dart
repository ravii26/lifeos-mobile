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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        width: double.infinity,
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: G.text(16, color: G.muted, height: 1.2)),
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
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            Text('Log and limits', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(left: 20, right: 6),
              constraints: const BoxConstraints(minHeight: 62),
              decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(31)),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _say,
                    onSubmitted: (_) => _send(),
                    style: G.text(17, height: 1.3),
                    cursorColor: G.accent,
                    decoration: InputDecoration(
                      hintText: 'Spent 250 on lunch',
                      hintStyle: G.text(17, color: G.faint, height: 1.3),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add to log',
                  onPressed: _busy ? null : _send,
                  icon: Icon(Icons.arrow_upward_rounded, color: G.onInk, size: 22),
                  style: IconButton.styleFrom(backgroundColor: G.accent, minimumSize: const Size(50, 50)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            if (_error != null) Text(_error!, style: G.text(17, color: G.muted, height: 1.4)),
            if (d == null && _error == null) Center(child: Padding(padding: const EdgeInsets.all(30), child: CircularProgressIndicator(color: G.accent, strokeWidth: 1.5))),
            if (d != null) ...[
              if (counts.isNotEmpty)
                _section('Today', [
                  for (final c in counts)
                    Row(children: [
                      Expanded(child: Text(c['target'] == null ? '${c['title']}: ${c['count']}' : '${c['title']}: ${c['count']} of ${c['target']}', style: G.text(19, height: 1.25))),
                      IconButton(
                        tooltip: 'Add one',
                        onPressed: () => _plus('${c['id']}'),
                        icon: Icon(Icons.add_rounded, color: G.onInk),
                        style: IconButton.styleFrom(backgroundColor: G.accent, minimumSize: const Size(46, 46)),
                      ),
                    ]),
                ]),
              if (limits.isNotEmpty)
                _section('My limits', [
                  for (final l in limits) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${l['line']}', style: G.text(18, height: 1.35))),
                ]),
              _section('Money this month', [
                Text(asInt(money?['entries']) == 0 ? 'Nothing logged yet.' : _inr(asDouble(money?['monthTotal'])), style: G.text(asInt(money?['entries']) == 0 ? 18 : 34, w: asInt(money?['entries']) == 0 ? FontWeight.w400 : FontWeight.w600, height: 1.2)),
                for (final c in categories.take(4))
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c['category']}  ${_inr(asDouble(c['total']))}', style: G.text(16, color: G.muted, height: 1.3))),
              ]),
              _section('Sleep, last 7 days', [
                Text(
                  asInt(sleep?['nights']) == 0
                      ? 'Nothing logged yet.'
                      : 'Average ${_one(asDouble(sleep?['average']))} h over ${sleep?['nights']} nights. Latest ${_one(asDouble(sleep?['latest']))} h.',
                  style: G.text(18, height: 1.35),
                ),
              ]),
              _section('Weight', [
                Text(
                  weight?['latest'] == null
                      ? 'Nothing logged yet.'
                      : '${_one(asDouble(weight?['latest']))} kg'
                          '${asInt(weight?['readings']) > 1 ? ', ${(asDouble(weight?['latest']) - asDouble(weight?['first'])) <= 0 ? 'down' : 'up'} ${_one((asDouble(weight?['latest']) - asDouble(weight?['first'])).abs())} kg since ${weight?['firstDate']}' : ''}',
                  style: G.text(18, height: 1.35),
                ),
              ]),
              if (recent.isNotEmpty)
                _section('Latest entries', [
                  for (final e in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            '${e['date']}  ${e['series']}  ${e['series'] == 'money' ? _inr(asDouble(e['value'])) : '${_one(asDouble(e['value']))} ${e['unit']}'}${e['label'] != null ? '  ${e['label']}' : ''}',
                            style: G.text(16, color: G.muted, height: 1.3),
                          ),
                        ),
                        IconButton(tooltip: 'Remove', onPressed: () => _remove(e), icon: Icon(Icons.close_rounded, size: 20, color: G.muted)),
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
