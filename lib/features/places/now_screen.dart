import 'package:flutter/material.dart';
import '../dump/dump_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/starters.dart';
import '../guide/guide_style.dart';
import 'done_screen.dart';
import 'know_card.dart';
import 'now_cubit.dart';
import 'now_life_lines.dart';
import 'timer_screen.dart';
import '../shrink/shrink_screen.dart';
import '../season/season_setup_screen.dart';

/// Real tasks are longer than "One DSA problem": the big type steps down to fit.
double nowTitleSize(String title) {
  final n = title.length;
  if (n <= 24) return 46;
  if (n <= 44) return 38;
  if (n <= 70) return 31;
  return 26;
}

/// What Ally says above the card. It follows the hour and how the day is going.
String nowGreeting(DateTime now, {bool lowEnergy = false}) {
  if (lowEnergy) return 'Easy day. Only small things.';
  if (now.hour >= 21 || now.hour < 5) return 'Last thing tonight.';
  if (now.hour < 12) return "Good morning. Let's start small.";
  if (now.hour < 17) return 'One thing at a time.';
  return "Long day? Let's do just one thing.";
}

/// Now: the one thing to do, why, and an easy way out. Talking to Ally opens
/// its own screen, so nothing else competes with the card here.
class NowScreen extends StatefulWidget {
  const NowScreen({super.key});

  @override
  State<NowScreen> createState() => _NowScreenState();
}

class _NowScreenState extends State<NowScreen> {
  // Nobody has told Ally anything yet: say hello instead of "nothing waiting".
  bool _fresh = false;

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_checkStarted);
    _checkStarted();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_checkStarted);
    super.dispose();
  }

  Future<void> _checkStarted() async {
    try {
      final started = (await SharedPreferences.getInstance()).getBool(allyStartedKey) ?? false;
      if (mounted && _fresh == started) setState(() => _fresh = !started);
    } catch (_) {}
  }

  static String _shown(NowOption o) => o.smaller ? o.minimum.replaceAll(RegExp(r'\.$'), '') : o.title;

  Future<void> _start(BuildContext context, NowOption o, {int? minutes}) async {
    final cubit = context.read<NowCubit>();
    final result = await Navigator.of(context).push<TimerResult>(MaterialPageRoute(
      builder: (_) => TimerScreen(
        title: _shown(o),
        minutes: minutes ?? (o.minutes > 0 ? o.minutes : 25),
        firstStep: !o.smaller && o.minimum.isNotEmpty ? o.minimum.replaceAll(RegExp(r'\.$'), '') : null,
      ),
    ));
    if (!context.mounted) return;
    if (result == TimerResult.finished) {
      await _done(context, o);
    } else if (result == TimerResult.stuck) {
      await cubit.smaller();
    }
  }

  Future<void> _done(BuildContext context, NowOption o) async {
    final cubit = context.read<NowCubit>();
    HapticFeedback.lightImpact();
    if (!await cubit.done() || !context.mounted) return;
    final choice = await Navigator.of(context).push<DoneChoice>(MaterialPageRoute(
      builder: (_) => DoneScreen(title: _shown(o), canUndo: cubit.state.undoId != null),
    ));
    if (choice == DoneChoice.undo) await cubit.undo();
    if (choice == DoneChoice.finishedForToday) await cubit.finishForToday();
  }

  // "What's in the way?" (decisions log #14): one optional tap, and each answer
  // gets its own fix instead of just a later date. The reason is kept with the
  // move so a restart can learn from it. Letting go is never offered on a low day.
  Future<void> _notNow(BuildContext context, NowState s, NowOption o) async {
    final cubit = context.read<NowCubit>();
    final picked = await showModalBottomSheet<({String? reason, String choice})>(
      context: context,
      backgroundColor: G.inset,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
      builder: (_) => _NotNowSheet(
        title: _shown(o),
        isGoal: o.sourceType == 'PROJECT',
        // For a habit the server would make "weekend" permanent, which is not what this asks.
        canWeekend: o.sourceType != 'HABIT',
        canLetGo: !s.lowEnergy,
        canShrink: !o.smaller,
      ),
    );
    if (picked == null || !context.mounted) return;
    switch (picked.choice) {
      case 'CLEAR':
        final go = await _showSteps(context, o);
        if (go == true && context.mounted) await _start(context, o);
      case 'SMALLER':
        await cubit.smaller();
      case 'FIVE':
        await _start(context, o, minutes: 5);
      case 'SKIP':
        await cubit.notNow(reason: picked.reason);
      default:
        await cubit.moveCurrent(picked.choice, reason: picked.reason);
    }
  }

  // "Not clear what to do": the first step, then the rest, so starting needs no decision.
  Future<bool?> _showSteps(BuildContext context, NowOption o) => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: G.inset,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(34))),
        builder: (sheet) {
          final steps = <String>[
            if (o.minimum.isNotEmpty) 'First: ${o.minimum.replaceAll(RegExp(r'\.$'), '')}',
            ...?o.detail?.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty),
          ];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text("Here's exactly how to start", style: G.text(28, w: FontWeight.w600, height: 1.12, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(o.title, style: G.text(17, color: G.muted, height: 1.3)),
                const SizedBox(height: 16),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: i == 0 ? G.accent : G.surfaceHigh, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: G.text(14, w: FontWeight.w600, color: i == 0 ? G.onInk : G.ink)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(steps[i], style: G.text(16, height: 1.4))),
                    ]),
                  ),
                if (steps.isEmpty) Text('Open it and do the first two minutes. That is the whole first step.', style: G.text(16, height: 1.4)),
                const SizedBox(height: 6),
                Text('Only step 1 matters right now.', style: G.text(14, color: G.faint)),
                const SizedBox(height: 16),
                GPill('Start step 1', primary: true, onTap: () => Navigator.of(sheet).pop(true)),
              ]),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: BlocConsumer<NowCubit, NowState>(
          listenWhen: (a, b) => b.error != null && a.error != b.error,
          listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!))),
          builder: (context, s) {
            final now = DateTime.now();
            final o = s.current;
            final picking = o != null && s.kind == 'PICK';
            final loading = s.status == NowStatus.loading;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 6),
                child: Row(children: [
                  const AllyOrb(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(nowGreeting(now, lowEnergy: s.lowEnergy || s.sick),
                          style: G.text(21, w: FontWeight.w500, height: 1.22)),
                      // Which chapter this is ("Switch & Shape · week 2 of 10"), once a season exists.
                      if (s.season != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(s.season!, style: G.text(14, color: G.faint, height: 1.2)),
                        ),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => RefreshIndicator(
                    onRefresh: context.read<NowCubit>().load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            if (s.fromSaved) const _SavedCopyBanner(),
                            if (picking && s.welcomeBack) const _WelcomeBack(),
                            if (picking && s.restart != null) _RestartCard(restart: s.restart!, busy: s.busy),
                            if (picking)
                              _TaskCard(option: o, focusMessage: s.focus ? s.message : null, shown: _shown(o))
                            else if (s.sick && !loading)
                              const _EasyDay()
                            else if (loading)
                              Text('Looking at your day…', style: G.text(26, w: FontWeight.w500, color: G.muted, height: 1.2))
                            else
                              _StartHere(fresh: _fresh, state: s),
                            if (picking && s.welcomeBack)
                              TextButton(
                                onPressed: () => openShrink(context),
                                style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 50)),
                                child: Text("Things changed. Let's redo my list", style: G.text(16, color: G.accent, height: 1.2)),
                              ),
                            if (s.undoId != null) _UndoBar(onUndo: context.read<NowCubit>().undo),
                            if (s.note != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(s.note!, style: G.text(16, color: G.muted, height: 1.4)),
                              ),
                            if (s.advice != null)
                              _AdviceBox(advice: s.advice!, busy: s.busy, onChoice: context.read<NowCubit>().adviceChoice),
                            if (s.prep.isNotEmpty) _PrepBox(steps: s.prep),
                            NowLifeLines(extras: s.extras, busy: s.busy),
                            // One short question at a time, never on top of the first-use starters.
                            if (!_fresh) const KnowCard(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (picking)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    GPill('Start', primary: true, onTap: s.busy ? null : () => _start(context, o)),
                    const SizedBox(height: 10),
                    _SecondChoices(
                      state: s,
                      option: o,
                      lateNight: now.hour >= 21 || now.hour < 5,
                      onDone: () => _done(context, o),
                      onNotNow: () => _notNow(context, s, o),
                    ),
                  ]),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

class _SecondChoices extends StatelessWidget {
  final NowState state;
  final NowOption option;
  final bool lateNight;
  final VoidCallback onDone;
  final VoidCallback onNotNow;
  const _SecondChoices({
    required this.state,
    required this.option,
    required this.lateNight,
    required this.onDone,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NowCubit>();
    final busy = state.busy;
    // Once it can't get smaller, the next honest step down is an easy day.
    final atSmallest = option.smaller || option.minimum.isEmpty;
    final second = state.lowEnergy ? 'Feeling better' : (atSmallest ? 'Low energy' : 'Too much');
    final VoidCallback? onSecond = busy
        ? null
        : (state.lowEnergy ? cubit.endLowEnergy : (atSmallest ? cubit.lowEnergy : cubit.smaller));
    return Row(children: [
      Expanded(child: GPill('Done', onTap: busy ? null : onDone)),
      const SizedBox(width: 8),
      Expanded(child: GPill(second, onTap: onSecond)),
      const SizedBox(width: 8),
      Expanded(child: GPill(lateNight ? 'Not tonight' : 'Not now', onTap: busy ? null : onNotNow)),
    ]);
  }
}

/// "What's in the way?" then "When should this come back?" (canvas board P1·D).
/// Each reason has its own fix: not clear → the steps, too big or tired → the
/// smaller version, didn't feel like it → just 5 minutes. No time and forgot
/// pick a "when", and the reason travels with it. Everything is optional.
class _NotNowSheet extends StatefulWidget {
  final String title;
  final bool isGoal;
  final bool canWeekend;
  final bool canLetGo;
  final bool canShrink; // already the smaller version: "too big" / "tired" just pick a time
  const _NotNowSheet({required this.title, required this.isGoal, required this.canWeekend, required this.canLetGo, required this.canShrink});

  @override
  State<_NotNowSheet> createState() => _NotNowSheetState();
}

class _NotNowSheetState extends State<_NotNowSheet> {
  String? _reason; // chosen reason that needs a "when" (no time, forgot, or tired/too big at the smallest size)

  void _pop(String choice, [String? reason]) => Navigator.of(context).pop((reason: reason ?? _reason, choice: choice));

  void _tapReason(String reason) {
    final fix = switch (reason) {
      'not clear what to do' => 'CLEAR',
      'too big' || 'tired' => widget.canShrink ? 'SMALLER' : null,
      "didn't feel like it" => 'FIVE',
      _ => null,
    };
    if (fix != null) return _pop(fix, reason);
    setState(() => _reason = _reason == reason ? null : reason);
  }

  Widget _choice(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: G.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _pop(value),
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(label, style: G.text(18, w: FontWeight.w500, height: 1.25)),
            ),
          ),
        ),
      );

  static const _reasons = [
    ('Tired', 'tired'),
    ('No time', 'no time'),
    ('Too big', 'too big'),
    ('Not clear what to do', 'not clear what to do'),
    ('Forgot', 'forgot'),
    ("Didn't feel like it", "didn't feel like it"),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: G.faint, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text("What's in the way?", style: G.text(30, w: FontWeight.w600, height: 1.12, letterSpacing: -0.6)),
            const SizedBox(height: 6),
            Text('One tap, optional. It helps me plan better.', style: G.text(16, color: G.muted, height: 1.3)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (label, value) in _reasons)
                ChoiceChip(
                  label: Text(label, style: G.text(15, w: _reason == value ? FontWeight.w600 : FontWeight.w400, color: _reason == value ? G.onInk : G.ink)),
                  selected: _reason == value,
                  showCheckmark: false,
                  selectedColor: G.accent,
                  backgroundColor: G.surfaceHigh,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onSelected: (_) => _tapReason(value),
                ),
            ]),
            const SizedBox(height: 22),
            Text('When should this come back?', style: G.text(20, w: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 4),
            Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(16, color: G.muted, height: 1.3)),
            const SizedBox(height: 12),
            _choice('Tomorrow', 'TOMORROW'),
            if (widget.canWeekend) _choice('This weekend', 'WEEKEND'),
            _choice('Show me something else', 'SKIP'),
            if (widget.canLetGo)
              TextButton(
                onPressed: () => _pop('LET_GO'),
                style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 52)),
                child: Text(widget.isGoal ? 'Park this goal for now' : 'Let this go',
                    style: G.text(17, w: FontWeight.w500, color: G.accent, height: 1.2)),
              ),
          ]),
        ),
      );
}

class _TaskCard extends StatelessWidget {
  final NowOption option;
  final String? focusMessage;
  final String shown;
  const _TaskCard({required this.option, required this.focusMessage, required this.shown});

  @override
  Widget build(BuildContext context) {
    final ink = G.onInk;
    // A deadline taking the rest of today: the message says what waits.
    var why = focusMessage ?? (option.why.isEmpty ? null : option.why);
    if (option.smaller && option.title != shown) why = 'The small version of: ${option.title}';
    final firstStep = !option.smaller && option.minimum.isNotEmpty ? option.minimum : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: G.accent,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 50, offset: Offset(0, 22))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(option.smaller ? 'Smaller version' : 'Right now', style: G.text(16, w: FontWeight.w500, color: ink, height: 1.2)),
          if (option.minutes > 0) Text('${option.minutes} min', style: G.text(16, w: FontWeight.w500, color: ink, height: 1.2)),
        ]),
        const SizedBox(height: 12),
        Text(shown, style: G.text(nowTitleSize(shown), w: FontWeight.w600, color: ink, height: 1.05, letterSpacing: -1)),
        if (why != null) ...[
          const SizedBox(height: 12),
          Text(why, style: G.text(18, color: ink, height: 1.34)),
        ],
        if (firstStep != null) ...[
          Container(height: 1, margin: const EdgeInsets.fromLTRB(0, 18, 0, 14), color: ink.withValues(alpha: 0.2)),
          Text('First step', style: G.text(15, color: ink, height: 1.2)),
          const SizedBox(height: 3),
          Text(firstStep, style: G.text(19, w: FontWeight.w500, color: ink, height: 1.25)),
        ],
      ]),
    );
  }
}

/// No connection: say so once, calmly. Done, Not now and the rest still work.
class _SavedCopyBanner extends StatelessWidget {
  const _SavedCopyBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
        child: Text("Can't reach the internet. You can keep going, and I'll save it when you're back.", style: G.text(17, height: 1.3)),
      );
}

/// Back after a gap: no overdue pile, no "where were you".
class _WelcomeBack extends StatelessWidget {
  const _WelcomeBack();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Good to see you.', style: G.text(42, w: FontWeight.w600, height: 1.05, letterSpacing: -1.2)),
          const SizedBox(height: 8),
          Text('No catching up needed. Start with one small thing.', style: G.text(19, color: G.muted, height: 1.35)),
        ]),
      );
}

/// Back after a week or more (decisions log #14): what got in the way last
/// time and what to change, a light week, the honest record. Everything here
/// is offered; "Keep as is" changes nothing.
class _RestartCard extends StatelessWidget {
  final NowRestart restart;
  final bool busy;
  const _RestartCard({required this.restart, required this.busy});

  Widget _button(String label, VoidCallback? onTap, {bool dark = true}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: busy ? null : onTap,
            style: TextButton.styleFrom(
              backgroundColor: dark ? G.onInk : Colors.transparent,
              foregroundColor: dark ? G.ink : G.onInk,
              side: dark ? null : BorderSide(color: G.onInk),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: const StadiumBorder(),
            ),
            child: Text(label, style: G.text(16, w: FontWeight.w600, color: dark ? G.ink : G.onInk)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NowCubit>();
    final r = restart;
    final switchTo = r.canLightWeek ? r.suggestBlock : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.insight != null || r.canLightWeek || r.resetup)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.resetup) ...[
                Text('A lot may have changed', style: G.text(18, w: FontWeight.w600, color: G.onInk)),
                const SizedBox(height: 4),
                Text('It\'s been a while. Pick this season\'s focus again in 2 minutes?', style: G.text(15, color: G.onInk, height: 1.35)),
                _button('Redo my season', () async {
                  cubit.dismissRestart();
                  await openSeasonSetup(context);
                }),
              ] else if (r.insight != null)
                Text(r.insight!, style: G.text(16, color: G.onInk, height: 1.4)),
              if (switchTo != null && !r.resetup)
                _button(switchTo == 'MORNING' ? 'Yes, move to mornings' : 'Yes, move to evenings', () => cubit.restartPlan(lightWeek: true, switchTo: switchTo)),
              if (r.canLightWeek && switchTo == null && !r.resetup) _button('Start with a light week', () => cubit.restartPlan(lightWeek: true)),
              _button('Keep as is', cubit.dismissRestart, dark: false),
            ]),
          ),
        if (r.record != null)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text(r.record!, style: G.text(15, color: G.muted, height: 1.35))),
      ]),
    );
  }
}

/// Sick mode: one kind instruction, and nothing to tick off.
class _EasyDay extends StatelessWidget {
  const _EasyDay();

  @override
  Widget build(BuildContext context) {
    final ink = G.onInk;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Just take care of yourself.', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
      const SizedBox(height: 12),
      Text('I moved everything else. Nothing is lost.', style: G.text(19, color: G.muted, height: 1.36)),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(32)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Only this today', style: G.text(16, w: FontWeight.w500, color: ink, height: 1.2)),
          const SizedBox(height: 10),
          Text('Drink water and rest', style: G.text(36, w: FontWeight.w600, color: ink, height: 1.08, letterSpacing: -0.9)),
        ]),
      ),
      const SizedBox(height: 18),
      GPill("I'm feeling better", onTap: context.read<NowCubit>().feelingBetter),
      TextButton(
        onPressed: () => talkRequest.value++,
        style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 50)),
        child: Text('I just want to talk', style: G.text(17, color: G.accent, height: 1.2)),
      ),
    ]);
  }
}

class _UndoBar extends StatelessWidget {
  final VoidCallback onUndo;
  const _UndoBar({required this.onUndo});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.only(left: 20, right: 6),
        constraints: const BoxConstraints(minHeight: 58),
        decoration: BoxDecoration(color: G.surfaceHigh, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Expanded(child: Text('Saved', style: G.text(17))),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 46)),
            child: Text('Undo', style: G.text(17, w: FontWeight.w600, color: G.accent, height: 1.2)),
          ),
        ]),
      );
}

class _PrepBox extends StatelessWidget {
  final List<String> steps;
  const _PrepBox({required this.steps});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ready for tomorrow', style: G.text(15, color: G.accent, height: 1.2)),
          const SizedBox(height: 5),
          Text(steps.join('; '), style: G.text(17, height: 1.35)),
        ]),
      );
}

class _AdviceBox extends StatelessWidget {
  final NowAdvice advice;
  final bool busy;
  final ValueChanged<String> onChoice;
  const _AdviceBox({required this.advice, required this.busy, required this.onChoice});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(advice.message, style: G.text(17, height: 1.35)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final (label, choice) in advice.actions)
              TextButton(
                onPressed: busy ? null : () => onChoice(choice),
                style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: Text(label, style: G.text(16, w: FontWeight.w600, color: G.accent, height: 1.2)),
              ),
          ]),
        ]),
      );
}

/// Nothing to do right now: Ally's hello and the four ways to start.
class _StartHere extends StatelessWidget {
  final bool fresh;
  final NowState state;
  const _StartHere({required this.fresh, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.restedToday) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Nothing else today.', style: G.text(50, w: FontWeight.w600, height: 1.04, letterSpacing: -1.5)),
        const SizedBox(height: 12),
        Text('Rest is part of the plan.', style: G.text(20, color: G.muted, height: 1.38)),
        const SizedBox(height: 24),
        GPill('Actually, show me more', onTap: context.read<NowCubit>().resumeToday),
      ]);
    }
    final String title;
    final String body;
    if (state.status == NowStatus.error) {
      title = "I can't reach the server right now.";
      body = 'You can still start something, and I will catch up when it is back.';
    } else if (fresh) {
      title = "What's on your mind right now?";
      body = "Say it messy. Work, health, family, money, anything. I'll sort it out.";
    } else if (state.options.isNotEmpty) {
      title = "That's all I'd suggest right now.";
      body = 'Rest is part of the plan. Or add something:';
    } else if (state.kind == 'REST') {
      title = state.message.isEmpty ? 'Time to rest.' : state.message;
      body = 'Want to add something for later?';
    } else {
      title = 'Nothing to do right now.';
      body = 'Rest is part of the plan. Or add something:';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: G.text(38, w: FontWeight.w600, height: 1.08, letterSpacing: -0.9)),
      const SizedBox(height: 10),
      Text(body, style: G.text(19, color: G.muted, height: 1.38)),
      const SizedBox(height: 20),
      if (fresh) ...[
        SizedBox(
          height: 72,
          child: TextButton.icon(
            // The way in for an overwhelmed person: everything first, then one thing (canvas board 1).
            onPressed: () => openDump(context),
            style: TextButton.styleFrom(backgroundColor: G.accent, foregroundColor: G.onInk, shape: const StadiumBorder()),
            icon: Icon(Icons.mic_none_rounded, size: 26, color: G.onInk),
            label: Text('My head is full: say everything', style: G.text(19, w: FontWeight.w600, color: G.onInk, height: 1.2)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Or start with', style: G.text(16, color: G.muted, height: 1.2)),
        const SizedBox(height: 10),
      ],
      if (!fresh)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: G.card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => openDump(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(children: [
                  Icon(Icons.blur_on_rounded, size: 24, color: G.accent),
                  const SizedBox(width: 14),
                  Expanded(child: Text('My head is full', style: G.text(18, w: FontWeight.w500, height: 1.25))),
                ]),
              ),
            ),
          ),
        ),
      for (final st in nowStarters)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: G.card,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () => starterRequest.value = st,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(children: [
                  Icon(st.icon, size: 24, color: G.accent),
                  const SizedBox(width: 14),
                  Expanded(child: Text(st.label, style: G.text(18, w: FontWeight.w500, height: 1.25))),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}
