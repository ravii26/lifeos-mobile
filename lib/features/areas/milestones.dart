import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// Milestones are small goals under a big one, each reachable in 1 to 4 weeks.
const maxMilestones = 6;

/// An editable list of milestones, in order: change any line, remove one, add
/// one (up to six). Used before anything is saved: in "Make a goal concrete"
/// and when splitting an existing goal.
class MilestoneEditor extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;
  const MilestoneEditor({super.key, required this.initial, required this.onChanged});

  @override
  State<MilestoneEditor> createState() => _MilestoneEditorState();
}

class _MilestoneEditorState extends State<MilestoneEditor> {
  late final List<TextEditingController> _rows = [for (final m in widget.initial) TextEditingController(text: m)];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _changed() => widget.onChanged([for (final r in _rows) if (r.text.trim().isNotEmpty) r.text.trim()]);

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < _rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.x2),
          child: Row(children: [
            SizedBox(width: 24, child: Text('${i + 1}', style: AllyType.num(color: c.faint))),
            Expanded(
              child: TextField(
                key: ValueKey('milestone-$i'),
                controller: _rows[i],
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                style: AllyType.body(color: c.ink),
                decoration: const InputDecoration(hintText: 'A result you can see is reached', counterText: '', isDense: true),
                onChanged: (_) => _changed(),
              ),
            ),
            IconButton(
              tooltip: 'Remove milestone ${i + 1}',
              icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
              onPressed: () {
                setState(() => _rows.removeAt(i).dispose());
                _changed();
              },
            ),
          ]),
        ),
      if (_rows.length < maxMilestones)
        Align(
          alignment: Alignment.centerLeft,
          child: AllyButton('Add a milestone',
              kind: AllyButtonKind.ghost, icon: Icons.add_rounded, onPressed: () => setState(() => _rows.add(TextEditingController()))),
        ),
    ]);
  }
}

/// "Split into milestones" for a goal that has none: Ally drafts them (AI, or
/// three plain ones without it), the person edits, then saves. Pops with the
/// Undo id (or '' when there is none), or null when closed.
class SplitGoalSheet extends StatefulWidget {
  final String goalId;
  final String goalTitle;
  final LifeRepository repo;
  const SplitGoalSheet({super.key, required this.goalId, required this.goalTitle, required this.repo});

  @override
  State<SplitGoalSheet> createState() => _SplitGoalSheetState();
}

class _SplitGoalSheetState extends State<SplitGoalSheet> {
  List<String>? _draft;
  List<String> _edited = const [];
  bool _byCode = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _draft = null;
      _error = null;
    });
    try {
      final d = await widget.repo.proposeMilestones(widget.goalId);
      if (!mounted) return;
      setState(() {
        _draft = d.milestones;
        _edited = d.milestones;
        _byCode = d.byCode;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.isNotFound ? 'This needs the latest server.' : e.message);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.repo.setMilestones(widget.goalId, _edited);
      if (mounted) Navigator.of(context).pop(id ?? '');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Split into milestones', style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x1),
      Text('Small goals of one to four weeks for ${widget.goalTitle}. Only the current one\'s steps show.',
          style: AllyType.small(color: c.muted)),
      const SizedBox(height: Sp.x4),
      if (_draft == null && _error == null) ...[
        const AllySkeleton(height: 44),
        const SizedBox(height: Sp.x2),
        const AllySkeleton(height: 44),
        const SizedBox(height: Sp.x2),
        const AllySkeleton(height: 44),
      ] else if (_draft == null) ...[
        AllyBanner(_error!, icon: Icons.cloud_off_rounded),
        const SizedBox(height: Sp.x3),
        AllyButton('Try again', kind: AllyButtonKind.secondary, wide: true, onPressed: _load),
      ] else ...[
        if (_byCode) ...[
          const AllyNote('Ally drafted these simply, without AI. Change them to fit.'),
          const SizedBox(height: Sp.x3),
        ],
        MilestoneEditor(initial: _draft!, onChanged: (m) => setState(() => _edited = m)),
        if (_error != null) ...[
          const SizedBox(height: Sp.x2),
          Text(_error!, style: AllyType.small(color: c.muted)),
        ],
        const SizedBox(height: Sp.x4),
        AllyButton(_edited.length < 2 ? 'Add at least two' : 'Save milestones',
            wide: true, onPressed: _saving || _edited.length < 2 ? null : _save),
      ],
    ]);
  }
}

/// What the person chose on the milestone edit sheet.
sealed class MilestoneAnswer {
  const MilestoneAnswer();
}

class MilestoneRename extends MilestoneAnswer {
  final String title;
  const MilestoneRename(this.title);
}

class MilestoneReached extends MilestoneAnswer {
  const MilestoneReached();
}

class MilestoneLetGo extends MilestoneAnswer {
  const MilestoneLetGo();
}

/// Edit one milestone: rename it, mark it reached (the current one only), or
/// let it go (a reached one stays reached).
class MilestoneSheet extends StatefulWidget {
  final String title;
  final bool current;
  final bool reached;
  const MilestoneSheet({super.key, required this.title, required this.current, required this.reached});

  @override
  State<MilestoneSheet> createState() => _MilestoneSheetState();
}

class _MilestoneSheetState extends State<MilestoneSheet> {
  late final _name = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed => _name.text.trim().isNotEmpty && _name.text.trim() != widget.title;

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    void pop(MilestoneAnswer a) => Navigator.of(context).pop<MilestoneAnswer>(a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Edit milestone', style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x3),
      Text('NAME', style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x2),
      TextField(
        controller: _name,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        style: AllyType.body(color: c.ink),
        decoration: const InputDecoration(hintText: 'Name', counterText: ''),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Sp.x4),
      AllyButton('Save', wide: true, onPressed: _changed ? () => pop(MilestoneRename(_name.text.trim())) : null),
      if (widget.current) ...[
        const SizedBox(height: Sp.x2),
        AllyButton('Mark it reached', kind: AllyButtonKind.secondary, icon: Icons.flag_rounded, wide: true, onPressed: () => pop(const MilestoneReached())),
      ],
      if (!widget.reached) ...[
        const SizedBox(height: Sp.x4),
        Text('Letting go keeps it, with its steps, out of the way. You can undo it.', style: AllyType.small(color: c.faint)),
        const SizedBox(height: Sp.x2),
        AllyButton('Let this milestone go', kind: AllyButtonKind.ghost, wide: true, onPressed: () => pop(const MilestoneLetGo())),
      ] else ...[
        const SizedBox(height: Sp.x3),
        Text('Reached. It stays reached.', style: AllyType.small(color: c.faint)),
      ],
    ]);
  }
}

/// The calm moment after a milestone is reached: the ring moves one place
/// forward, then what opens next. Pops true for Undo.
class MilestoneReachedSheet extends StatelessWidget {
  final String title;
  final String? next;
  final String? firstStep;
  final int reached; // after this one
  final int total;
  final Color color;
  final bool canUndo;
  const MilestoneReachedSheet(
      {super.key, required this.title, this.next, this.firstStep, required this.reached, required this.total, required this.color, this.canUndo = true});

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    final from = total == 0 ? 0.0 : (reached - 1) / total;
    final to = total == 0 ? 1.0 : reached / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: Sp.x2),
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: from, end: to),
          duration: Motion.of(context, const Duration(milliseconds: 900)),
          curve: Motion.ease,
          builder: (_, v, _) => ProgressRing(
            value: v,
            color: color,
            size: 88,
            stroke: 8,
            semanticLabel: '$reached of $total milestones reached',
            child: Icon(Icons.check_rounded, color: c.ink, size: 34),
          ),
        ),
      ),
      const SizedBox(height: Sp.x4),
      Text('MILESTONE REACHED · $reached OF $total', textAlign: TextAlign.center, style: AllyType.eyebrow(color: c.faint)),
      const SizedBox(height: Sp.x1),
      Text(title, textAlign: TextAlign.center, style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x3),
      if (next != null) ...[
        Text('Next: $next', textAlign: TextAlign.center, style: AllyType.body(color: c.muted)),
        if (firstStep != null) ...[
          const SizedBox(height: Sp.x1),
          Text('First step: $firstStep', textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
        ],
      ] else
        Text('That was the last one. The goal is reached.', textAlign: TextAlign.center, style: AllyType.body(color: c.muted)),
      const SizedBox(height: Sp.x5),
      AllyButton('Done', wide: true, onPressed: () => Navigator.of(context).pop(false)),
      if (canUndo) AllyButton('Undo', kind: AllyButtonKind.ghost, wide: true, onPressed: () => Navigator.of(context).pop(true)),
    ]);
  }
}
