import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/models/area.dart';
import '../../data/models/identity.dart';
import '../../data/repositories/life_repository.dart';
import 'guide_style.dart';
import 'tonight_cubit.dart';

Future<void> openGuideSetup(BuildContext context) async {
  final cubit = context.read<TonightCubit>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: G.card,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: G.lineSoft, width: 0.5),
    ),
    builder: (_) =>
        const FractionallySizedBox(heightFactor: 0.94, child: _GuideSetup()),
  );
  await cubit.load();
}

const _tiers = [
  ('MAIN', 'Main'),
  ('SECONDARY', 'Secondary'),
  ('MAINTAIN', 'Maintain'),
  ('LATER', 'Later'),
];

const _presets = [
  ('Career', '#8FA2FF'),
  ('Health & fitness', '#92D5A7'),
  ('Communication', '#FFB780'),
  ('Learning', '#B9C3FF'),
  ('Money', '#D4B37F'),
  ('Relationships', '#D68F9A'),
  ('Hobbies', '#E0A37A'),
  ('Mind', '#9B9EB5'),
];

class _AreaRow {
  final Area? existing;
  final String name;
  final String colorHex;
  String tier;
  _AreaRow(
      {this.existing,
      required this.name,
      required this.colorHex,
      required this.tier});

  Color get color =>
      Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
}

class _GuideSetup extends StatefulWidget {
  const _GuideSetup();

  @override
  State<_GuideSetup> createState() => _GuideSetupState();
}

class _GuideSetupState extends State<_GuideSetup> {
  final _repo = getIt<LifeRepository>();
  final _goal = TextEditingController();
  final _step = TextEditingController();
  final _minimum = TextEditingController();

  final List<_AreaRow> _rows = [];
  Identity _identity = Identity.empty;
  String? _stepArea;
  String? _time;
  String? _morning;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.areas(),
        _repo.identity(),
        NotificationService.instance.nightlyTime(),
        NotificationService.instance.morningTime(),
      ]);
      final areas =
          (results[0] as List<Area>).where((a) => a.isActive).toList();
      setState(() {
        _identity = results[1] as Identity;
        _goal.text = _identity.thisYearGoal ?? '';
        _rows.addAll(areas.map((a) => _AreaRow(
            existing: a,
            name: a.name,
            colorHex: a.colorHex,
            tier: a.tier)));
        _stepArea = _mainRow()?.name;
        _time = results[2] as String?;
        _morning = results[3] as String?;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  _AreaRow? _mainRow() =>
      _rows.where((r) => r.tier == 'MAIN').firstOrNull ?? _rows.firstOrNull;

  void _addPreset(String name, String color) => setState(() {
        _rows.add(_AreaRow(
          name: name,
          colorHex: color,
          tier: _rows.any((r) => r.tier == 'MAIN') ? 'SECONDARY' : 'MAIN',
        ));
        _stepArea ??= name;
      });

  void _setTier(_AreaRow row, String tier) => setState(() {
        if (tier == 'MAIN') {
          for (final r in _rows) {
            if (r != row && r.tier == 'MAIN') r.tier = 'SECONDARY';
          }
        }
        row.tier = tier;
      });

  @override
  void dispose() {
    _goal.dispose();
    _step.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      setState(() => _error = 'Add at least one area that matters to you.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final goal = _goal.text.trim();
      if (goal != (_identity.thisYearGoal ?? '')) {
        final i = _identity;
        await _repo.saveIdentity(
          personality: i.personality,
          values: i.values,
          strengths: i.strengths,
          weaknesses: i.weaknesses,
          purpose: i.purpose,
          thisYearGoal: goal.isEmpty ? null : goal,
          bigPicture: i.bigPicture,
          lifeVision: i.lifeVision,
        );
      }
      final idByName = <String, String>{};
      for (final r in _rows) {
        final existing = r.existing;
        if (existing == null) {
          final created = await _repo.createArea(
              name: r.name, color: r.colorHex, tier: r.tier);
          idByName[r.name] = created.id;
        } else {
          if (existing.tier != r.tier) {
            await _repo.updateArea(existing.id, tier: r.tier);
          }
          idByName[r.name] = existing.id;
        }
      }
      if (_step.text.trim().isNotEmpty) {
        await _repo.createTask(
          title: _step.text.trim(),
          areaId: idByName[_stepArea],
          priority: 'HIGH',
          minimumVersion: _minimum.text.trim(),
        );
      }
      await NotificationService.instance.setNightlyTime(_time);
      await NotificationService.instance.setMorningTime(_morning);
      _repo.setNightlyTime(_time).ignore();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _pickTime(String? current, String fallback) async {
    final parts = (current ?? fallback).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: G.text(14, color: G.faint),
        filled: true,
        fillColor: G.inset,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.lineSoft, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: G.accent, width: 0.8),
        ),
      );

  Widget _timeRow(String text, VoidCallback onTap, {Widget? trailing}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: G.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: G.lineSoft, width: 0.5),
          ),
          child: Row(children: [
            Expanded(child: Text(text, style: G.text(14, color: G.ink))),
            trailing ?? Icon(Icons.schedule_rounded, size: 18, color: G.faint),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(
              color: G.accent, strokeWidth: 1.5));
    }
    final taken = _rows.map((r) => r.name.toLowerCase()).toSet();
    final presets =
        _presets.where((p) => !taken.contains(p.$1.toLowerCase())).toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined, size: 20, color: G.accent),
              const SizedBox(width: 8),
              Text('Guide Setup', style: G.voice(20, color: G.ink)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tell Ally what matters. Ally will pick the right single thing each day.',
            style: G.voice(13.5, color: G.muted),
          ),
          const SizedBox(height: 20),

          Text('WHAT DO YOU MOST WANT THIS YEAR?',
              style: G.label(size: 10.5, color: G.faint)),
          const SizedBox(height: 8),
          TextField(
            controller: _goal,
            style: G.text(14.5, color: G.ink),
            decoration: _field(
                'e.g. Master system design, get fit, speak with presence'),
          ),
          const SizedBox(height: 20),

          Text('WHAT MATTERS IN YOUR LIFE',
              style: G.label(size: 10.5, color: G.faint)),
          const SizedBox(height: 4),
          Text('One Main pillar at a time; others receive smaller doses.',
              style: G.label(size: 11, color: G.muted)),
          const SizedBox(height: 10),
          for (final r in _rows) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: G.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: G.lineSoft, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: r.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(r.name,
                            style:
                                G.text(15, w: FontWeight.w600, color: G.ink))),
                    if (r.existing == null)
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _rows.remove(r)),
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: G.faint),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (value, label) in _tiers)
                      GestureDetector(
                        onTap: () => _setTier(r, value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: r.tier == value
                                ? G.accent.withValues(alpha: 0.15)
                                : G.inset,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: r.tier == value
                                  ? G.accent
                                  : G.lineSoft,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            label,
                            style: G.text(
                              12,
                              w: r.tier == value
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: r.tier == value ? G.accent : G.muted,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _rows.isEmpty ? 'Tap presets that fit:' : 'Add other areas:',
              style: G.label(size: 11, color: G.faint),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (name, color) in presets)
                GestureDetector(
                  onTap: () => _addPreset(name, color),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: G.inset,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: G.lineSoft, width: 0.5),
                    ),
                    child: Text('+ $name',
                        style: G.text(12, color: G.muted)),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 20),

          Text('ONE SMALL STEP TO START',
              style: G.label(size: 10.5, color: G.faint)),
          const SizedBox(height: 4),
          Text('A small action that moves your Main pillar forward.',
              style: G.label(size: 11, color: G.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _step,
            style: G.text(14.5, color: G.ink),
            decoration:
                _field('e.g. Write 1 paragraph, solve 1 small problem'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _minimum,
            style: G.text(14.5, color: G.ink),
            decoration:
                _field('2-minute minimum, e.g. Open doc and write title'),
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _rows.any((r) => r.name == _stepArea)
                  ? _stepArea
                  : null,
              decoration: _field('Area'),
              style: G.text(14, color: G.ink),
              dropdownColor: G.card,
              items: [
                for (final r in _rows)
                  DropdownMenuItem(value: r.name, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _stepArea = v),
            ),
          ],
          const SizedBox(height: 20),

          Text('NUDGES (OPTIONAL)', style: G.label(size: 10.5, color: G.faint)),
          const SizedBox(height: 4),
          Text("Ally only reaches out if scheduled or asked.",
              style: G.label(size: 11, color: G.muted)),
          const SizedBox(height: 8),
          _timeRow(
            _time == null
                ? 'Nightly one thing: off'
                : 'Nightly one thing at $_time',
            () async {
              final t = await _pickTime(
                  _time, NotificationService.suggestedNightlyTime);
              if (t != null) setState(() => _time = t);
            },
            trailing: Switch(
              value: _time != null,
              activeColor: G.accent,
              onChanged: (on) async {
                if (!on) return setState(() => _time = null);
                final t = await _pickTime(
                    null, NotificationService.suggestedNightlyTime);
                if (t != null) setState(() => _time = t);
              },
            ),
          ),
          const SizedBox(height: 8),
          _timeRow(
            _morning == null
                ? 'Morning heads-up: off'
                : 'Morning heads-up at $_morning',
            () async {
              final t = await _pickTime(_morning, '08:30');
              if (t != null) setState(() => _morning = t);
            },
            trailing: Switch(
              value: _morning != null,
              activeColor: G.accent,
              onChanged: (on) async {
                if (!on) return setState(() => _morning = null);
                final t = await _pickTime(null, '08:30');
                if (t != null) setState(() => _morning = t);
              },
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: G.text(13, color: G.carried)),
          ],
          const SizedBox(height: 20),
          GButton(_saving ? 'Saving…' : 'Save configuration',
              onTap: _saving ? null : _save),
        ],
      ),
    );
  }
}
