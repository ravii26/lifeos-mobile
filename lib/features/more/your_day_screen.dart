import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

const _weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _blockLabel = {
  'MORNING': 'Morning',
  'COMMUTE': 'Commute',
  'OFFICE': 'Office',
  'GYM': 'Gym',
  'EVENING': 'Evening',
  'NIGHT': 'Night',
};
const _modeText = {
  'NORMAL': 'Normal',
  'BUSY': 'Busy: only the smallest versions',
  'SICK': 'Sick: everything paused',
  'TRAVEL': 'Travelling: plans paused',
  'HOLIDAY': 'Holiday: plans paused',
};

/// What Ally believes your day looks like, so a wrong schedule is easy to
/// spot. Read only: you change it by telling Ally in chat.
class YourDayScreen extends StatefulWidget {
  const YourDayScreen({super.key});

  @override
  State<YourDayScreen> createState() => _YourDayScreenState();
}

class _YourDayScreenState extends State<YourDayScreen> {
  final _repo = getIt<LifeRepository>();
  List<Map<String, dynamic>>? _days;
  String _mode = 'NORMAL';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final days = await _repo.daySchedule();
      final mode = await _repo.mode();
      if (!mounted) return;
      setState(() {
        _days = days;
        _mode = mode;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _hours(int minutes) {
    if (minutes <= 0) return 'none';
    final h = minutes ~/ 60, m = minutes % 60;
    return h == 0 ? '$m min' : (m == 0 ? '$h h' : '$h h $m min');
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    // Monday first reads more naturally than Sunday first.
    final order = days == null ? const <Map<String, dynamic>>[] : [...days.skip(1), days.first];
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Text('Your day', style: G.display(30)),
          const SizedBox(height: 8),
          Text(
              'This is how I think your days run. To change it, tell me in chat, like "I work 10 to 8:30 on weekdays".',
              style: G.voice(17)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 18, color: G.ink),
              const SizedBox(width: 10),
              Expanded(child: Text('Mode: ${_modeText[_mode] ?? _mode}', style: G.text(15, w: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: G.text(15, color: G.muted)),
          if (days == null && _error == null)
            Center(child: CircularProgressIndicator(color: G.ink, strokeWidth: 2)),
          for (final d in order)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_weekdays[(d['weekday'] as num).toInt()], style: G.text(16, w: FontWeight.w700))),
                  Text(d['custom'] == true ? 'You told me' : "My guess, tell me if it's off",
                      style: G.text(12, color: G.muted)),
                ]),
                const SizedBox(height: 8),
                for (final b in (d['blocks'] as List).whereType<Map<String, dynamic>>())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      SizedBox(width: 84, child: Text(_blockLabel[b['block']] ?? '${b['block']}', style: G.text(14, w: FontWeight.w600))),
                      Expanded(child: Text('${b['start']} to ${b['end']}', style: G.text(14, color: G.muted))),
                      Text('free ${_hours((b['freeMinutes'] as num).toInt())}', style: G.text(13, color: G.muted)),
                    ]),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}
