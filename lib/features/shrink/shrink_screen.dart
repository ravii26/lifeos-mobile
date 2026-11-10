import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../places/now_cubit.dart';
import 'shrink_cubit.dart';

/// Opens the session from anywhere under the shell, and refreshes Now afterwards.
Future<void> openShrink(BuildContext context) async {
  final now = context.read<NowCubit>();
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => BlocProvider(
      create: (_) => ShrinkCubit(getIt<LifeRepository>(), lowEnergy: now.state.lowEnergy)..load(),
      child: const ShrinkScreen(),
    ),
  ));
  placesRefresh.value++;
  await now.load();
}

/// Shrink the pile: the honest number, one card at a time, and what is left.
class ShrinkScreen extends StatelessWidget {
  const ShrinkScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: G.bg,
        body: SafeArea(
          child: BlocConsumer<ShrinkCubit, ShrinkState>(
            listenWhen: (a, b) => b.error != null && a.error != b.error && b.stage != ShrinkStage.error,
            listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!))),
            builder: (context, s) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
              child: switch (s.stage) {
                ShrinkStage.loading => Center(child: Text('Adding it all up…', style: G.text(24, color: G.muted))),
                ShrinkStage.error => _Message(title: "I can't reach your list right now.", body: s.error ?? '', action: 'Try again', onAction: context.read<ShrinkCubit>().load),
                ShrinkStage.empty => _Message(title: 'Your list is clear.', body: "There's nothing to shrink right now.", action: 'Back', onAction: () => Navigator.of(context).pop()),
                ShrinkStage.summary => _Summary(s),
                ShrinkStage.deciding => _Deciding(s),
                ShrinkStage.result => _Result(s),
              },
            ),
          ),
        ),
      );
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton(this.onTap);

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Back',
        onPressed: onTap,
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: G.ink),
        style: IconButton.styleFrom(backgroundColor: G.card, minimumSize: const Size(46, 46)),
      );
}

class _Message extends StatelessWidget {
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  const _Message({required this.title, required this.body, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Spacer(),
        Text(title, style: G.text(40, w: FontWeight.w600, height: 1.08, letterSpacing: -1)),
        const SizedBox(height: 12),
        Text(body, style: G.text(19, color: G.muted, height: 1.36)),
        const Spacer(),
        GPill(action, primary: true, onTap: onAction),
      ]);
}

class _Bar extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;
  const _Bar({required this.label, required this.value, required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: G.text(18, height: 1.25))),
          const SizedBox(width: 10),
          Text(value, style: G.text(18, w: FontWeight.w600, height: 1.25)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: fraction, minHeight: 16, backgroundColor: G.card, valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
      ]);
}

class _Summary extends StatelessWidget {
  final ShrinkState s;
  const _Summary(this.s);

  @override
  Widget build(BuildContext context) {
    final most = s.weeklyMinutes > s.freeMinutes ? s.weeklyMinutes : s.freeMinutes;
    final over = s.weeklyMinutes > s.freeMinutes;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerLeft, child: _BackButton(() => Navigator.of(context).pop())),
      Expanded(
        child: ListView(children: [
          const SizedBox(height: 18),
          Text('You have ${s.count} ${s.count == 1 ? 'thing' : 'things'} on your list.', style: G.text(20, color: G.muted, height: 1.3)),
          const SizedBox(height: 8),
          Text(over ? 'No wonder it feels heavy.' : "It fits, but let's check it still matters.",
              style: G.text(44, w: FontWeight.w600, height: 1.06, letterSpacing: -1.3)),
          const SizedBox(height: 36),
          _Bar(label: 'What it would take', value: hoursText(s.weeklyMinutes), fraction: most == 0 ? 0 : s.weeklyMinutes / most, color: G.accent),
          const SizedBox(height: 26),
          _Bar(label: 'Free time in a week', value: hoursText(s.freeMinutes), fraction: most == 0 ? 0 : s.freeMinutes / most, color: G.ink),
          const SizedBox(height: 28),
          Text(over ? "It was never about being lazy. Let's choose what gets your time." : "Let's make sure your time goes to what matters most.",
              style: G.text(20, height: 1.36)),
        ]),
      ),
      GPill("Let's choose together", primary: true, onTap: context.read<ShrinkCubit>().begin),
      const SizedBox(height: 12),
      Text('Nothing gets deleted. You can change this anytime.', textAlign: TextAlign.center, style: G.text(15, color: G.muted, height: 1.3)),
    ]);
  }
}

class _Deciding extends StatelessWidget {
  final ShrinkState s;
  const _Deciding(this.s);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShrinkCubit>();
    final item = s.current!;
    final ink = G.onInk;
    final position = s.decided.length + 1;
    final eyebrow = item.dueLine ?? item.ageLine;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _BackButton(cubit.back),
        const Spacer(),
        TextButton(
          onPressed: cubit.finishEarly,
          style: TextButton.styleFrom(foregroundColor: G.muted, minimumSize: const Size(44, 46)),
          child: Text('Enough for now', style: G.text(16, color: G.muted, height: 1.2)),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: position / s.items.length,
              minHeight: 5,
              backgroundColor: G.card,
              valueColor: AlwaysStoppedAnimation<Color>(G.accent),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$position of ${s.items.length}', style: G.text(16, color: G.muted, height: 1.2)),
      ]),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
              decoration: BoxDecoration(
                color: G.accent,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 50, offset: Offset(0, 22))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (eyebrow != null) ...[
                  Text(eyebrow, style: G.text(16, w: FontWeight.w500, color: ink, height: 1.2)),
                  const SizedBox(height: 12),
                ],
                Text(item.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: G.text(item.title.length <= 24 ? 46 : (item.title.length <= 50 ? 36 : 28), w: FontWeight.w600, color: ink, height: 1.05, letterSpacing: -1)),
                const SizedBox(height: 14),
                Text(item.needs, style: G.text(18, color: ink, height: 1.34)),
              ]),
            ),
          ),
        ),
      ),
      GPill('Keep in focus', primary: true, onTap: s.busy ? null : cubit.keep),
      const SizedBox(height: 10),
      SizedBox(
        height: 62,
        child: TextButton(
          onPressed: s.busy ? null : cubit.park,
          style: TextButton.styleFrom(backgroundColor: G.surfaceHigh, foregroundColor: G.ink, shape: const StadiumBorder()),
          child: Text('Park until ${s.parkLabel}', style: G.text(18, w: FontWeight.w500, height: 1.2)),
        ),
      ),
      if (s.canLetGo)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TextButton(
            onPressed: s.busy
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    cubit.letGo();
                  },
            style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 50)),
            child: Text('Let it go', style: G.text(17, height: 1.2)),
          ),
        ),
    ]);
  }
}

class _Result extends StatelessWidget {
  final ShrinkState s;
  const _Result(this.s);

  @override
  Widget build(BuildContext context) {
    final removed = s.parked.length + s.letGo.length;
    final headline = removed == 0 ? 'Nothing had to go.' : (s.fits ? 'Much lighter now.' : 'Getting lighter.');
    final detail = s.fits
        ? 'This fits inside your ${hoursText(s.freeMinutes)}.'
        : 'Still about ${hoursText(s.remainingMinutes - s.freeMinutes)} more than you have. You can do another round anytime.';
    final untouched = s.count - s.decided.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(children: [
          const SizedBox(height: 28),
          Text(headline, style: G.text(46, w: FontWeight.w600, height: 1.05, letterSpacing: -1.4)),
          const SizedBox(height: 12),
          Text(detail, style: G.text(20, color: G.muted, height: 1.36)),
          const SizedBox(height: 24),
          for (final i in s.kept.take(3))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                Expanded(child: Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: G.text(23, w: FontWeight.w600, color: G.onInk, height: 1.15))),
                const SizedBox(width: 12),
                Text(hoursText(i.weeklyMinutes), style: G.text(16, color: G.onInk, height: 1.2)),
              ]),
            ),
          if (s.parked.isNotEmpty) _CountRow('Parked safely', s.parked.length),
          if (s.letGo.isNotEmpty) _CountRow('Let go', s.letGo.length),
          if (untouched > 0) _CountRow('Not looked at yet', untouched),
        ]),
      ),
      GPill("Show me what's first", primary: true, onTap: () => Navigator.of(context).pop()),
    ]);
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int count;
  const _CountRow(this.label, this.count);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(child: Text(label, style: G.text(18, height: 1.25))),
          Text('$count', style: G.text(18, height: 1.25)),
        ]),
      );
}
