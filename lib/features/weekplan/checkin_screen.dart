import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/fitness_plan.dart';
import '../../data/models/sleep_plan.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

Future<void> openCheckin(BuildContext context) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const CheckinScreen()));

/// The Sunday check-in (decisions log #1, #13; canvas board P1·E): about two
/// minutes. Last week's sessions, next week's plan (changed by fixed rules,
/// never by AI), the weekly weigh-in and the sleep question, then "Looks good".
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _repo = getIt<LifeRepository>();
  final _weight = TextEditingController();
  CheckinPreview? _fit;
  SleepPlan? _sleep;
  bool _loading = true;
  String? _error;
  int? _sleepDays; // how many days the wake time was kept; null = not answered
  bool _saving = false;
  List<String>? _results; // after "Looks good"
  String? _undoId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.checkinPreview(), _repo.sleepPlan()]);
      if (!mounted) return;
      setState(() {
        _fit = results[0] as CheckinPreview?;
        _sleep = results[1] as SleepPlan?;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _apply() async {
    setState(() => _saving = true);
    final lines = <String>[];
    try {
      if (_fit != null && !_fit!.alreadyDone) {
        final r = await _repo.applyCheckin(weightKg: double.tryParse(_weight.text.trim().replaceAll(',', '.')));
        _undoId = r.activityId;
        lines.add(r.result?.message ?? _fit!.message);
        if (r.weightLine != null) lines.add(r.weightLine!);
      }
      if (_sleep != null && !_sleep!.done && _sleepDays != null) {
        final s = await _repo.sleepCheckin(_sleepDays!);
        lines.add(s.message);
      }
      if (lines.isEmpty) lines.add('Nothing to change this week. See you next Sunday.');
      if (mounted) {
        setState(() {
          _results = lines;
          _saving = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static const _dayName = {'MON': 'Mon', 'TUE': 'Tue', 'WED': 'Wed', 'THU': 'Thu', 'FRI': 'Fri', 'SAT': 'Sat', 'SUN': 'Sun'};

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(
        backgroundColor: G.bg,
        surfaceTintColor: G.bg,
        foregroundColor: G.ink,
        elevation: 0,
        title: Text('Sunday check-in', style: G.text(20, w: FontWeight.w500, height: 1.2)),
      ),
      body: SafeArea(top: false, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: Text('Looking at your week…', style: G.text(20, color: G.muted)));
    if (_error != null) return Padding(padding: const EdgeInsets.all(22), child: Text(_error!, style: G.text(17, color: G.muted)));
    if (_results != null) return _done();
    final f = _fit, s = _sleep;
    if (f == null && s == null) {
      return Padding(
        padding: const EdgeInsets.all(22),
        child: Text('Nothing to check in on yet. Start a fitness plan or a sleep plan in My life.', style: G.text(18, color: G.muted, height: 1.4)),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
      Text("Here's your week.", style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
      const SizedBox(height: 6),
      Text('About two minutes. Next week adjusts itself.', style: G.text(16, color: G.muted)),
      const SizedBox(height: 18),
      if (f != null && f.askWeight && !f.alreadyDone) ...[
        Text('Weight this morning? (optional)', style: G.text(16, w: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: G.text(18),
          decoration: InputDecoration(
            hintText: f.lastWeight != null ? 'last: ${f.lastWeight} kg' : 'kg',
            hintStyle: G.text(16, color: G.faint),
            filled: true,
            fillColor: G.inset,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: G.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: G.line)),
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (f != null)
        _card([
          Row(children: [
            Expanded(child: Text('Fitness · week ${f.week} of ${f.weeks}', style: G.text(17, w: FontWeight.w600))),
            Text('${f.done} of ${f.planned}', style: G.text(17, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          Text(f.message, style: G.text(15, color: G.accent, height: 1.35)),
          if (!f.alreadyDone)
            for (final x in f.sessions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${x.title}: ${x.changed ?? 'same, ${x.minutes} min · ${x.days.map((d) => _dayName[d] ?? d).join(', ')}'}',
                    style: G.text(14, color: G.muted, height: 1.35)),
              ),
          if (f.alreadyDone) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Already checked in this week.', style: G.text(14, color: G.faint))),
        ]),
      if (s != null && !s.done)
        _card([
          Row(children: [
            Expanded(child: Text('Sleep · week ${s.step} of ${s.steps.length}', style: G.text(17, w: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          Text('How many days did you wake by ${clockLabel(s.current.wake)}?', style: G.text(15, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var d = 0; d <= 7; d++)
              ChoiceChip(
                label: Text('$d', style: G.text(15, w: FontWeight.w600, color: _sleepDays == d ? G.onInk : G.ink)),
                selected: _sleepDays == d,
                showCheckmark: false,
                selectedColor: G.accent,
                backgroundColor: G.surfaceHigh,
                side: BorderSide.none,
                shape: const CircleBorder(),
                onSelected: (_) => setState(() => _sleepDays = d),
              ),
          ]),
          const SizedBox(height: 6),
          Text('5 or more moves you to next week\'s times. Fewer is fine: same times one more week.', style: G.text(13, color: G.faint, height: 1.35)),
        ]),
      const SizedBox(height: 16),
      GPill(_saving ? 'Saving…' : 'Looks good', primary: true, onTap: _saving ? null : _apply),
    ]);
  }

  Widget _done() => ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 24), children: [
        Text('Next week is set.', style: G.text(34, w: FontWeight.w600, height: 1.1, letterSpacing: -0.8)),
        const SizedBox(height: 6),
        Text('Nothing to plan. Today\'s piece shows on Now.', style: G.text(17, color: G.muted)),
        const SizedBox(height: 18),
        for (final l in _results!)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _card([Text(l, style: G.text(16, height: 1.4))]),
          ),
        const SizedBox(height: 10),
        GPill('Done', primary: true, onTap: () => Navigator.of(context).pop()),
        if (_undoId != null && _undoId!.isNotEmpty)
          TextButton(
            onPressed: () async {
              await _repo.undo(_undoId!);
              if (mounted) Navigator.of(context).pop();
            },
            child: Text('Undo the fitness changes', style: G.text(16, color: G.muted)),
          ),
      ]);
}
