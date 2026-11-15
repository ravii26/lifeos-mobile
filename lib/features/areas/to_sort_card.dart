import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;

/// "To sort" (ALLY.md 2.4): things said in Talk or a brain dump that have no
/// area yet wait here, and Ally asks where each goes. One tap puts it in an
/// area (the one its words suggest is first), with Undo; or let it go.
/// Shows nothing when there is nothing to sort, offline, or on an older server.
class ToSortCard extends StatefulWidget {
  final LifeRepository repo;
  final List<({String id, String name})> areas;
  const ToSortCard({super.key, required this.repo, required this.areas});

  @override
  State<ToSortCard> createState() => _ToSortCardState();
}

class _ToSortCardState extends State<ToSortCard> {
  List<Json> _items = const [];

  @override
  void initState() {
    super.initState();
    placesRefresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    placesRefresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repo.toSort();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // Nothing to show: offline, or the server has no "to sort" yet.
    }
  }

  Future<void> _open(BuildContext themed) async {
    await showAllySheet<void>(themed, builder: (ctx) => _SortSheet(repo: widget.repo, items: _items, areas: widget.areas, toastContext: themed));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty || widget.areas.isEmpty) return const SizedBox.shrink();
    final c = context.ac;
    final n = _items.length;
    return AllyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('TO SORT', style: AllyType.eyebrow(color: c.faint)),
        const SizedBox(height: Sp.x1),
        Text(n == 1 ? 'One thing has no area yet' : '$n things have no area yet', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text(asString(_items.first['title']) + (n > 1 ? ', and more' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x3),
        Align(alignment: Alignment.centerLeft, child: AllyButton('Sort them', kind: AllyButtonKind.secondary, onPressed: () => _open(context))),
      ]),
    );
  }
}

class _SortSheet extends StatefulWidget {
  final LifeRepository repo;
  final List<Json> items;
  final List<({String id, String name})> areas;
  final BuildContext toastContext;
  const _SortSheet({required this.repo, required this.items, required this.areas, required this.toastContext});

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late final List<Json> _left = [...widget.items];
  bool _busy = false;

  Future<void> _do(Json item, Future<({String message, String? activityId})> Function() job) async {
    setState(() => _busy = true);
    try {
      final r = await job();
      placesRefresh.value++;
      setState(() {
        _left.remove(item);
        _busy = false;
      });
      final undo = r.activityId;
      final repo = widget.repo;
      if (widget.toastContext.mounted) {
        showAllyToast(widget.toastContext, r.message, onUndo: undo == null ? null : () => repo.undo(undo).then((_) => placesRefresh.value++).catchError((_) {}));
      }
      if (_left.isEmpty && mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _busy = false);
      if (widget.toastContext.mounted) showAllyToast(widget.toastContext, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Where does each go?', style: AllyType.h2(color: c.ink)),
      const SizedBox(height: Sp.x3),
      for (final item in _left.take(5)) ...[
        AllyCard(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(asString(item['title']), style: AllyType.body(color: c.ink, w: FontWeight.w600)),
            const SizedBox(height: Sp.x2),
            Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
              for (final a in [
                ...widget.areas.where((a) => a.id == item['suggestedAreaId']),
                ...widget.areas.where((a) => a.id != item['suggestedAreaId']),
              ])
                AllyChip(a.name,
                    selected: a.id == item['suggestedAreaId'],
                    onTap: _busy ? null : () => _do(item, () => widget.repo.sortStep(asString(item['id']), a.id))),
              AllyChip('Let it go', onTap: _busy ? null : () => _do(item, () => widget.repo.letGoStep(asString(item['id'])))),
            ]),
          ]),
        ),
        const SizedBox(height: Sp.x2),
      ],
      if (_left.length > 5) Text('${_left.length - 5} more after these.', style: AllyType.small(color: c.faint)),
    ]);
  }
}
