import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/fitness_plan.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

/// Opens the fitness plan setup. Returns the Undo id when a plan was started.
Future<String?> openFitnessSetup(BuildContext context) =>
    Navigator.of(context).push<String?>(MaterialPageRoute(builder: (_) => const FitnessSetupScreen()));

/// The fitness weekly plan (decisions log #1, canvas board P1·C): five quick
/// questions → the plan (phase, week shape, smallest versions, food rules,
/// rules for parties and cravings) → start. Ally runs it from there.
class FitnessSetupScreen extends StatefulWidget {
  const FitnessSetupScreen({super.key});

  @override
  State<FitnessSetupScreen> createState() => _FitnessSetupScreenState();
}

class _FitnessSetupScreenState extends State<FitnessSetupScreen> {
  final _repo = getIt<LifeRepository>();
  final _a = FitnessAnswers();
  final _weight = TextEditingController();
  FitnessPlan? _plan; // shown once "Make my plan" is tapped
  bool _busy = false;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Widget _chips(List<(String, String)> options, bool Function(String) on, void Function(String) tap) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, label) in options)
            ChoiceChip(
              label: Text(label, style: G.text(15, w: on(value) ? FontWeight.w600 : FontWeight.w400, color: on(value) ? G.onInk : G.ink)),
              selected: on(value),
              showCheckmark: false,
              selectedColor: G.accent,
              backgroundColor: G.card,
              side: BorderSide.none,
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() => tap(value)),
            ),
        ],
      );

  Widget _q(String text) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(text, style: G.text(18, w: FontWeight.w500)));

  Future<void> _make() async {
    _a.weightKg = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    setState(() => _busy = true);
    try {
      final p = await _repo.previewFitnessPlan(_a);
      if (mounted) {
        setState(() {
          _plan = p;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final undoId = await _repo.startFitnessPlan(_a);
      if (mounted) Navigator.of(context).pop(undoId ?? '');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(
        backgroundColor: G.bg,
        surfaceTintColor: G.bg,
        foregroundColor: G.ink,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _plan != null ? setState(() => _plan = null) : Navigator.of(context).pop(),
        ),
        title: Text('Fitness plan', style: G.text(20, w: FontWeight.w500, height: 1.2)),
      ),
      body: SafeArea(top: false, child: _plan == null ? _questions() : _preview(_plan!)),
    );
  }

  Widget _questions() => ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
        Text('Five quick questions', style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
        const SizedBox(height: 6),
        Text('Then Ally writes one simple plan and runs it with you.', style: G.text(17, color: G.muted, height: 1.4)),
        _q('Main goal?'),
        _chips(const [('LOSE_BELLY', 'Lose belly fat'), ('LOSE_WEIGHT', 'Lose weight'), ('BUILD_MUSCLE', 'Build muscle'), ('STAMINA', 'Stamina')],
            (v) => _a.goal == v, (v) => _a.goal = v),
        _q('Weight now? (optional)'),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: G.text(18),
          decoration: InputDecoration(
            hintText: 'kg',
            hintStyle: G.text(16, color: G.faint),
            filled: true,
            fillColor: G.inset,
            helperText: "Don't know? Skip it; I'll ask on Sunday morning.",
            helperStyle: G.text(13, color: G.faint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: G.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: G.line)),
          ),
        ),
        _q('Gym or home?'),
        _chips(const [('GYM', 'Gym'), ('HOME', 'Home'), ('BOTH', 'Both')], (v) => _a.where == v, (v) => _a.where = v),
        _q('What do you eat?'),
        _chips(const [('VEG', 'Veg'), ('VEG_EGG', 'Veg + eggs'), ('NON_VEG', 'Non-veg')], (v) => _a.diet == v,
            (v) => _a.diet = _a.diet == v ? null : v),
        const SizedBox(height: 8),
        _chips(
          const [('home', 'Home food'), ('mess', 'Mess / PG'), ('outside', 'Outside / junk often')],
          (v) => switch (v) { 'home' => _a.homeFood, 'mess' => _a.messFood, _ => _a.outsideOften },
          (v) => switch (v) {
            'home' => _a.homeFood = !_a.homeFood,
            'mess' => _a.messFood = !_a.messFood,
            _ => _a.outsideOften = !_a.outsideOften,
          },
        ),
        _q('Any health condition?'),
        _chips(const [('NONE', 'None'), ('CONDITION', 'BP / sugar / thyroid / PCOS'), ('JOINT', 'Knee or joint pain')],
            (v) => _a.health == v, (v) => _a.health = v),
        const SizedBox(height: 26),
        GPill(_busy ? 'Making it…' : 'Make my plan', primary: true, onTap: _busy ? null : _make),
      ]);

  static const _dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  Widget _preview(FitnessPlan p) {
    String? on(String day) {
      for (final s in p.sessions) {
        if (s.days.contains(day)) return s.key == 'STRENGTH' ? (_a.where == 'HOME' ? 'Home' : 'Gym') : 'Walk';
      }
      return null;
    }

    Widget rule(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: G.accent, shape: BoxShape.circle))),
            Expanded(child: Text(t, style: G.text(16, height: 1.4))),
          ]),
        );

    return ListView(padding: const EdgeInsets.fromLTRB(22, 4, 22, 24), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Phase 1 · ${p.phaseWeeks} weeks', style: G.text(14, w: FontWeight.w500, color: G.onInk)),
          const SizedBox(height: 4),
          Text(p.title, style: G.text(26, w: FontWeight.w600, color: G.onInk, height: 1.1)),
          if (p.startKg != null) Text('About 0.5 kg a week, a safe pace. Weigh in on Sunday mornings.', style: G.text(14, color: G.onInk, height: 1.35)),
          const SizedBox(height: 12),
          Row(children: [
            for (final d in _dayNames)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: on(d) == null ? Colors.transparent : (on(d) == 'Walk' ? G.onInk.withValues(alpha: 0.12) : G.onInk),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: G.onInk.withValues(alpha: on(d) == null ? 0.35 : 1)),
                  ),
                  child: Column(children: [
                    Text(d[0] + d.substring(1).toLowerCase(), style: G.text(11, color: on(d) == null || on(d) == 'Walk' ? G.onInk : G.accent)),
                    Text(on(d) ?? 'Rest', style: G.text(11, w: FontWeight.w600, color: on(d) == null || on(d) == 'Walk' ? G.onInk : G.accent)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Text('Week 1 is lighter on purpose: 4 sessions. Early overdoing is why most people quit.', style: G.text(13, color: G.onInk, height: 1.35)),
        ]),
      ),
      const SizedBox(height: 16),
      for (final s in p.sessions)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(18)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: G.ink,
              collapsedIconColor: G.faint,
              title: Text('${s.title} · ${s.minutes} min', style: G.text(16, w: FontWeight.w500)),
              subtitle: Text('Smallest version: ${s.smallest}', style: G.text(13, color: G.muted)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(s.detail, style: G.text(15, height: 1.5))],
            ),
          ),
        ),
      const SizedBox(height: 10),
      Text('3 food rules', style: G.text(17, w: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final r in p.foodRules) rule(r),
      const SizedBox(height: 6),
      Text('When life happens', style: G.text(17, w: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final r in p.lifeRules) rule(r),
      const SizedBox(height: 6),
      for (final c in p.cautions) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(c, style: G.text(13, color: G.faint, height: 1.35))),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What I do for you', style: G.text(16, w: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Show only today\'s piece on Now, with a smaller version. Keep these rules in Notes and read them back when you need them. Adjust the plan each Sunday. Restart you lighter if you disappear.',
              style: G.text(15, color: G.muted, height: 1.4)),
          const SizedBox(height: 10),
          Text('What you do', style: G.text(16, w: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('The workouts and the food. That\'s it.', style: G.text(15, color: G.muted, height: 1.4)),
        ]),
      ),
      const SizedBox(height: 22),
      GPill(_busy ? 'Starting…' : 'Start the plan', primary: true, onTap: _busy ? null : _start),
    ]);
  }
}
