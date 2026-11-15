import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../places/now_cubit.dart' show placesRefresh;
import 'you_page.dart';

/// One thing that happened, from `GET /activity`.
class HistoryItem {
  final String id;
  final String title;
  final String type; // CREATED | DONE | UPDATED | ARCHIVED | LOGGED | SKIPPED…
  final DateTime at;
  final bool canUndo;
  final bool undone;
  const HistoryItem(this.id, this.title, this.type, this.at, {this.canUndo = false, this.undone = false});

  factory HistoryItem.fromJson(Json j) {
    final undo = j['undo'];
    final kind = undo is Json ? asString(undo['kind']) : '';
    return HistoryItem(
      asString(j['id']),
      asString(j['title'], 'Something changed'),
      asString(j['type']),
      asDate(j['at'])?.toLocal() ?? DateTime.now(),
      // NOOP means there is nothing to put back (a skip, a note of what got in the way).
      canUndo: kind.isNotEmpty && kind != 'NOOP',
      undone: j['undoneAt'] != null,
    );
  }

  String get verb => switch (type) {
        'CREATED' => 'Added',
        'DONE' || 'LOGGED' || 'MINIMUM' => 'Done',
        'ARCHIVED' => 'Let go',
        'SKIPPED' => 'Not now',
        'UPDATED' => 'Changed',
        _ => '',
      };
}

/// History: everything Ally did or you did through Ally, newest first, with Undo.
class HistoryPage extends StatefulWidget {
  final LifeRepository repo;
  final DateTime Function()? clock;
  const HistoryPage({super.key, required this.repo, this.clock});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryItem>? _items;
  String? _error;
  final Set<String> _working = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = (await widget.repo.activity(days: 30)).map(HistoryItem.fromJson).toList();
      if (mounted) {
        setState(() {
          _items = r;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && _items == null) setState(() => _error = e.message);
    }
  }

  Future<void> _undo(BuildContext themed, HistoryItem h) async {
    setState(() => _working.add(h.id));
    try {
      await widget.repo.undo(h.id);
      placesRefresh.value++;
      await _load();
      if (themed.mounted) showAllyToast(themed, 'Undone: ${h.title}');
    } on ApiException catch (e) {
      if (themed.mounted) showAllyToast(themed, e.message);
    } finally {
      if (mounted) setState(() => _working.remove(h.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final now = (widget.clock ?? DateTime.now)();
    return YouPage(
      title: 'History',
      sub: 'The last 30 days. Anything that can be undone has Undo.',
      loading: items == null && _error == null,
      error: items == null ? _error : null,
      onRetry: _load,
      onRefresh: _load,
      children: (themed, c) {
        if (items!.isEmpty) return [Text('Nothing yet. What you and Ally do shows up here.', style: AllyType.body(color: c.muted))];
        final groups = <String, List<HistoryItem>>{};
        for (final h in items) {
          groups.putIfAbsent(dayHeading(h.at, now), () => []).add(h);
        }
        return [
          for (final e in groups.entries)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(e.key.toUpperCase(), style: AllyType.eyebrow(color: c.faint)),
              const SizedBox(height: Sp.x2),
              youRows(c, [
                for (final h in e.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sp.x2),
                    child: Row(children: [
                      SizedBox(width: 52, child: Text(hm(h.at), style: AllyType.num(color: c.faint, size: 13))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(h.title,
                              style: AllyType.body(color: h.undone ? c.faint : c.ink)
                                  .copyWith(decoration: h.undone ? TextDecoration.lineThrough : null)),
                          if (h.verb.isNotEmpty || h.undone) Text(h.undone ? 'Undone' : h.verb, style: AllyType.small(color: c.faint)),
                        ]),
                      ),
                      if (h.canUndo && !h.undone)
                        AllyButton('Undo', kind: AllyButtonKind.ghost, onPressed: _working.contains(h.id) ? null : () => _undo(themed, h)),
                    ]),
                  ),
              ]),
            ]),
        ];
      },
    );
  }
}
