import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../today/day_shape.dart' show duration;

/// What keeping the plan gave back: the first step, to start right away.
class KeptPlan {
  final String goalTitle;
  final String? stepId;
  final String? stepTitle;
  final int stepMinutes;

  /// True when the person chose "Start step one" rather than "Save, start later".
  final bool startNow;
  final String? activityId;
  const KeptPlan(this.goalTitle, this.stepId, this.stepTitle, this.stepMinutes, this.startNow, this.activityId);
}

/// "Make a goal concrete": what you want, why, what done looks like in about
/// eight weeks, and the time you can honestly give, then a draft plan that is
/// good enough to start, with step one at 15 minutes or less.
///
/// The server drafts it (AI when available, code otherwise) and checks it fits
/// the time given and the week's free time. Nothing is saved until "Start" or
/// "Save". Pops with a [KeptPlan], or null.
class ConcreteGoalScreen extends StatefulWidget {
  final String areaId;
  final String areaName;
  final LifeRepository repo;

  /// Prefill for the first question (an existing goal's words).
  final String? goal;

  const ConcreteGoalScreen({super.key, required this.areaId, required this.areaName, required this.repo, this.goal});

  @override
  State<ConcreteGoalScreen> createState() => _ConcreteGoalScreenState();
}

class _ConcreteGoalScreenState extends State<ConcreteGoalScreen> {
  // Generic choices: nothing here belongs to one person. Each also takes their own words.
  static const _whys = ['It matters for my work', 'I enjoy it', 'For my health', 'For people I care about', 'Not sure yet'];
  static const _dones = ['A habit, every week', 'A result I can point to', 'Just try it a few times'];
  static const _times = [30, 60, 120, 180, 300];

  late final _goal = TextEditingController(text: widget.goal ?? '');
  final _why = TextEditingController();
  final _done = TextEditingController();
  int _step = 0; // 0 what and why · 1 done · 2 time · 3 draft
  int _minutes = 120;
  bool _drafting = false;
  bool _saving = false;
  String? _error;
  Json? _proposal;

  @override
  void dispose() {
    _goal.dispose();
    _why.dispose();
    _done.dispose();
    super.dispose();
  }

  Json? get _plan => _proposal?['plan'] is Json ? _proposal!['plan'] as Json : null;

  Future<void> _draft() async {
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final p = await widget.repo.proposeGoalPlan(
        _goal.text.trim(),
        why: _why.text.trim().isEmpty ? null : _why.text.trim(),
        done: _done.text.trim().isEmpty ? null : _done.text.trim(),
        weeklyMinutes: _minutes,
      );
      if (!mounted) return;
      setState(() {
        _proposal = p;
        _drafting = false;
        _step = 3;
        if (_plan == null) _error = "Couldn't draft a plan from that. Try saying the goal another way.";
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _drafting = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _keep({required bool startNow}) async {
    final plan = _plan;
    if (plan == null || _saving) return;
    setState(() => _saving = true);
    try {
      final r = await widget.repo.acceptGoalPlan(plan, areaId: widget.areaId);
      if (!mounted) return;
      final first = r['firstStep'] is Json ? r['firstStep'] as Json : null;
      Navigator.of(context).pop(KeptPlan(
        asString(plan['title']),
        asStringOrNull(first?['id']),
        asStringOrNull(first?['title']),
        first == null ? 15 : asInt(first['minutes'], 15),
        startNow,
        asStringOrNull(r['activityId']),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  void _back() {
    if (_step == 0 || _drafting) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _step = _step == 3 ? 2 : _step - 1;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.ac;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step == 0 ? 'Close' : 'Back',
            icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: _back,
          ),
          title: Text(widget.areaName, style: AllyType.small(color: c.faint)),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Sp.side, 0, Sp.side, Sp.x6),
            children: [
              _progress(c),
              const SizedBox(height: Sp.x5),
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.d3),
                switchInCurve: Motion.ease,
                child: KeyedSubtree(key: ValueKey('$_step$_drafting'), child: _body(c)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress(AllyColors c) => Semantics(
        label: 'Step ${_step + 1} of 4',
        child: Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.d3),
                height: 4,
                decoration: BoxDecoration(color: i <= _step ? c.ink : c.raised, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ]),
      );

  Widget _chips(List<String> options, TextEditingController into) => Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
        for (final o in options)
          AllyChip(o, selected: into.text == o, onTap: () => setState(() => into.text = into.text == o ? '' : o)),
      ]);

  Widget _field(AllyColors c, TextEditingController ctl, String hint, {bool autofocus = false}) => TextField(
        controller: ctl,
        autofocus: autofocus,
        maxLength: 300,
        minLines: 1,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        style: AllyType.body(color: c.ink),
        decoration: InputDecoration(hintText: hint, counterText: ''),
        onChanged: (_) => setState(() {}),
      );

  Widget _body(AllyColors c) {
    if (_drafting) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Drafting your plan…', style: AllyType.h1(color: c.ink)),
        const SizedBox(height: Sp.x2),
        Text('Sizing it to ${duration(_minutes)} a week and checking it fits your week.', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x5),
        const AllySkeleton(height: 22, width: 220),
        const SizedBox(height: Sp.x3),
        const AllySkeleton(height: 120, radius: Rad.card),
      ]);
    }
    final error = _error == null
        ? const SizedBox.shrink()
        : Padding(padding: const EdgeInsets.only(bottom: Sp.x3), child: AllyNote(_error!));
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('What do you want?', style: AllyType.h1(color: c.ink)),
          const SizedBox(height: Sp.x3),
          _field(c, _goal, 'In your own words', autofocus: widget.goal == null),
          const SizedBox(height: Sp.x5),
          Text('Why does it matter?', style: AllyType.h2(color: c.ink)),
          const SizedBox(height: Sp.x1),
          Text('Optional. It helps on the days it feels hard.', style: AllyType.small(color: c.faint)),
          const SizedBox(height: Sp.x3),
          _chips(_whys, _why),
          const SizedBox(height: Sp.x2),
          _field(c, _why, 'Or say it yourself'),
          const SizedBox(height: Sp.x5),
          AllyButton('Next', wide: true, onPressed: _goal.text.trim().length < 3 ? null : () => setState(() => _step = 1)),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('In about 8 weeks, what would "done" look like?', style: AllyType.h1(color: c.ink)),
          const SizedBox(height: Sp.x3),
          _chips(_dones, _done),
          const SizedBox(height: Sp.x2),
          _field(c, _done, 'Or describe it'),
          const SizedBox(height: Sp.x5),
          AllyButton('Next', wide: true, onPressed: () => setState(() => _step = 2)),
          AllyButton('Skip', kind: AllyButtonKind.ghost, wide: true, onPressed: () => setState(() {
            _done.clear();
            _step = 2;
          })),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How much time a week, honestly?', style: AllyType.h1(color: c.ink)),
          const SizedBox(height: Sp.x2),
          Text('A plan you keep beats a bigger one you drop.', style: AllyType.body(color: c.muted)),
          const SizedBox(height: Sp.x4),
          Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
            for (final m in _times) AllyChip(duration(m), selected: _minutes == m, onTap: () => setState(() => _minutes = m)),
          ]),
          const SizedBox(height: Sp.x5),
          error,
          AllyButton('Draft my plan', wide: true, onPressed: _draft),
        ]);
      default:
        return _draftView(c, error);
    }
  }

  Widget _draftView(AllyColors c, Widget error) {
    final plan = _plan;
    if (plan == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        error,
        AllyButton('Change my answers', kind: AllyButtonKind.secondary, wide: true, onPressed: () => setState(() => _step = 0)),
      ]);
    }
    final milestones = ((plan['milestones'] as List?) ?? const []).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    final targets = ((plan['targets'] as List?) ?? const []).whereType<Json>().toList();
    final steps = ((plan['steps'] as List?) ?? const []).whereType<Json>().toList();
    final fit = _proposal?['fit'] is Json ? asStringOrNull((_proposal!['fit'] as Json)['message']) : null;
    final caution = _proposal?['caution'] is Json ? asStringOrNull((_proposal!['caution'] as Json)['message']) : null;
    final question = asStringOrNull(plan['question']);
    final byCode = _proposal?['draftedBy'] == 'CODE';
    final first = steps.isEmpty ? null : steps.first;
    return Stagger(gap: Sp.x4, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DRAFT 1 · GOOD ENOUGH TO START', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        Text(asString(plan['title']), style: AllyType.h1(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('It gets better as you go, from what you actually do.', style: AllyType.small(color: c.muted)),
      ]),
      if (byCode) const AllyBanner('Ally drafted this simply, without AI. Step one will make the next steps clear.', icon: Icons.info_outline_rounded),
      if (fit != null) AllyBanner(fit, icon: Icons.balance_rounded),
      if (caution != null) AllyBanner(caution, icon: Icons.schedule_rounded),
      if (question != null) AllyBanner(question, icon: Icons.help_outline_rounded),
      if (targets.isNotEmpty)
        _list(c, 'EACH WEEK', [
          for (final t in targets)
            (asString(t['title']), asString(t['unit']) == 'count' ? '${asInt(t['perWeek'])} ${asString(t['countUnit'], 'times')}' : duration(asInt(t['perWeek']))),
        ]),
      if (milestones.isNotEmpty) _list(c, 'MILESTONES', [for (final m in milestones) (m, '')]),
      if (steps.isNotEmpty) _list(c, 'FIRST STEPS', [for (final s in steps) (asString(s['title']), duration(asInt(s['minutes'], 15)))]),
      error,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AllyButton(first == null ? 'Keep this plan' : 'Start step one · ${duration(asInt(first['minutes'], 15))}',
            icon: first == null ? Icons.check_rounded : Icons.play_arrow_rounded,
            wide: true,
            onPressed: _saving ? null : () => _keep(startNow: first != null)),
        const SizedBox(height: Sp.x1),
        if (first != null)
          AllyButton('Save, start later', kind: AllyButtonKind.ghost, wide: true, onPressed: _saving ? null : () => _keep(startNow: false)),
        AllyButton('Change my answers', kind: AllyButtonKind.ghost, wide: true, onPressed: _saving ? null : () => setState(() => _step = 0)),
      ]),
    ]);
  }

  Widget _list(AllyColors c, String title, List<(String, String)> rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllyCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(color: c.line, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(rows[i].$1, style: AllyType.body(color: c.ink))),
                  if (rows[i].$2.isNotEmpty) ...[
                    const SizedBox(width: Sp.x2),
                    Text(rows[i].$2, style: AllyType.num(color: c.faint)),
                  ],
                ]),
              ),
            ],
          ]),
        ),
      ]);
}
