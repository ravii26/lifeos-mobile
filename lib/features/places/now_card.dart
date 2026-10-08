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
      if (s.later.isNotEmpty) then = 'Then: ${s.later.map((l) => l.title.toLowerCase()).join(', ')}.';
    }
    final minutes = picking && o.minutes > 0 ? ' You have ${o.minutes} minutes.' : '';

    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(DateFormat('EEEE d MMMM').format(now), style: G.text(13, color: G.muted)),
              Row(children: [
                Container(width: 8, height: 8, color: G.part(part)),
                const SizedBox(width: 6),
                Text(DayStrip.partName(part), style: G.text(13, color: G.muted)),
              ]),
            ]),
            const SizedBox(height: 16),
            DayStrip(now: now),
            const SizedBox(height: 12),
            Text('${DateFormat('h:mm a').format(now).toLowerCase()}.$minutes', style: G.text(13, color: G.muted)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 44, 24, 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(sentence),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.prep.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text("Tonight's prep: ${s.prep.join('; ')}.", style: G.voice(16)),
                    ),
                  Text(sentence, style: G.voice(36, color: s.status == NowStatus.loading ? G.muted : G.ink)),
                  if (why != null) ...[
                    const SizedBox(height: 14),
                    Text(why, style: G.text(15, color: G.muted, height: 1.5)),
                  ],
                  if (then != null) ...[
                    const SizedBox(height: 22),
                    Text(then, style: G.text(13, color: G.muted)),
                  ],
                  if (s.note != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(s.note!, style: G.text(13, color: G.muted, height: 1.5))),
                  if (s.undoId != null) _UndoLine(onUndo: cubit.undo),
                ],
              ),
            ),
          ),
        ),
        if (picking)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: s.busy
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          cubit.done();
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: G.ink,
                    foregroundColor: G.onInk,
                    disabledBackgroundColor: G.ink.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('Done', style: G.text(17, w: FontWeight.w700, color: G.onInk)),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _Quiet('Smaller', s.busy ? null : cubit.smaller)),
                Expanded(child: _Quiet('Not now', s.busy ? null : cubit.notNow)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _Quiet extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Quiet(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: G.muted, shape: const RoundedRectangleBorder()),
          child: Text(label, style: G.text(15, w: FontWeight.w500, color: G.muted)),
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
          Text('Logged. ', style: G.text(13, color: G.muted)),
          InkWell(onTap: onUndo, child: Text('Undo', style: G.text(13, w: FontWeight.w700))),
        ]),
      );
}
