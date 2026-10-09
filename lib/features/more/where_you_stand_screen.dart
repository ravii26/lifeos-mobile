import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _kindText = {
  'MILESTONE': 'Milestone Project',
  'OUTCOME': 'Outcome Project',
  'PRACTICE': 'Weekly Practice',
  'WORK': 'Work with a Deadline',
};

/// Where you stand: stages, trend and pace on each goal.
/// Styled according to Nocturne Sanctuary (ally_you_progress_where_you_stand).
class WhereYouStandScreen extends StatefulWidget {
  const WhereYouStandScreen({super.key});

  @override
  State<WhereYouStandScreen> createState() => _WhereYouStandScreenState();
}

class _WhereYouStandScreenState extends State<WhereYouStandScreen> {
  final _repo = getIt<LifeRepository>();
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.progress();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: G.bg,
      appBar: GTopBar(
        'Where you stand',
        subtitle: 'Paced linearity and goal trajectories',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Text(
              'Worked out from what you actually did. To log something, tell Ally in chat, like "I solved 10 problems".',
              style: G.voice(14, color: G.muted),
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: G.lineSoft),
            const SizedBox(height: 14),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: G.label(size: 12, color: Colors.redAccent)),
              ),
            if (items == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            if (items != null && items.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'No active goals yet. Tell Ally a goal in chat to track stages or metrics.',
                  style: G.voice(14, color: G.muted),
                ),
              ),
            for (final p in items ?? const <Map<String, dynamic>>[])
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      (_kindText['${p['kind']}'] ?? 'PROJECT').toUpperCase(),
                      style: G.label(size: 10, color: G.accent, w: FontWeight.w600),
                    ),
                    if (p['status'] == 'PAUSED')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: G.inset,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('Paused', style: G.label(size: 10, color: G.faint)),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text('${p['title']}', style: G.text(15, w: FontWeight.w600, height: 1.3)),
                  const SizedBox(height: 6),
                  Text('${p['message']}', style: G.text(13, color: G.muted, height: 1.4)),
                  if (p['why'] != null && '${p['why']}'.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      decoration: BoxDecoration(
                        color: G.inset,
                        border: Border(left: BorderSide(color: G.accent, width: 2)),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                      ),
                      child: Text(
                        '“${p['why']}”',
                        style: G.voice(13, color: G.muted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Flat Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 3,
                      color: G.inset,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.45,
                          child: Container(color: G.accent),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
