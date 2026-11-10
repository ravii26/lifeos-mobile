import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';
import '../places/you_screen.dart' show goalProgress;

/// Goals: how far along each one is, worked out from what was actually done.
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
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Widget _card(Map<String, dynamic> p) {
    final progress = goalProgress(p);
    final why = '${p['why'] ?? ''}';
    final paused = p['status'] == 'PAUSED';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['title']}${paused ? ' (paused)' : ''}', style: G.text(24, w: FontWeight.w600, height: 1.15, letterSpacing: -0.4)),
        const SizedBox(height: 6),
        Text('${p['message']}', style: G.text(17, color: G.muted, height: 1.35)),
        if (why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Why it matters: $why', style: G.text(16, height: 1.35))),
        // Only a number the server worked out: an invented bar would be a lie.
        if (progress != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: G.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(G.accent),
            ),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            Text('My goals', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
            const SizedBox(height: 8),
            Text('Worked out from what you actually did.', style: G.text(19, color: G.muted, height: 1.3)),
            const SizedBox(height: 18),
            if (_error != null) Text(_error!, style: G.text(17, color: G.muted, height: 1.4)),
            if (items == null && _error == null) Text('Loading…', style: G.text(18, color: G.muted)),
            if (items != null && items.isEmpty) GPill('Plan a goal', primary: true, onTap: () => starterRequest.value = Starter.goal),
            for (final p in items ?? const <Map<String, dynamic>>[]) _card(p),
          ],
        ),
      ),
    );
  }
}
