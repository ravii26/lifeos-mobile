import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/models/tonight.dart';
import '../shell/life_cubit.dart' show LoadStatus;
import 'guide_setup_sheet.dart';
import 'save_sheet.dart';
import 'guide_style.dart';
import 'tonight_cubit.dart';

/// Home tab: tonight's one thing, why it matters, its 2-minute minimum, and
/// one-tap answers. The same answers exist on the nightly notification.
class TonightScreen extends StatelessWidget {
  const TonightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: G.bg,
      child: SafeArea(
        bottom: false,
        child: BlocConsumer<TonightCubit, TonightState>(
          listenWhen: (a, b) => b.error != null && a.error != b.error,
          listener: (context, s) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(s.error!))),
          builder: (context, s) {
            final cubit = context.read<TonightCubit>();
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _Header(onSetup: () => openGuideSetup(context)),
                  const SizedBox(height: 18),
                  ..._body(context, s),
                  if (s.tonight != null) ...[
                    const SizedBox(height: 28),
                    _SavedPrompt(onTap: () async {
                      if (await openPasteSave(context)) await cubit.load();
                    }),
                  ],
                  if (s.history != null) ...[
                    const SizedBox(height: 12),
                    _Week(history: s.history!),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, TonightState s) {
    if (s.status == LoadStatus.loading || s.status == LoadStatus.initial) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: G.ink, strokeWidth: 2)),
      ];
    }
    if (s.status == LoadStatus.error && s.tonight == null) {
      return [
        Text("Couldn't reach your guide.", style: G.display(28)),
        const SizedBox(height: 10),
        Text(s.error ?? 'Check your connection and try again.', style: G.text(16, color: G.muted)),
        const SizedBox(height: 20),
        GButton('Try again', onTap: context.read<TonightCubit>().load),
      ];
    }
    final tonight = s.tonight!;
    final c = tonight.commitment;
    if (c == null) return _empty(context, tonight);
    return c.isPending ? _pending(context, s, c, tonight) : _answered(context, s, c);
  }

  List<Widget> _empty(BuildContext context, Tonight t) => [
        Text('Nothing to pick from yet.', style: G.display(32)),
        const SizedBox(height: 12),
        Text(t.emptyMessage ?? '', style: G.voice(18)),
        const SizedBox(height: 24),
        GButton('Set up my guide', onTap: () => openGuideSetup(context)),
      ];

  List<Widget> _pending(BuildContext context, TonightState s, Commitment c, Tonight t) {
    final cubit = context.read<TonightCubit>();
    return [
      Text(
        c.isSmaller ? 'AFTER ${t.missedNights} MISSED NIGHTS' : 'TONIGHT, ONE THING',
        style: G.label(),
      ),
      const SizedBox(height: 8),
      Text(c.isSmaller ? c.minimum : c.title, style: G.display(34)),
      const SizedBox(height: 14),
      Text(c.message, style: G.voice(18)),
      const SizedBox(height: 18),
      _Card(
        color: G.tint,
        label: 'WHY IT MATTERS',
        labelColor: G.tintInk,
        child: Text(c.why, style: G.text(16, color: G.tintInk, w: FontWeight.w500)),
      ),
      if (!c.isSmaller) ...[
        const SizedBox(height: 10),
        _Card(
          color: G.card,
          label: 'TIRED? THE MINIMUM COUNTS',
          child: Text(c.minimum, style: G.text(16, w: FontWeight.w500)),
        ),
      ],
      const SizedBox(height: 22),
      GButton(c.isSmaller ? 'Done, I did it' : 'Done',
          onTap: s.busy ? null : () => cubit.respond('DONE')),
      if (!c.isSmaller) ...[
        const SizedBox(height: 8),
        GButton('I did the minimum',
            primary: false, onTap: s.busy ? null : () => cubit.respond('MINIMUM')),
      ],
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextButton(
            onPressed: s.busy ? null : () => _askSkip(context),
            child: Text('Not tonight', style: G.text(15, color: G.muted, w: FontWeight.w700)),
          ),
        ),
        Expanded(
          child: TextButton(
            onPressed: s.busy ? null : cubit.swap,
            child: Text('Give me another', style: G.text(15, color: G.muted, w: FontWeight.w700)),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _answered(BuildContext context, TonightState s, Commitment c) {
    final skipped = c.status == 'SKIPPED';
    final cubit = context.read<TonightCubit>();
    return [
      Text(
        switch (c.status) {
          'DONE' => 'Counted.',
          'MINIMUM' => 'The minimum counts.',
          _ => 'Okay. No guilt.',
        },
        style: G.display(36),
      ),
      const SizedBox(height: 12),
      Text(
        skipped
            ? "Tomorrow's version will be smaller, so it's easy to start."
            : "That's a follow-through day. ${c.title}.",
        style: G.voice(18),
      ),
      if (s.next != null && !skipped) ...[
        const SizedBox(height: 24),
        _Card(
          color: G.card,
          label: 'GOT ENERGY LEFT? ONE MORE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.next!.title, style: G.display(22, w: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(s.next!.why, style: G.text(14, color: G.muted)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GButton('Not now', primary: false, onTap: cubit.dismissNext),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GButton('Done', onTap: s.busy ? null : cubit.completeNext),
                ),
              ]),
            ],
          ),
        ),
      ],
    ];
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

class _Header extends StatelessWidget {
  final VoidCallback onSetup;
  const _Header({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
            style: G.text(14, color: G.muted, w: FontWeight.w700)),
      ),
      IconButton(
        tooltip: 'Set up your guide',
        onPressed: onSetup,
        icon: const Icon(Icons.tune_rounded, color: G.ink),
      ),
    ]);
  }
}

/// Entry point for the save → action flow when the person didn't come in
/// through the share sheet.
class _SavedPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _SavedPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: G.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SAVED A VIDEO OR REEL?', style: G.label()),
                  const SizedBox(height: 4),
                  Text('Turn it into one action', style: G.display(19, w: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Or share it to Ally from any app.',
                      style: G.text(14, color: G.muted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: G.ink),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Color color;
  final String label;
  final Color labelColor;
  final Widget child;
  const _Card({
    required this.color,
    required this.label,
    required this.child,
    this.labelColor = G.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: G.label(color: labelColor)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// Last 7 nights, planned vs. did.
class _Week extends StatelessWidget {
  final GuideHistory history;
  const _Week({required this.history});

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in history.days) d.date: d.status};
    final today = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final fmt = DateFormat('yyyy-MM-dd');
    final followed = days
        .where((d) => const {'DONE', 'MINIMUM'}.contains(byDate[fmt.format(d)]))
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 7 NIGHTS', style: G.label()),
          const SizedBox(height: 4),
          Text('$followed of 7 followed through', style: G.display(20, w: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final d in days)
                Column(children: [
                  _Dot(status: byDate[fmt.format(d)]),
                  const SizedBox(height: 6),
                  Text(DateFormat('E').format(d).substring(0, 1),
                      style: G.text(12, color: G.muted, w: FontWeight.w700)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final String? status;
  const _Dot({this.status});

  @override
  Widget build(BuildContext context) {
    final (fill, border, mark) = switch (status) {
      'DONE' => (G.good, G.good, Icons.check_rounded),
      'MINIMUM' => (G.goodSoft, G.good, Icons.remove_rounded),
      'SKIPPED' => (G.card, G.line, Icons.close_rounded),
      'PENDING' => (G.card, G.ink, null),
      _ => (G.soft, G.soft, null),
    };
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: mark == null
          ? null
          : Icon(mark, size: 18, color: status == 'DONE' ? Colors.white : G.muted),
    );
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
          Text('One tap. It helps me plan a version you will actually do.', style: G.voice(16)),
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
          GButton('Skip tonight', onTap: () => Navigator.pop(context, _ctrl.text)),
        ],
      ),
    );
  }
}
