import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/sleep_plan.dart';
import '../../data/repositories/life_repository.dart';
import '../guide/guide_style.dart';

/// Opens the sleep fix. Returns the Undo id when a plan was started.
Future<String?> openSleepSetup(BuildContext context) =>
    Navigator.of(context).push<String?>(MaterialPageRoute(builder: (_) => const SleepSetupScreen()));

/// The sleep fix (decisions log #13, canvas board P1·B): where you are now,
/// the wake time you want, how long you want to sleep → one fast jump, then
/// 30 minutes a week. Sleep is fixed first because everything else needs it.
class SleepSetupScreen extends StatefulWidget {
  const SleepSetupScreen({super.key});

  @override
  State<SleepSetupScreen> createState() => _SleepSetupScreenState();
}

class _SleepSetupScreenState extends State<SleepSetupScreen> {
  final _repo = getIt<LifeRepository>();
  String _nowWake = '08:00';
  String _targetWake = '06:00';
  int _hours = 420;
  bool _saving = false;

  // Common answers as one tap; "Other time" covers everyone else (students
  // waking at 11, early risers at 5, people on shifts).
  static const _nowChoices = ['06:00', '07:00', '08:00', '09:00', '10:00'];
  static const _targetChoices = ['05:30', '06:00', '06:30', '07:00', '07:30'];
  static const _hourChoices = [300, 360, 390, 420, 450, 480, 540, 600];

  String _hoursLabel(int m) => m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60}.5 h';

  static String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(String current, void Function(String) pick, {String? earliest}) async {
    final parts = current.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (t == null || !mounted) return;
    final v = _hhmm(t);
    if (earliest != null && v.compareTo(earliest) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A wake time before 4 am isn't something I'll plan.")));
      return;
    }
    setState(() => pick(v));
  }

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) pick, {VoidCallback? other}) {
    final custom = !values.contains(selected);
    Widget chip(String text, bool on, VoidCallback onTap) => ChoiceChip(
          label: Text(text, style: G.text(15, w: on ? FontWeight.w600 : FontWeight.w400, color: on ? G.onInk : G.ink)),
          selected: on,
          showCheckmark: false,
          selectedColor: G.accent,
          backgroundColor: G.card,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          onSelected: (_) => onTap(),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values) chip(label(v), v == selected, () => setState(() => pick(v))),
        if (other != null) chip(custom ? label(selected) : 'Other time', custom, other),
      ],
    );
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      final r = await _repo.startSleepPlan(nowWake: _nowWake, targetWake: _targetWake, hours: _hours);
      if (!mounted) return;
      if (r.note != null) {
        // Said once, then the choice stands (product rule, decisions log #13).
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: G.inset,
            content: Text(r.note!, style: G.text(16, height: 1.4)),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Okay', style: G.text(16, color: G.accent)))],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(r.activityId ?? '');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = previewLadder(_nowWake, _targetWake, _hours);
    return Scaffold(
      backgroundColor: G.bg,
      appBar: AppBar(
        backgroundColor: G.bg,
        surfaceTintColor: G.bg,
        foregroundColor: G.ink,
        elevation: 0,
        title: Text('Fix my sleep', style: G.text(20, w: FontWeight.w500, height: 1.2)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 24), children: [
          Text("Let's fix sleep first", style: G.text(32, w: FontWeight.w600, height: 1.1, letterSpacing: -0.7)),
          const SizedBox(height: 8),
          Text('Everything else is easier with a fixed wake time. One jump now, then a little each week.',
              style: G.text(17, color: G.muted, height: 1.4)),
          const SizedBox(height: 22),
          Text('Roughly, when do you wake up now?', style: G.text(18, w: FontWeight.w500)),
          const SizedBox(height: 10),
          _chips(_nowChoices, _nowWake, clockLabel, (v) => _nowWake = v, other: () => _pickTime(_nowWake, (v) => _nowWake = v)),
          const SizedBox(height: 20),
          Text('What wake time do you want?', style: G.text(18, w: FontWeight.w500)),
          const SizedBox(height: 10),
          _chips(_targetChoices, _targetWake, clockLabel, (v) => _targetWake = v,
              other: () => _pickTime(_targetWake, (v) => _targetWake = v, earliest: '04:00')),
          const SizedBox(height: 20),
          Text('How long do you want to sleep?', style: G.text(18, w: FontWeight.w500)),
          const SizedBox(height: 10),
          _chips(_hourChoices, _hours, _hoursLabel, (v) => _hours = v),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(steps.length == 1 ? 'From this week' : 'Your plan, ${steps.length} weeks', style: G.text(16, w: FontWeight.w600)),
              const SizedBox(height: 10),
              for (final s in steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(width: 74, child: Text('Week ${s.week}', style: G.text(15, color: s.week == 1 ? G.accent : G.muted))),
                    Expanded(child: Text('sleep ${clockLabel(s.sleep)}', style: G.text(15))),
                    Text('wake ${clockLabel(s.wake)}', style: G.text(15, w: FontWeight.w600)),
                  ]),
                ),
              const SizedBox(height: 6),
              Text('Same wake time every day, weekends too. The next step comes only after you keep it 5 of 7 days.',
                  style: G.text(13, color: G.faint, height: 1.35)),
            ]),
          ),
          const SizedBox(height: 10),
          Text('Slept late one night? Still wake on time; a nap under 20 minutes is fine. General guidance, not medical.',
              style: G.text(13, color: G.faint, height: 1.35)),
          const SizedBox(height: 22),
          GPill(_saving ? 'Starting…' : 'Start the plan', primary: true, onTap: _saving ? null : _start),
        ]),
      ),
    );
  }
}
