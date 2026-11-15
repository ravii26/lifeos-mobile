import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../today/day_shape.dart' show duration;

typedef TasteDraft = ({String title, int minutes});

/// The same three generic tastes the server falls back to, so the sheet works
/// without a connection and without AI.
List<TasteDraft> genericTastes(String area) => [
      (title: 'Try the simplest version of $area for half an hour', minutes: 30),
      (title: 'Watch or read one beginner guide to $area', minutes: 30),
      (title: 'Make or do one small thing in $area', minutes: 45),
    ];

/// Plan three small tastes of an area: suggested by Ally, each one editable.
/// Pops with the three to start, or null.
class TastesSheet extends StatefulWidget {
  final String areaId;
  final String areaName;
  final LifeRepository repo;

  const TastesSheet({super.key, required this.areaId, required this.areaName, required this.repo});

  @override
  State<TastesSheet> createState() => _TastesSheetState();
}

class _TastesSheetState extends State<TastesSheet> {
  final _fields = [TextEditingController(), TextEditingController(), TextEditingController()];
  final _minutes = [30, 30, 45];
  bool _loading = true;
  String? _note;

  @override
  void initState() {
    super.initState();
    _suggest();
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _fill(List<TasteDraft> list) {
    for (var i = 0; i < 3; i++) {
      final t = i < list.length ? list[i] : genericTastes(widget.areaName)[i];
      _fields[i].text = t.title;
      _minutes[i] = t.minutes;
    }
  }

  Future<void> _suggest() async {
    try {
      final r = await widget.repo.suggestTastes(widget.areaId);
      if (!mounted) return;
      setState(() {
        _fill(r.tastes);
        _loading = false;
        _note = r.byCode ? 'Simple starting points. Change them to anything that feels like a real taste.' : null;
      });
    } on ApiException {
      if (!mounted) return;
      // Offline or an older server: start from the generic three, still editable.
      setState(() {
        _fill(genericTastes(widget.areaName));
        _loading = false;
        _note = "Couldn't reach Ally for ideas. These are simple starting points; change them freely.";
      });
    }
  }

  bool get _ready => _fields.every((f) => f.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Three small tastes', style: AllyType.h2(color: c.ink)),
        const SizedBox(height: Sp.x1),
        Text('Not sure about ${widget.areaName} yet is fine. Try three small things, then decide.',
            style: AllyType.body(color: c.muted)),
        const SizedBox(height: Sp.x4),
        if (_loading)
          const Column(children: [
            AllySkeleton(height: 52),
            SizedBox(height: Sp.x2),
            AllySkeleton(height: 52),
            SizedBox(height: Sp.x2),
            AllySkeleton(height: 52),
          ])
        else ...[
          if (_note != null) ...[
            AllyBanner(_note!, icon: Icons.info_outline_rounded),
            const SizedBox(height: Sp.x3),
          ],
          for (var i = 0; i < 3; i++) ...[
            Row(children: [
              Text('TASTE ${i + 1}', style: AllyType.eyebrow(color: c.faint)),
              const Spacer(),
              Text(duration(_minutes[i]), style: AllyType.num(color: c.faint, size: 12)),
            ]),
            const SizedBox(height: Sp.x1),
            TextField(
              controller: _fields[i],
              maxLength: 150,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: AllyType.body(color: c.ink),
              decoration: InputDecoration(hintText: 'Taste ${i + 1}', counterText: ''),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Sp.x3),
          ],
          AllyButton('Start the tastes',
              wide: true,
              onPressed: _ready
                  ? () => Navigator.of(context).pop<List<TasteDraft>>([
                        for (var i = 0; i < 3; i++) (title: _fields[i].text.trim(), minutes: _minutes[i]),
                      ])
                  : null),
        ],
      ],
    );
  }
}
