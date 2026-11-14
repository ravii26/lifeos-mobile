import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart';
import 'day_shape.dart';

/// "I've got time": say how long, get one thing that fits, start it.
///
/// Asks the same rules engine as the Today card (`GET /now?minutes=`), so the
/// answer follows deadlines, the part of the day and the person's mode. If
/// the server cannot be reached, it falls back to today's list on the phone.
/// Pops with the option to start, or null.
class FreeTimeSheet extends StatefulWidget {
  final LifeRepository repo;

  /// Today's list, for the offline fallback.
  final List<TodayItem> items;

  /// Preselected length, e.g. what is left of the current free window.
  final int? suggestedMinutes;

  const FreeTimeSheet({super.key, required this.repo, required this.items, this.suggestedMinutes});

  @override
  State<FreeTimeSheet> createState() => _FreeTimeSheetState();
}

class _FreeTimeSheetState extends State<FreeTimeSheet> {
  static const _lengths = [15, 30, 60, 90];

  late int _minutes = _nearest(widget.suggestedMinutes ?? 30);
  bool _low = false;
  bool _loading = false;
  bool _asked = false;
  bool _offline = false;
  String? _message;
  List<NowOption> _options = const [];
  int _index = 0;

  static int _nearest(int m) {
    var best = _lengths.first;
    for (final l in _lengths) {
      if (l <= m) best = l;
    }
    return best;
  }

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _asked = true;
      _offline = false;
      _message = null;
      _options = const [];
      _index = 0;
    });
    try {
      final data = await widget.repo.now(minutes: _minutes, smallest: _low);
      if (!mounted) return;
      final options = ((data['options'] as List?) ?? const []).whereType<Json>().map(NowOption.fromJson).toList();
      setState(() {
        _loading = false;
        _options = options;
        _message = options.isEmpty ? asString(data['message'], 'Nothing on your list fits that. Rest is a good use of it.') : null;
      });
    } on ApiException {
      if (!mounted) return;
      final fit = fitFromList(widget.items, _minutes);
      setState(() {
        _loading = false;
        _offline = true;
        _options = fit == null
            ? const []
            : [NowOption(fit.sourceType, fit.id, fit.title, fit.minutes ?? _minutes, false, '', "From today's list.")];
        _message = fit == null ? "Can't reach Ally, and nothing on today's list fits. Rest is a good use of it." : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final o = _index < _options.length ? _options[_index] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("I've got time", style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('How long do you have?', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x3),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final l in _lengths)
            AllyChip(duration(l), selected: _minutes == l, onTap: _loading ? null : () => setState(() => _minutes = l)),
        ]),
        const SizedBox(height: Sp.x2),
        Row(children: [
          Expanded(child: Text('Low on energy', style: AllyType.body(color: c.ink))),
          AllySwitch(value: _low, semanticLabel: 'Low on energy', onChanged: _loading ? null : (v) => setState(() => _low = v)),
        ]),
        const SizedBox(height: Sp.x3),
        if (!_asked)
          AllyButton('Show me what fits', wide: true, onPressed: _ask)
        else if (_loading)
          const AllySkeleton(height: 132, radius: Rad.card)
        else ...[
          if (_offline) ...[
            const AllyBanner("You're offline. This is from today's list on this phone."),
            const SizedBox(height: Sp.x3),
          ],
          if (o != null)
            AllyCard(
              key: ValueKey('${o.sourceId}$_index'),
              free: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.smaller && o.minimum.isNotEmpty ? o.minimum : o.title, style: AllyType.h2(color: c.ink)),
                const SizedBox(height: Sp.x1),
                Text(
                  [if (o.minutes > 0) duration(o.minutes), if (o.why.isNotEmpty) o.why].join(' · '),
                  style: AllyType.body(color: c.muted),
                ),
                const SizedBox(height: Sp.x4),
                AllyButton('Start',
                    kind: AllyButtonKind.free,
                    icon: Icons.play_arrow_rounded,
                    wide: true,
                    onPressed: () => Navigator.of(context).pop(o)),
              ]),
            )
          else
            AllyCard(child: Text(_message ?? '', style: AllyType.body(color: c.ink))),
          const SizedBox(height: Sp.x2),
          Row(children: [
            if (_index + 1 < _options.length)
              Expanded(
                child: AllyButton('Something else',
                    kind: AllyButtonKind.secondary, wide: true, onPressed: () => setState(() => _index++)),
              )
            else
              Expanded(
                child: AllyButton('Ask again', kind: AllyButtonKind.secondary, wide: true, onPressed: _ask),
              ),
            const SizedBox(width: Sp.x2),
            Expanded(
              child: AllyButton('Rest instead',
                  kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop()),
            ),
          ]),
        ],
      ],
    );
  }
}

/// What the person chose on "What's in the way?".
typedef NotNowAnswer = ({String choice, String? reason});

/// "Not now": one optional reason, and each reason leads to its own fix
/// instead of only a later date. The reason is kept so a restart can learn
/// from it. Same rules as before; only the look is new.
class NotNowSheet extends StatefulWidget {
  final String title;
  final bool isGoal;
  final bool canWeekend;
  final bool canLetGo;
  final bool canShrink;

  const NotNowSheet({
    super.key,
    required this.title,
    required this.isGoal,
    required this.canWeekend,
    required this.canLetGo,
    required this.canShrink,
  });

  @override
  State<NotNowSheet> createState() => _NotNowSheetState();
}

class _NotNowSheetState extends State<NotNowSheet> {
  String? _reason;

  static const _reasons = [
    ('Tired', 'tired'),
    ('No time', 'no time'),
    ('Too big', 'too big'),
    ('Not clear what to do', 'not clear what to do'),
    ('Forgot', 'forgot'),
    ("Didn't feel like it", "didn't feel like it"),
  ];

  void _pop(String choice, [String? reason]) =>
      Navigator.of(context).pop<NotNowAnswer>((choice: choice, reason: reason ?? _reason));

  void _tapReason(String reason) {
    // Some reasons have a better answer than "later".
    final fix = switch (reason) {
      'not clear what to do' => 'CLEAR',
      'too big' || 'tired' => widget.canShrink ? 'SMALLER' : null,
      "didn't feel like it" => 'FIVE',
      _ => null,
    };
    if (fix != null) return _pop(fix, reason);
    setState(() => _reason = _reason == reason ? null : reason);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("What's in the way?", style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('One tap, optional. It helps me plan better.', style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x3),
        Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
          for (final (label, value) in _reasons)
            AllyChip(label, selected: _reason == value, onTap: () => _tapReason(value)),
        ]),
        const SizedBox(height: Sp.x5),
        Text('WHEN SHOULD THIS COME BACK?', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x3),
        AllyButton('Tomorrow', kind: AllyButtonKind.secondary, wide: true, onPressed: () => _pop('TOMORROW')),
        if (widget.canWeekend) ...[
          const SizedBox(height: Sp.x2),
          AllyButton('This weekend', kind: AllyButtonKind.secondary, wide: true, onPressed: () => _pop('WEEKEND')),
        ],
        const SizedBox(height: Sp.x2),
        AllyButton('Show me something else', kind: AllyButtonKind.secondary, wide: true, onPressed: () => _pop('SKIP')),
        if (widget.canLetGo) ...[
          const SizedBox(height: Sp.x1),
          AllyButton(widget.isGoal ? 'Park this goal for now' : 'Let this go',
              kind: AllyButtonKind.ghost, wide: true, onPressed: () => _pop('LET_GO')),
        ],
      ],
    );
  }
}

/// "Not clear what to do": the first step, then the rest. Pops true to start.
class StepsSheet extends StatelessWidget {
  final String title;
  final String firstStep;
  final String? detail;
  const StepsSheet({super.key, required this.title, required this.firstStep, this.detail});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x3),
        if (firstStep.isNotEmpty) ...[
          Text('START WITH', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(firstStep, style: AllyType.body(color: c.ink, w: FontWeight.w500)),
          const SizedBox(height: Sp.x3),
        ],
        if (detail != null && detail!.isNotEmpty) ...[
          Text('THEN', style: AllyType.eyebrow(color: c.faint)),
          const SizedBox(height: Sp.x1),
          Text(detail!, style: AllyType.body(color: c.muted)),
          const SizedBox(height: Sp.x3),
        ],
        if (firstStep.isEmpty && (detail == null || detail!.isEmpty)) ...[
          Text('Do the first two minutes of it. That is enough to find the next step.',
              style: AllyType.body(color: c.muted)),
          const SizedBox(height: Sp.x3),
        ],
        AllyButton('Start', wide: true, onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
  }
}
