import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// What a feeling leads to. The sheet pops with one of these, or null.
enum FeelingAction { easyDay, startTwoMinutes, freeTime, talk, decide, rest }

/// One feeling: a kind line, one small thing to do, and a way forward.
/// All written here, so it works offline and without AI.
class Feeling {
  final String key;
  final String label;
  final String line;
  final String smallThing;
  final String? actionLabel;
  final FeelingAction? action;

  /// Low and anxious moments also show where to talk to someone now.
  final bool helpline;
  final bool breathe;

  const Feeling(this.key, this.label, this.line, this.smallThing, {this.actionLabel, this.action, this.helpline = false, this.breathe = false});
}

const feelings = <Feeling>[
  Feeling('low', 'Low', 'Low days happen. Nothing needs proving today.', 'Drink a glass of water and step outside for two minutes.',
      actionLabel: 'Make today easy', action: FeelingAction.easyDay, helpline: true),
  Feeling('stuck', "Can't start", "Starting is the hardest part, not the work.", 'Do only the first two minutes of the next thing. You can stop after.',
      actionLabel: 'Start two minutes', action: FeelingAction.startTwoMinutes),
  Feeling('scrolling', 'Scrolling', "Your attention got pulled. That's what those apps are built to do.",
      'Put the phone face down, stand up, then pick one thing.', actionLabel: 'Show me one thing', action: FeelingAction.freeTime),
  Feeling('overthinking', 'Overthinking', "Thinking more won't make it clearer. Doing a small part will.",
      'Write the options down, then give the easiest one ten minutes.', actionLabel: 'Help me decide', action: FeelingAction.decide),
  Feeling('anxious', 'Anxious', 'That feeling is real, and it will pass.', 'Breathe in for four, out for six. Five times.',
      helpline: true, breathe: true, actionLabel: 'Make today easy', action: FeelingAction.easyDay),
  Feeling('good', 'Good', 'Good. Use it on something that matters to you.', 'Pick the thing you have been putting off and give it real time.',
      actionLabel: "I've got time", action: FeelingAction.freeTime),
];

/// India's free, 24×7 government mental health line.
const helplineName = 'Tele-MANAS';
const helplineNumber = '14416';

/// "I'm feeling…": pick a feeling, get a kind line and one small thing.
class FeelingSheet extends StatefulWidget {
  const FeelingSheet({super.key});

  @override
  State<FeelingSheet> createState() => _FeelingSheetState();
}

class _FeelingSheetState extends State<FeelingSheet> {
  Feeling? _f;

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final f = _f;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text("I'm feeling…", style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x3),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
        for (final x in feelings) AllyChip(x.label, selected: f?.key == x.key, onTap: () => setState(() => _f = x)),
      ]),
      AnimatedSwitcher(
        duration: Motion.of(context, Motion.d3),
        child: f == null
            ? const SizedBox(height: Sp.x2)
            : Column(key: ValueKey(f.key), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: Sp.x5),
                Text(f.line, style: AllyType.h2(color: c.ink)),
                const SizedBox(height: Sp.x3),
                Text('ONE SMALL THING', style: AllyType.eyebrow(color: c.faint)),
                const SizedBox(height: Sp.x1),
                Text(f.smallThing, style: AllyType.body(color: c.ink)),
                if (f.breathe) ...[const SizedBox(height: Sp.x4), const _Breathe()],
                const SizedBox(height: Sp.x4),
                if (f.action != null) AllyButton(f.actionLabel!, wide: true, onPressed: () => Navigator.of(context).pop(f.action)),
                AllyButton('Just rest for now', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop(FeelingAction.rest)),
                if (f.helpline) ...[
                  const SizedBox(height: Sp.x3),
                  AllyCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('If it feels like too much, you can talk to someone now.', style: AllyType.body(color: c.ink)),
                      const SizedBox(height: Sp.x1),
                      Text('$helplineName: $helplineNumber. Free, any time, in India.', style: AllyType.small(color: c.muted)),
                      const SizedBox(height: Sp.x3),
                      AllyButton('Call $helplineNumber',
                          kind: AllyButtonKind.secondary,
                          icon: Icons.call_outlined,
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: helplineNumber)).catchError((_) => false)),
                    ]),
                  ),
                ],
              ]),
      ),
    ]);
  }
}

/// A slow breath to follow: in for four, out for six. Still with reduced motion.
class _Breathe extends StatefulWidget {
  const _Breathe();

  @override
  State<_Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<_Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 10));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    // One steady instruction for a screen reader, not a word that changes every few seconds.
    return Semantics(
      container: true,
      label: 'Breathe in for four seconds, out for six.',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final inhale = t < 0.4;
          // Grows over four seconds, shrinks over six.
          final scale = inhale ? 0.6 + 0.4 * Curves.easeInOut.transform(t / 0.4) : 1 - 0.4 * Curves.easeInOut.transform((t - 0.4) / 0.6);
          return Column(children: [
            SizedBox(
              height: 120,
              child: Center(
                child: Container(
                  width: 110 * scale,
                  height: 110 * scale,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.raised, border: Border.all(color: c.line, width: 2)),
                ),
              ),
            ),
            Text(Motion.reduced(context) ? 'In for four, out for six' : (inhale ? 'Breathe in' : 'Breathe out'), style: AllyType.body(color: c.muted)),
          ]);
        },
      ),
    );
  }
}

/// A different day: what kind, and for how long. Pops with (mode, days), or
/// ('NORMAL', 0) to go back to a normal day.
class DifferentDaySheet extends StatefulWidget {
  final String current;
  const DifferentDaySheet({super.key, required this.current});

  @override
  State<DifferentDaySheet> createState() => _DifferentDaySheetState();
}

class _DifferentDaySheetState extends State<DifferentDaySheet> {
  static const _kinds = [
    ('SICK', 'Unwell', 'Nothing is asked of you. Rest is the plan.'),
    ('TRAVEL', 'Travelling', 'Only small things that need no desk.'),
    ('BUSY', 'Busy, office late', 'The smallest version counts.'),
    ('HOLIDAY', 'On holiday', 'Plans pause; nothing piles up.'),
  ];
  static const _lengths = [(1, 'Today'), (3, 'A few days'), (7, 'A week')];

  String? _mode;
  int _days = 1;

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final chosen = _kinds.where((k) => k.$1 == _mode).firstOrNull;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('A different day', style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x1),
      Text('Today gets re-planned to fit. It goes back to normal by itself.', style: AllyType.body(color: c.muted)),
      const SizedBox(height: Sp.x4),
      Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
        for (final (m, label, _) in _kinds) AllyChip(label, selected: _mode == m, onTap: () => setState(() => _mode = m)),
      ]),
      if (chosen != null) ...[
        const SizedBox(height: Sp.x2),
        Text(chosen.$3, style: AllyType.small(color: c.faint)),
        const SizedBox(height: Sp.x4),
        Text('FOR', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x2),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final (d, label) in _lengths) AllyChip(label, selected: _days == d, onTap: () => setState(() => _days = d)),
        ]),
      ],
      const SizedBox(height: Sp.x5),
      AllyButton(chosen == null ? 'Pick what kind of day' : 'Re-plan for ${chosen.$2.toLowerCase()}',
          wide: true, onPressed: chosen == null ? null : () => Navigator.of(context).pop<(String, int)>((_mode!, _days))),
      if (widget.current != 'NORMAL')
        AllyButton('Back to a normal day', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop<(String, int)>(('NORMAL', 0))),
    ]);
  }
}

/// "Travelling" and so on, for the banner on Today.
String modeWords(String mode) => switch (mode) {
      'TRAVEL' => 'Travelling: only small things that need no desk.',
      'BUSY' => 'A busy day: the smallest version counts.',
      'HOLIDAY' => 'On holiday: plans are paused.',
      _ => '',
    };
