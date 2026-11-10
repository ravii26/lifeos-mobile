import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../places/now_cubit.dart';
import 'shrink_screen.dart';

/// Everything parked: none of it needs you today, and any of it can come back with a tap.
class ParkedScreen extends StatefulWidget {
  const ParkedScreen({super.key});

  @override
  State<ParkedScreen> createState() => _ParkedScreenState();
}

class _ParkedScreenState extends State<ParkedScreen> {
  final _repo = getIt<LifeRepository>();
  List<Json>? _items;
  String? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.parked();
      if (mounted) setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _bringBack(Json item) async {
    final id = asString(item['activityId']);
    setState(() => _busy = id);
    try {
      await _repo.undo(id);
      placesRefresh.value++;
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          Text('Safe for later', style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
          const SizedBox(height: 8),
          Text('None of this needs you today.', style: G.text(19, color: G.muted, height: 1.3)),
          const SizedBox(height: 18),
          if (_error != null) Text(_error!, style: G.text(17, color: G.muted, height: 1.4)),
          if (items == null && _error == null) Text('Loading…', style: G.text(18, color: G.muted)),
          if (items != null && items.isEmpty) ...[
            Text('Nothing is parked right now.', style: G.text(20, height: 1.3)),
            const SizedBox(height: 18),
            GPill('Look through my list', onTap: () => openShrink(context)),
          ],
          for (final i in items ?? const <Json>[])
            Container(
              constraints: const BoxConstraints(minHeight: 74),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.lineSoft))),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(asString(i['title']), style: G.text(20, height: 1.25)),
                    const SizedBox(height: 2),
                    Text('Comes back in ${asString(i['untilLabel'])}', style: G.text(15, color: G.muted, height: 1.25)),
                  ]),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _busy != null ? null : () => _bringBack(i),
                  style: TextButton.styleFrom(backgroundColor: G.card, foregroundColor: G.ink, minimumSize: const Size(44, 46), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: Text('Bring back', style: G.text(16, height: 1.2)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
