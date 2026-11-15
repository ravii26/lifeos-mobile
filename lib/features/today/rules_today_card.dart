import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// Rules that show up before an event (ALLY.md 5.2 #17): when something on
/// today or tomorrow matches rules the person switched on ("party", "interview"),
/// they show here without being asked. "Got it" hides them for today.
class RulesTodayCard extends StatefulWidget {
  final LifeRepository repo;

  /// For tests: today's date, which decides what "hidden for today" means.
  final DateTime Function()? clock;
  const RulesTodayCard({super.key, required this.repo, this.clock});

  @override
  State<RulesTodayCard> createState() => _RulesTodayCardState();
}

class _RulesTodayCardState extends State<RulesTodayCard> {
  List<Json> _rules = const [];
  Set<String> _hidden = {};

  String get _today {
    final d = (widget.clock ?? DateTime.now)();
    return '${d.year}-${d.month}-${d.day}';
  }

  String _key(String id) => 'rules_hidden_${id}_$_today';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rules = await widget.repo.rulesForToday();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _hidden = {for (final r in rules) if (prefs.getBool(_key(asString(r['id']))) ?? false) asString(r['id'])};
      });
    } on ApiException catch (_) {
      // Offline or an older server: nothing to show.
    } catch (_) {}
  }

  Future<void> _hide(String id) async {
    setState(() => _hidden.add(id));
    try {
      await (await SharedPreferences.getInstance()).setBool(_key(id), true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final show = _rules.where((r) => !_hidden.contains(asString(r['id']))).toList();
    if (show.isEmpty) return const SizedBox.shrink();
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in show)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.x2),
          child: AllyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('FOR ${asString(r['because']).toUpperCase()}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AllyType.eyebrow(color: c.faint)),
              const SizedBox(height: Sp.x1),
              Text(asString(r['title']), style: AllyType.h2(color: c.ink)),
              const SizedBox(height: Sp.x2),
              for (final (i, item) in ((r['items'] as List?) ?? const []).map((e) => '$e').indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 24, child: Text('${i + 1}', style: AllyType.num(color: c.faint))),
                    Expanded(child: Text(item, style: AllyType.body(color: c.ink))),
                  ]),
                ),
              Align(alignment: Alignment.centerRight, child: AllyButton('Got it', kind: AllyButtonKind.ghost, onPressed: () => _hide(asString(r['id'])))),
            ]),
          ),
        ),
    ]);
  }
}
