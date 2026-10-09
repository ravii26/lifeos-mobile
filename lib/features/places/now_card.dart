import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../guide/guide_style.dart';
import 'now_cubit.dart';

/// Now, the home place (ADR 0021): the day as a strip, the right thing as one
/// sentence, one big Done, and two quiet words. Nothing here counts or scolds.
///
/// [compact] is the one-line version that sits above a conversation.
class NowCard extends StatelessWidget {
  final bool compact;
  const NowCard({super.key, this.compact = false});

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
      why = o.why.isEmpty ? null : o.why;
      if (o.smaller && o.title != sentence) why = [?why, 'The small version of: ${o.title}'].join('. ');
      if (s.later.isNotEmpty) then = s.later.map((l) => l.title.toLowerCase()).join(' · ');
    }

    final isLateNight = now.hour >= 21 || now.hour < 5;
    final greeting = isLateNight ? 'Aaj ka aakhri kadam.' : 'Aaj ka agla kadam.';
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
                  Text('Sab shaant hai', style: G.voice(15, color: G.ink)),
                  Text(
                    '${DateFormat('h:mm a').format(now)} · ${DayStrip.partName(part)}',
                    style: G.label(size: 11, color: G.faint),
                  ),
                ]),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Hinglish', style: G.label(size: 11, color: G.muted)),
              ),
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
                children: [
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
                        Text('ONE THING FOR RIGHT NOW',
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

                      // Priority / Context Meta
                      if (picking)
                        Row(children: [
                          Text('Priority focus', style: G.label(size: 11, color: G.faint)),
                          Text('  •  ', style: G.label(size: 11, color: G.line)),
                          Text('Quiet cadence', style: G.label(size: 11, color: G.faint)),
                        ]),

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
                            Text('Kal subah ready.', style: G.label(size: 11, color: G.faint)),
                          ]),
                        ),
                      ]),
                    ),
                  ],

                  if (s.note != null) ...[
                    const SizedBox(height: 12),
                    Text(s.note!, style: G.text(13, color: G.muted, height: 1.5)),
                  ],

                  if (s.undoId != null) _UndoLine(onUndo: cubit.undo),

                  // Reassuring Sleep Status Capsule
                  const SizedBox(height: 20),
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: G.good.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: 8),
                      Text('Sab shaant hai. Rest when you are ready.',
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
              // Secondary Grid
              Row(children: [
                Expanded(
                  child: _ThumbAction(
                    icon: Icons.compress_rounded,
                    label: o.smaller ? 'Small version active' : 'Smaller',
                    onTap: s.busy || o.smaller ? null : cubit.smaller,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThumbAction(
                    icon: Icons.snooze_rounded,
                    label: isLateNight ? 'Not tonight' : 'Not now',
                    onTap: s.busy ? null : cubit.notNow,
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
