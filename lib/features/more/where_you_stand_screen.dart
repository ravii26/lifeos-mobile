import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _kindText = {
  'MILESTONE': 'Stages',
  'OUTCOME': 'A number to move',
  'PRACTICE': 'Weekly practice',
  'WORK': 'Work with a deadline',
};

/// One line per goal: where you are, whether you are moving, what is next.
/// Every number is computed by the server from your own history; nothing here
/// is typed in by hand. Read only: tell Ally in chat to log or change things.
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
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Text('Where you stand', style: G.display(30)),
          const SizedBox(height: 8),
          Text('Worked out from what you actually did. To log something, tell me in chat, like "I solved 10 problems".',
              style: G.voice(17)),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: G.text(15, color: G.muted)),
          if (items == null && _error == null)
            const Center(child: CircularProgressIndicator(color: G.ink, strokeWidth: 2)),
          if (items != null && items.isEmpty)
            Text('No goals yet. Tell me one in chat and I will set it up with stages or a number to track.',
                style: G.text(16, color: G.muted)),
          for (final p in items ?? const <Map<String, dynamic>>[])
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${p['title']}', style: G.text(17, w: FontWeight.w700))),
                  if (p['status'] == 'PAUSED') Text('Paused', style: G.text(12, color: G.muted)),
                ]),
                const SizedBox(height: 2),
                Text(_kindText['${p['kind']}'] ?? '', style: G.text(12, color: G.muted)),
                const SizedBox(height: 8),
                Text('${p['message']}', style: G.text(15, w: FontWeight.w500)),
                if (p['why'] != null && '${p['why']}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Why: ${p['why']}', style: G.voice(14)),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}
