import 'package:flutter/material.dart';
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

  Future<void> _start(BuildContext context, NowOption o) async {
    final cubit = context.read<NowCubit>();
    final result = await Navigator.of(context).push<TimerResult>(MaterialPageRoute(
      builder: (_) => TimerScreen(
        title: _shown(o),
        minutes: o.minutes > 0 ? o.minutes : 25,
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

  // Letting something go is never offered on a low day: that decision can wait.
  Future<void> _notNow(BuildContext context, NowState s, NowOption o) async {
    final cubit = context.read<NowCubit>();
    final choice = await showModalBottomSheet<String>(
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
      ),
    );
    if (choice == null) return;
    if (choice == 'SKIP') {
      await cubit.notNow();
    } else {
      await cubit.moveCurrent(choice);
    }
  }

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
                    child: Text(nowGreeting(now, lowEnergy: s.lowEnergy || s.sick),
                        style: G.text(21, w: FontWeight.w500, height: 1.22)),
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

class _NotNowSheet extends StatelessWidget {
  final String title;
  final bool isGoal;
  final bool canWeekend;
  final bool canLetGo;
  const _NotNowSheet({required this.title, required this.isGoal, required this.canWeekend, required this.canLetGo});

  Widget _choice(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: G.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).pop(value),
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(label, style: G.text(18, w: FontWeight.w500, height: 1.25)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(color: G.faint, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text('When should this come back?', style: G.text(32, w: FontWeight.w600, height: 1.12, letterSpacing: -0.6)),
            const SizedBox(height: 8),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(18, color: G.muted, height: 1.3)),
            const SizedBox(height: 18),
            _choice(context, 'Tomorrow', 'TOMORROW'),
            if (canWeekend) _choice(context, 'This weekend', 'WEEKEND'),
            _choice(context, 'Show me something else', 'SKIP'),
            if (canLetGo)
              TextButton(
                onPressed: () => Navigator.of(context).pop('LET_GO'),
                style: TextButton.styleFrom(foregroundColor: G.accent, minimumSize: const Size(64, 52)),
                child: Text(isGoal ? 'Park this goal for now' : 'Let this go',
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
            onPressed: () => talkRequest.value++,
            style: TextButton.styleFrom(backgroundColor: G.accent, foregroundColor: G.onInk, shape: const StadiumBorder()),
            icon: Icon(Icons.mic_none_rounded, size: 26, color: G.onInk),
            label: Text('Tell Ally', style: G.text(20, w: FontWeight.w600, color: G.onInk, height: 1.2)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Or start with', style: G.text(16, color: G.muted, height: 1.2)),
        const SizedBox(height: 10),
      ],
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
