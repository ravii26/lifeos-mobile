import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/models/tonight.dart';
import '../shell/life_cubit.dart' show LoadStatus;
import 'guide_setup_sheet.dart';
import 'guide_style.dart';
import 'tonight_cubit.dart';

/// Today's one thing, pinned at the top of Chat. One tap to answer; tap the
/// card's header to fold it into a single line when you want room to talk.
class TonightCard extends StatefulWidget {
  const TonightCard({super.key});

  @override
  State<TonightCard> createState() => _TonightCardState();
}

class _TonightCardState extends State<TonightCard> {
  bool _folded = false;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TonightCubit, TonightState>(
      listenWhen: (a, b) => b.error != null && a.error != b.error,
      listener: (context, s) =>
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!))),
      builder: (context, s) {
        final child = _content(context, s);
        if (child == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }

  Widget? _content(BuildContext context, TonightState s) {
    if (s.status == LoadStatus.initial || s.status == LoadStatus.loading) {
      return _Shell(child: Text("Picking today's one thing…", style: G.voice(15)));
    }
    final tonight = s.tonight;
    if (tonight == null) return null; // offline/error: chat still works
    final c = tonight.commitment;
    if (c == null) {
      return _Shell(
        child: Row(children: [
          Expanded(
            child: Text('Tell me what matters and I\'ll pick one small thing for you each day.',
                style: G.text(14, color: G.muted)),
          ),
          const SizedBox(width: 8),
          _Small('Set up', onTap: () => openGuideSetup(context)),
        ]),
      );
    }
    if (_folded) return _foldedBar(c);
    return c.isPending ? _pending(context, s, c, tonight) : _answered(context, s, c);
  }

  Widget _foldedBar(Commitment c) => InkWell(
        onTap: () => setState(() => _folded = false),
        borderRadius: BorderRadius.circular(16),
        child: _Shell(
          dense: true,
          child: Row(children: [
            Icon(
              c.isPending ? Icons.radio_button_unchecked : Icons.check_circle_rounded,
              size: 18,
              color: c.isPending ? G.ink : G.good,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.isPending ? 'Today: ${c.title}' : 'Today: done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: G.text(14, w: FontWeight.w700)),
            ),
            const Icon(Icons.expand_more_rounded, color: G.muted),
          ]),
        ),
      );

  Widget _header(String label, TonightState s) => InkWell(
        onTap: () => setState(() => _folded = true),
        child: Row(children: [
          Expanded(child: Text(label, style: G.label())),
          if (s.history != null) _Dots(history: s.history!),
          const SizedBox(width: 4),
          const Icon(Icons.expand_less_rounded, size: 20, color: G.muted),
        ]),
      );

  Widget _pending(BuildContext context, TonightState s, Commitment c, Tonight t) {
    final cubit = context.read<TonightCubit>();
    return _Shell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(c.isSmaller ? 'AFTER ${t.missedNights} MISSED NIGHTS · JUST THIS' : "TODAY'S ONE THING", s),
        const SizedBox(height: 6),
        Text(c.isSmaller ? c.minimum : c.title, style: G.display(20, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(c.why, style: G.voice(14)),
        if (!c.isSmaller) ...[
          const SizedBox(height: 6),
          Text('Tired? Minimum: ${c.minimum}', style: G.text(13, color: G.muted)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _Small('Done', primary: true, onTap: s.busy ? null : () => cubit.respond('DONE')),
          ),
          if (!c.isSmaller) ...[
            const SizedBox(width: 6),
            Expanded(
              child: _Small('Did the minimum', onTap: s.busy ? null : () => cubit.respond('MINIMUM')),
            ),
          ],
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded, color: G.muted),
            color: G.card,
            onSelected: (v) => v == 'skip' ? _askSkip(context) : cubit.swap(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'skip', child: Text('Not today', style: G.text(15))),
              PopupMenuItem(value: 'swap', child: Text('Give me another', style: G.text(15))),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _answered(BuildContext context, TonightState s, Commitment c) {
    final cubit = context.read<TonightCubit>();
    final skipped = c.status == 'SKIPPED';
    return _Shell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(
            switch (c.status) {
              'DONE' => 'COUNTED',
              'MINIMUM' => 'THE MINIMUM COUNTS',
              _ => 'OKAY. NO GUILT.',
            },
            s),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text(skipped ? "Tomorrow's version will be easier to start." : c.title,
                style: G.text(15, w: FontWeight.w600)),
          ),
          if (cubit.canUndo)
            TextButton(
              onPressed: s.busy ? null : cubit.undoLast,
              child: Text('Undo', style: G.text(14, w: FontWeight.w700, color: G.muted)),
            ),
        ]),
        if (s.next != null && !skipped) ...[
          const SizedBox(height: 10),
          Text('Energy left? One more: ${s.next!.title}', style: G.voice(14, color: G.ink)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Small('Done', primary: true, onTap: s.busy ? null : cubit.completeNext)),
            const SizedBox(width: 6),
            Expanded(child: _Small('Not now', onTap: cubit.dismissNext)),
          ]),
        ],
      ]),
    );
  }

  Future<void> _askSkip(BuildContext context) async {
    final cubit = context.read<TonightCubit>();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: G.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SkipSheet(),
    );
    if (reason != null) await cubit.respond('SKIPPED', reason: reason);
  }
}

class _Shell extends StatelessWidget {
  final Widget child;
  final bool dense;
  const _Shell({required this.child, this.dense = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: dense ? const EdgeInsets.fromLTRB(14, 10, 8, 10) : const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: G.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: G.line),
        ),
        child: child,
      );
}

class _Small extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  const _Small(this.label, {this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: primary ? G.ink : G.soft,
            foregroundColor: primary ? Colors.white : G.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: G.text(14, w: FontWeight.w700, color: primary ? Colors.white : G.ink)),
        ),
      );
}

/// Last 7 days as tiny dots: done / minimum / skipped / nothing.
class _Dots extends StatelessWidget {
  final GuideHistory history;
  const _Dots({required this.history});

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in history.days) d.date: d.status};
    final fmt = DateFormat('yyyy-MM-dd');
    final today = DateTime.now();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 6; i >= 0; i--)
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (byDate[fmt.format(today.subtract(Duration(days: i)))]) {
              'DONE' => G.good,
              'MINIMUM' => G.good.withValues(alpha: 0.45),
              'SKIPPED' => G.line,
              _ => G.soft,
            },
          ),
        ),
    ]);
  }
}

class _SkipSheet extends StatefulWidget {
  const _SkipSheet();

  @override
  State<_SkipSheet> createState() => _SkipSheetState();
}

class _SkipSheetState extends State<_SkipSheet> {
  final _ctrl = TextEditingController();
  static const _reasons = ['Too tired', 'No time today', 'Not feeling it', 'Ended up on my phone'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What got in the way?', style: G.display(26)),
          const SizedBox(height: 6),
          Text('One tap. It helps me pick a version you will actually do.', style: G.voice(16)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _reasons)
              ActionChip(
                label: Text(r, style: G.text(15, w: FontWeight.w500)),
                backgroundColor: G.card,
                side: const BorderSide(color: G.line),
                shape: const StadiumBorder(),
                onPressed: () => Navigator.pop(context, r),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            style: G.text(16),
            decoration: InputDecoration(
              hintText: 'Or say it in your words',
              hintStyle: G.text(16, color: G.muted),
              filled: true,
              fillColor: G.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          GButton('Skip today', onTap: () => Navigator.pop(context, _ctrl.text)),
        ],
      ),
    );
  }
}
