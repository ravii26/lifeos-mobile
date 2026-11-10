import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';
import '../onboarding/first_run_screen.dart';

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
  'BUSY': 'Busy (smallest versions)',
  'SICK': 'Sick (all paused)',
  'TRAVEL': 'Travelling (plans paused)',
  'HOLIDAY': 'Holiday (plans paused)',
};

/// What Ally believes your day looks like, so a wrong schedule is easy to spot.
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

  String _free(int minutes) {
    if (minutes <= 0) return 'No free time';
    final h = minutes ~/ 60, m = minutes % 60;
    return '${h == 0 ? '$m min' : (m == 0 ? '$h h' : '$h h $m min')} free';
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;
    // Monday first reads more naturally than Sunday first.
    final order = days == null ? const <Map<String, dynamic>>[] : [...days.skip(1), days.first];
    return Scaffold(
      backgroundColor: G.bg,
      appBar: gBar(),
      body: RefreshIndicator(
        color: G.accent,
        backgroundColor: G.card,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
          children: [
            const GTitle('My day', sub: 'This is how Ally thinks your days run. If it looks wrong, just say so in Talk, like "I work 10 to 8:30 on weekdays".'),
            GCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Right now', style: G.text(16, color: G.accent, height: 1.2)),
                const SizedBox(height: 4),
                Text(_modeText[_mode] ?? _mode, style: G.text(23, w: FontWeight.w500, height: 1.2)),
              ]),
            ),
            GPill('Set my day again', onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FirstRunScreen()));
              await _load();
            }),
            const SizedBox(height: 22),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: G.text(16, color: G.accent, height: 1.3)),
              ),
            if (days == null && _error == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 2, color: G.accent),
                ),
              ),
            for (final d in order)
              GCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_weekdays[(d['weekday'] as num).toInt()], style: G.text(23, w: FontWeight.w500, height: 1.2)),
                  Text(
                    d['custom'] == true ? 'You told Ally this' : "Ally's guess",
                    style: G.text(15, color: G.muted, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  for (final b in (d['blocks'] as List).whereType<Map<String, dynamic>>())
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: G.accent),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${_blockLabel[b['block']] ?? b['block']}, ${b['start']} to ${b['end']}', style: G.text(18, height: 1.3)),
                            Text(_free((b['freeMinutes'] as num).toInt()), style: G.text(15, color: G.muted, height: 1.3)),
                          ]),
                        ),
                      ]),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
