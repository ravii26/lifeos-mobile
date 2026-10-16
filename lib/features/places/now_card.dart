import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../chat/starters.dart';
import '../guide/guide_style.dart';
import 'now_cubit.dart';

/// Now, the home place (ADR 0021): the day as a strip, the right thing as one
/// sentence, one big Done, and two quiet words. Nothing here counts or scolds.
///
/// [compact] is the one-line version that sits above a conversation.
class NowCard extends StatelessWidget {
  final bool compact;
  // Nobody has told Ally anything yet: say hello instead of "nothing waiting".
  final bool fresh;
  // The four starters, shown whenever there is nothing to do right now.
  final ValueChanged<Starter>? onStarter;
  const NowCard({super.key, this.compact = false, this.fresh = false, this.onStarter});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NowCubit, NowState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!))),
      builder: (context, s) => compact ? _compact(context, s) : _full(context, s),
    );
  }

  // ---- compact: "Now / title ........ Done" -----------------------------------------------

  Widget _compact(BuildContext context, NowState s) {
    final o = s.current;
    final cubit = context.read<NowCubit>();
    if (o == null || s.kind != 'PICK') return const SizedBox.shrink();
    final shown = o.smaller ? o.minimum.replaceAll(RegExp(r'\.$'), '') : o.title;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Now', style: G.text(11, color: G.muted)),
            Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: G.text(15, w: FontWeight.w500)),
          ]),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: s.busy ? null : cubit.done,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Done', style: G.text(15, w: FontWeight.w700).copyWith(decoration: TextDecoration.underline, decorationThickness: 1.5)),
          ),
        ),
      ]),
    );
  }

  // ---- full ---------------------------------------------------------------------------------

  Widget _full(BuildContext context, NowState s) {
    final cubit = context.read<NowCubit>();
    final now = DateTime.now();
    final o = s.current;
    final picking = o != null && s.kind == 'PICK';
    final part = DayStrip.partOf(now);

    String sentence;
    String? why;
    String? then;
    if (s.status == NowStatus.loading) {
      sentence = 'Looking at your day…';
    } else if (s.status == NowStatus.error) {
      sentence = "I can't reach the server right now.";
      why = 'Chat still works, and I will have your day when it is back.';
    } else if (!picking) {
      sentence = s.options.isEmpty ? s.message : "That's all I'd suggest right now.";
      if (s.options.isNotEmpty) why = 'Rest is fine too.';
    } else {
      sentence = o.smaller ? o.minimum.replaceAll(RegExp(r'\.$'), '') : o.title;
      // A deadline taking the rest of today: the message says what waits.
      why = s.focus ? s.message : (o.why.isEmpty ? null : o.why);
      if (o.smaller && o.title != sentence) why = [?why, 'The small version of: ${o.title}'].join('. ');
      if (s.later.isNotEmpty) then = s.later.map((l) => l.title.toLowerCase()).join(' · ');
    }

    final showStarters = !picking && s.status != NowStatus.loading && onStarter != null;
    final isLateNight = now.hour >= 21 || now.hour < 5;
    final greeting = isLateNight ? 'Last thing tonight' : 'Up next';
    final subtitle = isLateNight
        ? 'No catch-up. No penalty. Just winding down quietly.'
        : 'One thing at a time. The rest waits patiently.';

    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top Header matching Nocturne TopAppBar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(Icons.bedtime_outlined, size: 20, color: G.accent),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Now', style: G.voice(15, color: G.ink)),
                  Text(
                    '${DateFormat('h:mm a').format(now)} · ${DayStrip.partName(part)}',
                    style: G.label(size: 11, color: G.faint),
                  ),
                ]),
              ]),
            ]),
            const SizedBox(height: 12),
            // Segmented Day Strip
            DayStrip(now: now),
          ]),
        ),

        // Main Scrollable Canvas
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(sentence),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: showStarters
                    ? [_StartHere(fresh: fresh, state: s, onStarter: onStarter!)]
                    : [
                  // Greeting in Serif Italic
                  Text(greeting, style: G.voice(22, color: G.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: G.label(size: 12, color: G.faint)),
                  const SizedBox(height: 16),

                  // The Right-Now Focus Unit (Planar Card)
                  Container(
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Eyebrow
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Do this now',
                            style: G.label(size: 11, color: G.accent, w: FontWeight.w600)),
                        if (picking && o.minutes > 0)
                          Text('${o.minutes} mins', style: G.label(size: 11, color: G.faint)),
                      ]),
                      const SizedBox(height: 10),

                      // Task Heading
                      Text(
                        sentence,
                        style: G.text(18,
                            w: FontWeight.w500,
                            color: s.status == NowStatus.loading ? G.muted : G.ink,
                            height: 1.35),
                      ),
                      const SizedBox(height: 8),


                      // Why Context Whisper
                      if (why != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          decoration: BoxDecoration(
                            color: G.inset,
                            border: Border(left: BorderSide(color: G.accent, width: 2)),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                          ),
                          child: Text(
                            '“$why”',
                            style: G.voice(13.5, color: G.muted),
                          ),
                        ),
                      ],

                      // Next Preview Peeking Line
                      if (then != null) ...[
                        const SizedBox(height: 14),
                        Container(height: 0.5, color: G.lineSoft),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.navigate_next_rounded, size: 16, color: G.faint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              then,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: G.text(12, color: G.faint),
                            ),
                          ),
                          Text('NEXT', style: G.label(size: 10, color: G.faint)),
                        ]),
                      ],
                    ]),
                  ),

                  // Tonight's prep note (if any)
                  if (s.prep.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: G.inset,
                        border: Border.all(color: G.lineSoft, width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 10),
                          child: Icon(Icons.check_box_outline_blank_rounded, size: 16, color: G.carried),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("TONIGHT'S PREP", style: G.label(size: 10, color: G.carried, w: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(s.prep.join('; '), style: G.text(13, color: G.ink, height: 1.35)),
                            const SizedBox(height: 2),
                            Text('Ready for tomorrow morning.', style: G.label(size: 11, color: G.faint)),
                          ]),
                        ),
                      ]),
                    ),
                  ],

                  // The honest "not now" / "better way", with the person's choices.
                  if (s.advice != null) ...[
                    const SizedBox(height: 14),
                    _AdviceBox(advice: s.advice!, busy: s.busy, onChoice: cubit.adviceChoice),
                  ],

                  if (s.note != null) ...[
                    const SizedBox(height: 12),
                    Text(s.note!, style: G.text(13, color: G.muted, height: 1.5)),
                  ],

                  if (s.undoId != null) _UndoLine(onUndo: cubit.undo),

                  // Only when there's truly nothing asked of you.
                  if (!picking && s.status != NowStatus.loading) const SizedBox(height: 20),
                  if (!picking && s.status != NowStatus.loading) Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: G.good.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: 8),
                      Text('All calm. Rest when you are ready.',
                          style: G.label(size: 11, color: G.faint)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Action Trio in Bedside Thumb Zone
        if (picking)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(children: [
              // Primary Done Button: Sage Canopy styling
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: s.busy
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          cubit.done();
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: G.goodSoft,
                    foregroundColor: G.good,
                    side: BorderSide(color: G.good.withValues(alpha: 0.3), width: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: G.good),
                      const SizedBox(width: 8),
                      Text('Done', style: G.text(15, w: FontWeight.w600, color: G.good)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // One quiet choice; the rest is behind "More" so Done stays the obvious tap.
              Row(children: [
                Expanded(
                  child: _ThumbAction(
                    icon: Icons.snooze_rounded,
                    label: isLateNight ? 'Not tonight' : 'Not now',
                    onTap: s.busy ? null : cubit.notNow,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: PopupMenuButton<String>(
                    enabled: !s.busy,
                    tooltip: 'More',
                    onSelected: (v) => v == 'smaller' ? cubit.smaller() : cubit.lowEnergy(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'smaller',
                        enabled: !o.smaller,
                        child: Text(o.smaller ? 'Already the smallest version' : 'Make it smaller', style: G.text(14)),
                      ),
                      PopupMenuItem(
                        value: 'low',
                        enabled: !s.lowEnergy,
                        child: Text(s.lowEnergy ? 'Low energy today: on' : 'Low energy today', style: G.text(14)),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: G.card,
                        border: Border.all(color: G.lineSoft, width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('More', style: G.label(size: 11, color: G.muted, w: FontWeight.w500)),
                        Icon(Icons.expand_more_rounded, size: 16, color: G.faint),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _ThumbAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ThumbAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: G.card,
            foregroundColor: G.muted,
            side: BorderSide(color: G.lineSoft, width: 0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: G.faint),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: G.label(size: 11, color: G.muted, w: FontWeight.w500)),
              ),
            ],
          ),
        ),
      );
}

class _UndoLine extends StatelessWidget {
  final VoidCallback onUndo;
  const _UndoLine({required this.onUndo});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Text('Logged. ', style: G.label(size: 12, color: G.faint)),
          InkWell(
            onTap: onUndo,
            child: Text('Undo', style: G.label(size: 12, color: G.accent, w: FontWeight.w600)),
          ),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: G.inset,
          border: Border(left: BorderSide(color: G.carried, width: 2)),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(advice.message, style: G.text(14, color: G.ink, height: 1.4)),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (final (label, choice) in advice.actions)
              InkWell(
                onTap: busy ? null : () => onChoice(choice),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(label, style: G.label(size: 12.5, color: G.accent, w: FontWeight.w600)),
                ),
              ),
          ]),
        ]),
      );
}

/// Empty Now: Ally's hello and the four ways to start (doc 17). Big buttons,
/// one example each, and a line saying typing works too.
class _StartHere extends StatelessWidget {
  final bool fresh;
  final NowState state;
  final ValueChanged<Starter> onStarter;
  const _StartHere({required this.fresh, required this.state, required this.onStarter});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    if (state.status == NowStatus.error) {
      title = "I can't reach the server right now.";
      body = 'You can still start something; I will catch up when it is back.';
    } else if (fresh) {
      title = "Hi, I'm Ally.";
      body = "Tell me what you want to get done. I'll tell you what to do and when, one thing at a time. Pick one to start:";
    } else if (state.options.isNotEmpty) {
      title = "That's all I'd suggest right now.";
      body = 'Rest is fine. Or add something:';
    } else if (state.kind == 'REST') {
      title = state.message.isEmpty ? 'Time to rest.' : state.message;
      body = 'Want to add something for later?';
    } else {
      title = 'Nothing to do right now.';
      body = 'Rest is fine. Or add something:';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: G.voice(22, color: G.ink)),
      const SizedBox(height: 6),
      Text(body, style: G.text(14, color: G.muted, height: 1.45)),
      const SizedBox(height: 18),
      for (final st in nowStarters)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => onStarter(st),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: G.card,
                border: Border.all(color: G.line, width: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Icon(st.icon, size: 22, color: G.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.label, style: G.text(15.5, w: FontWeight.w600)),
                    Text(st.example, style: G.text(12.5, color: G.faint)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: G.faint),
              ]),
            ),
          ),
        ),
      const SizedBox(height: 6),
      Text('Or just type or say anything below, like "gym at 7 every day".', style: G.text(13, color: G.muted, height: 1.4)),
    ]);
  }
}
