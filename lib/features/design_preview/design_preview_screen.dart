import 'package:flutter/material.dart';

import '../../design/ally_theme.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// Every piece of the new design system on one page, with sample data, so it
/// can be judged on a real phone before screens are rebuilt with it.
/// Reached from Settings. Not part of the product; removed before launch.
class DesignPreviewScreen extends StatefulWidget {
  const DesignPreviewScreen({super.key});

  @override
  State<DesignPreviewScreen> createState() => _DesignPreviewScreenState();
}

class _DesignPreviewScreenState extends State<DesignPreviewScreen> {
  bool _dark = true;
  int _replay = 0;
  String _energy = 'normal';
  final Set<String> _picked = {'30 min'};
  bool _switch = true;
  final List<bool> _done = [true, false, false];
  bool _loading = false;
  double _focus = 0.35;

  // Sample areas only. A person's own areas replace these.
  static const _areas = ['Work', 'Health', 'Learning', 'Family', 'Money', 'Hobby'];
  static const _progress = [0.8, 0.55, 0.3, 0.9, 0.15, 0.45];
  static const _modes = ['Push', 'Maintain', 'Explore', 'Maintain', 'Rest', 'Explore'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? AllyTheme.dark() : AllyTheme.light(),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final c = context.ac;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Design preview'),
        actions: [
          IconButton(
            tooltip: 'Play the entrance again',
            icon: const Icon(Icons.replay_rounded),
            onPressed: () => setState(() => _replay++),
          ),
          IconButton(
            tooltip: _dark ? 'Switch to light' : 'Switch to dark',
            icon: Icon(_dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => setState(() => _dark = !_dark),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x2, Sp.side, Sp.x6),
        children: [
          Stagger(
            key: ValueKey(_replay),
            children: [
              _today(c),
              _freeCard(c),
              _list(c),
              _wheel(c),
              _areaRows(c),
              _controls(c),
              _focusCard(c),
              _states(c),
              _type(c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, AllyColors c, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x3),
          ...children,
        ],
      );

  Widget _today(AllyColors c) => _section('Day dial', c, [
        DayDial(
          key: ValueKey('dial$_replay'),
          now: 17 * 60 + 20,
          semanticLabel: 'Your day. Free from 6:30 to 8:00 this evening.',
          parts: [
            const DayPart(23 * 60, 6 * 60 + 30, DayPartKind.fixed),
            DayPart(7 * 60, 7 * 60 + 45, DayPartKind.planned, color: c.area(1)),
            const DayPart(9 * 60 + 30, 18 * 60, DayPartKind.fixed),
            const DayPart(18 * 60 + 30, 20 * 60, DayPartKind.free),
            DayPart(20 * 60 + 30, 21 * 60 + 15, DayPartKind.planned,
                color: c.area(3)),
            DayPart(21 * 60 + 45, 22 * 60 + 30, DayPartKind.planned,
                color: c.area(2)),
          ],
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('FREE AT 6:30', style: AllyType.eyebrow(color: c.freeInk)),
            const SizedBox(height: 4),
            Text('1h 30', style: AllyType.big(color: c.ink)),
            const SizedBox(height: 2),
            Text('this evening', style: AllyType.small(color: c.muted)),
          ]),
        ),
      ]);

  Widget _freeCard(AllyColors c) => _section('Free time', c, [
        AllyCard(
          free: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AreaLabel(_areas[2], color: c.area(2)),
              const SizedBox(height: Sp.x2),
              Text('Finish chapter 3 notes', style: AllyType.h2(color: c.ink)),
              const SizedBox(height: Sp.x1),
              Text('25 min. It fits before dinner.',
                  style: AllyType.body(color: c.muted)),
              const SizedBox(height: Sp.x4),
              AllyButton('Start',
                  kind: AllyButtonKind.free,
                  icon: Icons.play_arrow_rounded,
                  wide: true,
                  onPressed: () => showAllyToast(context, 'Started. 25 min.',
                      onUndo: () {})),
              const SizedBox(height: Sp.x1),
              AllyButton('Something else',
                  kind: AllyButtonKind.ghost, wide: true, onPressed: _openSheet),
            ],
          ),
        ),
      ]);

  Widget _list(AllyColors c) {
    const items = ['Morning walk', 'Call the bank', 'Read 10 pages'];
    const times = ['7:00', '13:15', '21:45'];
    return _section('Today', c, [
      AllyCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1),
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(color: c.line, height: 1),
            Row(children: [
              SizedBox(
                  width: 52,
                  child: Text(times[i], style: AllyType.num(color: c.faint))),
              Container(
                  width: 4,
                  height: 30,
                  decoration: BoxDecoration(
                      color: c.area(i + 1),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Text(items[i],
                    style: AllyType.body(
                            color: _done[i] ? c.faint : c.ink,
                            w: FontWeight.w500)
                        .copyWith(
                            decoration:
                                _done[i] ? TextDecoration.lineThrough : null)),
              ),
              AllyCheck(
                done: _done[i],
                semanticLabel: items[i],
                onTap: () => setState(() => _done[i] = !_done[i]),
              ),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _wheel(AllyColors c) => _section('Life wheel', c, [
        LifeWheel(
          key: ValueKey('wheel$_replay'),
          spokes: [
            for (var i = 0; i < _areas.length; i++)
              WheelSpoke(_areas[i], c.area(i), _progress[i]),
          ],
          onTap: (i) => showAllyToast(context,
              '${_areas[i]}: ${(_progress[i] * 100).round()}% of this week'),
          child: Text('${_areas.length}', style: AllyType.h2(color: c.ink)),
        ),
      ]);

  Widget _areaRows(AllyColors c) => _section('Areas', c, [
        AllyCard(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x1),
          child: Column(children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) Divider(color: c.line, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Sp.x3),
                child: Row(children: [
                  ProgressRing(
                    key: ValueKey('ring$i$_replay'),
                    value: _progress[i],
                    color: c.area(i),
                    semanticLabel: _areas[i],
                  ),
                  const SizedBox(width: Sp.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(_areas[i],
                                style: AllyType.body(
                                    color: c.ink, w: FontWeight.w500)),
                          ),
                          const SizedBox(width: Sp.x2),
                          ModeTag(_modes[i]),
                        ]),
                        Text('${(_progress[i] * 5).toStringAsFixed(1)} of 5 h this week',
                            style: AllyType.small(color: c.faint)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.faint),
                ]),
              ),
            ],
          ]),
        ),
      ]);

  Widget _controls(AllyColors c) => _section('Controls', c, [
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final t in const ['15 min', '30 min', '1 hour', 'More'])
            AllyChip(t,
                selected: _picked.contains(t),
                onTap: () => setState(() => _picked
                  ..clear()
                  ..add(t))),
        ]),
        const SizedBox(height: Sp.x4),
        AllySegmented<String>(
          options: const {'low': 'Low', 'normal': 'Normal', 'high': 'High'},
          value: _energy,
          onChanged: (v) => setState(() => _energy = v),
        ),
        const SizedBox(height: Sp.x4),
        Row(children: [
          Expanded(
              child: Text('Speak up when I am free',
                  style: AllyType.body(color: c.ink))),
          AllySwitch(
              value: _switch,
              semanticLabel: 'Speak up when I am free',
              onChanged: (v) => setState(() => _switch = v)),
        ]),
        const SizedBox(height: Sp.x4),
        AllyButton('Main action', wide: true, onPressed: () {}),
        const SizedBox(height: Sp.x2),
        Row(children: [
          Expanded(
              child: AllyButton('Secondary',
                  kind: AllyButtonKind.secondary, wide: true, onPressed: () {})),
          const SizedBox(width: Sp.x2),
          Expanded(
              child: AllyButton('Delete',
                  kind: AllyButtonKind.danger, wide: true, onPressed: () {})),
        ]),
        const SizedBox(height: Sp.x2),
        const AllyButton('Not available', wide: true, onPressed: null),
        const SizedBox(height: Sp.x3),
        const TextField(decoration: InputDecoration(hintText: 'Say anything…')),
      ]);

  Widget _focusCard(AllyColors c) => _section('Focus', c, [
        AllyCard(
          child: Column(children: [
            ProgressRing(
              value: _focus,
              color: c.area(2),
              size: 170,
              stroke: 12,
              tickWhenFull: true,
              semanticLabel: 'Focus session',
              child: Text('${((1 - _focus) * 25).round()}:00',
                  style: AllyType.big(color: c.ink, size: 34)),
            ),
            const SizedBox(height: Sp.x4),
            Row(children: [
              Expanded(
                child: AllyButton(_focus >= 1 ? 'Again' : 'Skip ahead',
                    kind: AllyButtonKind.secondary,
                    wide: true,
                    onPressed: () => setState(
                        () => _focus = _focus >= 1 ? 0.1 : (_focus + 0.35).clamp(0, 1))),
              ),
            ]),
          ]),
        ),
      ]);

  Widget _states(AllyColors c) => _section('States', c, [
        const AllyBanner("You're offline. Changes are saved on this phone."),
        const SizedBox(height: Sp.x3),
        AllyNote('A reminder did not arrive at 7:00 this morning.',
            actionLabel: 'Fix in 2 steps', onAction: () {}),
        const SizedBox(height: Sp.x3),
        AllyButton(_loading ? 'Show content' : 'Show loading',
            kind: AllyButtonKind.secondary,
            onPressed: () => setState(() => _loading = !_loading)),
        const SizedBox(height: Sp.x3),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.d2),
          child: _loading
              ? const Column(
                  key: ValueKey('sk'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AllySkeleton(height: 96, radius: Rad.card),
                    SizedBox(height: Sp.x2),
                    AllySkeleton(height: 18, width: 220),
                    SizedBox(height: Sp.x2),
                    AllySkeleton(height: 18, width: 150),
                  ],
                )
              : AllyCard(
                  key: const ValueKey('empty'),
                  child: Column(children: [
                    Text('Nothing here yet', style: AllyType.h2(color: c.ink)),
                    const SizedBox(height: Sp.x1),
                    Text('Add your first area and Ally will draft a plan.',
                        textAlign: TextAlign.center,
                        style: AllyType.body(color: c.muted)),
                    const SizedBox(height: Sp.x4),
                    AllyButton('Add an area', onPressed: () {}),
                  ]),
                ),
        ),
      ]);

  Widget _type(AllyColors c) => _section('Type', c, [
        Text('Good evening', style: AllyType.h1(color: c.ink)),
        const SizedBox(height: Sp.x2),
        Text('A card title', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x2),
        Text('Body text is 16 and follows the size set on your phone.',
            style: AllyType.body(color: c.ink)),
        Text('Supporting text is 14.', style: AllyType.small(color: c.muted)),
        const SizedBox(height: Sp.x2),
        Text('18:30  25 min  1h 30', style: AllyType.num(color: c.ink)),
      ]);

  void _openSheet() {
    showAllySheet<void>(
      context,
      builder: (ctx) {
        final c = ctx.ac;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Something else', style: AllyType.h2(color: c.ink)),
            const SizedBox(height: Sp.x1),
            Text('The best option in each other area.',
                style: AllyType.body(color: c.muted)),
            const SizedBox(height: Sp.x4),
            for (var i = 0; i < 3; i++) ...[
              AllyCard(
                onTap: () => Navigator.pop(ctx),
                padding: const EdgeInsets.all(Sp.x4),
                child: Row(children: [
                  Expanded(child: AreaLabel(_areas[i], color: c.area(i))),
                  Text('${15 + i * 10} min', style: AllyType.num(color: c.faint)),
                ]),
              ),
              const SizedBox(height: Sp.x2),
            ],
            AllyButton('Rest instead',
                kind: AllyButtonKind.ghost, onPressed: () => Navigator.pop(ctx)),
          ],
        );
      },
    );
  }
}
