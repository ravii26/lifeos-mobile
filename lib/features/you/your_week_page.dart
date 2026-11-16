import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../areas/areas_overview.dart' show loadAreasOverview;
import '../firstrun/first_run_data.dart' show workDayChoices, workHourChoices, wakeChoices, sleepChoices;
import '../week/review_rules.dart' show minutesLabel;
import 'you_page.dart';

/// Your normal day: work days and hours, when you wake and sleep, as tap
/// choices (the same ones first run asks). Nothing is picked until you pick it,
/// so a save never writes a guess over what Ally already knows.
class YourWeekPage extends StatefulWidget {
  final LifeRepository? repo;
  const YourWeekPage({super.key, this.repo});

  @override
  State<YourWeekPage> createState() => _YourWeekPageState();
}

class _YourWeekPageState extends State<YourWeekPage> {
  late final LifeRepository _repo = widget.repo ?? getIt<LifeRepository>();
  int _days = -1, _hours = -1, _wake = -1, _sleep = -1;
  bool _busy = false;
  String? _error;
  int? _freeMinutes;

  bool get _noWork => _days >= 0 && workDayChoices[_days].$2.isEmpty;
  bool get _ready => _days >= 0 && (_noWork || _hours >= 0) && _wake >= 0 && _sleep >= 0;

  Future<void> _save(BuildContext themed) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (_, days) = workDayChoices[_days];
      final (_, start, end) = _noWork ? ('', null, null) : workHourChoices[_hours];
      await _repo.setDayBasics(
        wake: wakeChoices[_wake].$2,
        sleep: sleepChoices[_sleep].$2,
        officeDays: start == null ? const [] : days,
        officeStart: days.isEmpty ? null : start,
        officeEnd: days.isEmpty ? null : end,
      );
      final o = await loadAreasOverview(_repo);
      if (mounted) setState(() => _freeMinutes = o.freeMinutes);
      if (themed.mounted) showAllyToast(themed, 'Saved. Ally plans into what is free.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return YouPage(
      title: 'Your normal day',
      sub: 'So Ally only plans into time that is really yours. Pick each to change it.',
      children: (themed, c) {
        Widget group(String label, List<String> options, int value, ValueChanged<int> onPick) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(label, style: AllyType.eyebrow(color: c.faint)),
              const SizedBox(height: Sp.x2),
              Wrap(spacing: Sp.x2, runSpacing: Sp.x2, children: [
                for (var i = 0; i < options.length; i++)
                  AllyChip(options[i], selected: value == i, onTap: () => setState(() {
                        onPick(i);
                        _freeMinutes = null;
                      })),
              ]),
            ]);
        return [
          group('WORK DAYS', [for (final x in workDayChoices) x.$1], _days, (i) => _days = i),
          if (_days >= 0 && !_noWork) group('WORK HOURS, INCLUDING TRAVEL', [for (final x in workHourChoices) x.$1], _hours, (i) => _hours = i),
          group('YOU WAKE AROUND', [for (final x in wakeChoices) x.$1], _wake, (i) => _wake = i),
          group('YOU SLEEP AROUND', [for (final x in sleepChoices) x.$1], _sleep, (i) => _sleep = i),
          if (_freeMinutes != null && _freeMinutes! > 0)
            AllyCard(strong: true, child: Text('That leaves about ${minutesLabel(_freeMinutes!)} a week that is yours.', style: AllyType.h2(color: c.ink))),
          if (_error != null) AllyNote(_error!),
          AllyButton(_busy ? 'Saving…' : 'Save', wide: true, onPressed: _ready && !_busy ? () => _save(themed) : null),
        ];
      },
    );
  }
}
