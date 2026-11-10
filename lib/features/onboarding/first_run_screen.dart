import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/form_kit.dart' show gFieldStyle;
import '../guide/guide_style.dart';
import '../more/reminders_check_screen.dart';

/// First run: three questions so Ally knows your day instead of guessing it,
/// then a check that reminders will arrive. Every question can be skipped.
/// Pops with what the person wants help with first (sent to chat as their
/// own words), or null.
class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key});

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleep = const TimeOfDay(hour: 23, minute: 0);
  bool _works = true;
  // 0 = Sunday … 6 = Saturday, as the server counts.
  final Set<int> _officeDays = {1, 2, 3, 4, 5};
  TimeOfDay _officeStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _officeEnd = const TimeOfDay(hour: 19, minute: 0);
  final _help = TextEditingController();
  bool _saving = false;
  String? _error;

  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  static String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _help.dispose();
    super.dispose();
  }

  Future<void> _pick(TimeOfDay current, ValueChanged<TimeOfDay> set) async {
    final t = await showTimePicker(context: context, initialTime: current);
    if (t != null) setState(() => set(t));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await getIt<LifeRepository>().setDayBasics(
        wake: _hhmm(_wake),
        sleep: _hhmm(_sleep),
        officeDays: _works ? (_officeDays.toList()..sort()) : const [],
        officeStart: _works && _officeDays.isNotEmpty ? _hhmm(_officeStart) : null,
        officeEnd: _works && _officeDays.isNotEmpty ? _hhmm(_officeEnd) : null,
      );
      if (!mounted) return;
      // Reminders matter most, so the check comes right after.
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RemindersCheckScreen()));
      if (!mounted) return;
      final help = _help.text.trim();
      Navigator.of(context).pop(help.isEmpty ? null : help);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          children: [
            const GTitle("Hi, I'm Ally.", sub: 'Three quick questions so I can fit things into your real day. Skip anything you like.'),
            const GHeading('When do you wake up and sleep?'),
            Row(children: [
              Expanded(child: _TimeField(label: 'Wake up', time: _wake, onTap: () => _pick(_wake, (t) => _wake = t))),
              const SizedBox(width: 10),
              Expanded(child: _TimeField(label: 'Sleep', time: _sleep, onTap: () => _pick(_sleep, (t) => _sleep = t))),
            ]),
            const GHeading('Do you have work hours?'),
            Row(children: [
              Expanded(child: Text('I go to work or an office', style: G.text(18, height: 1.3))),
              Switch(value: _works, activeThumbColor: G.onInk, activeTrackColor: G.accent, onChanged: (v) => setState(() => _works = v)),
            ]),
            if (_works) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var d = 0; d < 7; d++)
                    _DayChip(
                      letter: _dayLetters[d],
                      on: _officeDays.contains(d),
                      onTap: () => setState(() => _officeDays.contains(d) ? _officeDays.remove(d) : _officeDays.add(d)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _TimeField(label: 'Starts', time: _officeStart, onTap: () => _pick(_officeStart, (t) => _officeStart = t))),
                const SizedBox(width: 10),
                Expanded(child: _TimeField(label: 'Ends', time: _officeEnd, onTap: () => _pick(_officeEnd, (t) => _officeEnd = t))),
              ]),
            ],
            const GHeading('What do you want help with first?'),
            TextField(
              controller: _help,
              minLines: 2,
              maxLines: 4,
              cursorColor: G.accent,
              style: G.text(18, height: 1.3),
              decoration: gFieldStyle('Like drinking more water, or preparing for interviews'),
            ),
            const SizedBox(height: 8),
            Text("I'll take this as your first message. Nothing is saved without your OK.",
                style: G.text(15, color: G.muted, height: 1.3)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: G.text(16, color: G.accent, height: 1.3)),
            ],
            const SizedBox(height: 24),
            GPill(_saving ? 'Saving…' : 'Continue', primary: true, onTap: _saving ? null : _save),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 48)),
              child: Text('Skip for now', style: G.text(17, height: 1.2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeField({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => GCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: G.text(15, color: G.muted, height: 1.25)),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(time.format(context), style: G.text(25, w: FontWeight.w500, height: 1.2))),
        ]),
      );
}

class _DayChip extends StatelessWidget {
  final String letter;
  final bool on;
  final VoidCallback onTap;
  const _DayChip({required this.letter, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? G.accent : G.card),
          child: Text(letter, style: G.text(16, w: FontWeight.w600, color: on ? G.onInk : G.muted, height: 1.2)),
        ),
      );
}
