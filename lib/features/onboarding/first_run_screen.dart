import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/life_repository.dart';
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
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            Text('Hi, I\'m Ally.', style: G.display(30)),
            const SizedBox(height: 8),
            Text('Three quick questions so I can fit things into your real day. Skip anything you like.',
                style: G.text(15, color: G.muted, height: 1.45)),
            const GHeading('1. WHEN DO YOU WAKE UP AND SLEEP?'),
            Row(children: [
              Expanded(child: _TimeField(label: 'Wake up', time: _wake, onTap: () => _pick(_wake, (t) => _wake = t))),
              const SizedBox(width: 12),
              Expanded(child: _TimeField(label: 'Sleep', time: _sleep, onTap: () => _pick(_sleep, (t) => _sleep = t))),
            ]),
            const GHeading('2. OFFICE OR WORK HOURS?'),
            Row(children: [
              Expanded(child: Text('I go to work / office', style: G.text(15))),
              Switch(value: _works, onChanged: (v) => setState(() => _works = v)),
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
                const SizedBox(width: 12),
                Expanded(child: _TimeField(label: 'Ends', time: _officeEnd, onTap: () => _pick(_officeEnd, (t) => _officeEnd = t))),
              ]),
            ],
            const GHeading('3. WHAT DO YOU WANT HELP WITH FIRST?'),
            TextField(
              controller: _help,
              minLines: 2,
              maxLines: 4,
              style: G.text(15),
              decoration: InputDecoration(
                hintText: 'e.g. drink more water, follow my diet, prepare for interviews',
                hintStyle: G.text(14, color: G.faint),
                filled: true,
                fillColor: G.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: G.lineSoft)),
              ),
            ),
            const SizedBox(height: 6),
            Text('I\'ll take this as your first message and suggest what to set up. Nothing is saved without your OK.',
                style: G.label(size: 11, color: G.faint)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: G.text(13, color: G.carried)),
            ],
            const SizedBox(height: 24),
            GButton(_saving ? 'Saving…' : 'Continue', onTap: _saving ? null : _save),
            const SizedBox(height: 8),
            GButton('Skip for now', primary: false, onTap: _saving ? null : () => Navigator.of(context).pop()),
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: G.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: G.lineSoft),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: G.label(size: 11, color: G.faint)),
            const SizedBox(height: 2),
            Text(time.format(context), style: G.text(18, w: FontWeight.w500)),
          ]),
        ),
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
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? G.accentStrong.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: on ? G.accent : G.line),
          ),
          child: Text(letter, style: G.text(14, w: FontWeight.w600, color: on ? G.accent : G.muted)),
        ),
      );
}
