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
  'BUSY': 'Busy (smallest versions)',
  'SICK': 'Sick (all paused)',
  'TRAVEL': 'Travelling (plans paused)',
  'HOLIDAY': 'Holiday (plans paused)',
};

/// What Ally believes your day looks like, so a wrong schedule is easy to spot.
/// Styled according to Nocturne Sanctuary.
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
      appBar: GTopBar(
        'Your day & schedule',
        subtitle: 'Schedule blocks and active mode',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Text(
              'This is how Ally thinks your days run. To change it, tell Ally in chat, like "I work 10 to 8:30 on weekdays".',
              style: G.voice(14, color: G.muted),
            ),
            const SizedBox(height: 14),
            // Current Mode Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: G.card,
                border: Border.all(color: G.lineSoft, width: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: G.accent),
                ),
                const SizedBox(width: 8),
                Text('ACTIVE MODE: ', style: G.label(size: 10, color: G.faint, w: FontWeight.w600)),
                Text(_modeText[_mode] ?? _mode, style: G.text(14, w: FontWeight.w600, color: G.ink)),
              ]),
            ),
            const SizedBox(height: 14),
            Container(height: 0.5, color: G.lineSoft),
            const SizedBox(height: 14),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: G.label(size: 12, color: Colors.redAccent)),
              ),
            if (days == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),

            for (final d in order)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: G.card,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_weekdays[(d['weekday'] as num).toInt()], style: G.text(15, w: FontWeight.w600)),
                    Text(
                      d['custom'] == true ? 'You taught Ally' : 'Default guess',
                      style: G.label(size: 10, color: G.faint),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  for (final b in (d['blocks'] as List).whereType<Map<String, dynamic>>())
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: G.part('${b['block']}'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 80,
                          child: Text(
                            _blockLabel[b['block']] ?? '${b['block']}',
                            style: G.text(13, w: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${b['start']} – ${b['end']}',
                            style: G.label(size: 11, color: G.faint),
                          ),
                        ),
                        Text(
                          'free ${_hours((b['freeMinutes'] as num).toInt())}',
                          style: G.label(size: 11, color: G.muted),
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
