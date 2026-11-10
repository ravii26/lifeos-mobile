import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/json.dart';
import '../../data/repositories/life_repository.dart';
import '../chat/starters.dart';
import '../guide/guide_style.dart';

/// "You showed up 4 days." A quiet week gets a fresh start, never a score.
String weekHeadline(int daysActive) {
  if (daysActive <= 0) return 'A fresh week starts whenever you do.';
  return daysActive == 1 ? 'You showed up 1 day.' : 'You showed up $daysActive days.';
}

/// 45 → "45 min", 120 → "2 h", 90 → "1.5 h".
String timeShort(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = (minutes / 30).round() / 2;
  return hours == hours.roundToDouble() ? '${hours.toInt()} h' : '$hours h';
}

/// The weekly life check: only when asked for, and honest without keeping score.
class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  Json? _week;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final week = await getIt<LifeRepository>().weekCheck();
      if (mounted) setState(() => _week = week);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: G.text(30, w: FontWeight.w600, height: 1.15))),
            Text(label, style: G.text(15, color: G.muted, height: 1.25)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = _week;
    final habits = ((w?['habits'] as List?) ?? const []).whereType<Json>().toList();
    final moved = ((w?['moved'] as List?) ?? const []).whereType<Json>().toList();
    final quiet = asStringOrNull(w?['quietArea']);
    final top = asStringOrNull(w?['topArea']);
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(backgroundColor: G.bg, surfaceTintColor: G.bg, foregroundColor: G.ink, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          if (_error != null) Text(_error!, style: G.text(18, color: G.muted, height: 1.4)),
          if (w == null && _error == null) Text('Looking at your week…', style: G.text(24, color: G.muted, height: 1.2)),
          if (w != null) ...[
            Text('Your week', style: G.text(17, color: G.accent, height: 1.2)),
            const SizedBox(height: 8),
            Text(weekHeadline(asInt(w['daysActive'])), style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
            const SizedBox(height: 22),
            Row(children: [
              _stat('${asInt(w['done'])}', 'done'),
              const SizedBox(width: 8),
              _stat('${asInt(w['minimums'])}', 'small steps'),
              const SizedBox(width: 8),
              _stat(timeShort(asInt(w['minutes'])), 'on goals'),
            ]),
            const SizedBox(height: 20),
            for (final h in habits)
              _line(asString(h['title']), '${asInt(h['days'])} of 7 days'),
            for (final m in moved) _line(asString(m['title']), asString(m['message'])),
            if (top != null) _line('Most effort', top),
            if (quiet != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                decoration: BoxDecoration(color: G.accent, borderRadius: BorderRadius.circular(26)),
                child: Text('Nothing from $quiet in two weeks. Want to change that?',
                    style: G.text(22, w: FontWeight.w500, color: G.onInk, height: 1.25)),
              ),
              const SizedBox(height: 14),
              GPill('Plan something small', primary: true, onTap: () => starterRequest.value = Starter.goal),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 50)),
                child: Text('Not this week', style: G.text(17, height: 1.2)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _line(String left, String right) => Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: G.lineSoft))),
        child: Row(children: [
          Expanded(child: Text(left, style: G.text(18, height: 1.25))),
          const SizedBox(width: 12),
          Flexible(child: Text(right, textAlign: TextAlign.end, style: G.text(16, color: G.muted, height: 1.25))),
        ]),
      );
}
