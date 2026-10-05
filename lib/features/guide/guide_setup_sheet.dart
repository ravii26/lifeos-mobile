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
    backgroundColor: G.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: _GuideSetup()),
  );
  await cubit.load();
}

const _tiers = [
  ('MAIN', 'Main'),
  ('SECONDARY', 'Secondary'),
  ('MAINTAIN', 'Maintain'),
  ('LATER', 'Later'),
];

/// Common life areas a new person can add in one tap. Name + colour only;
/// anything else can be added from the Areas tab.
const _presets = [
  ('Career', '#4b55d6'),
  ('Health & fitness', '#2e9e5b'),
  ('Communication', '#12a39a'),
  ('Learning', '#9b6bdf'),
  ('Money', '#b7791f'),
  ('Relationships', '#d65a5a'),
  ('Hobbies', '#e08a2e'),
  ('Mind', '#6b7280'),
];

/// One row in the areas list: an existing area, or a new one created on save.
class _AreaRow {
  final Area? existing;
  final String name;
  final String colorHex;
  String tier;
  _AreaRow({this.existing, required this.name, required this.colorHex, required this.tier});

  Color get color => Color(int.parse('FF${colorHex.replaceFirst('#', '')}', radix: 16));
}

/// Everything the guide needs to choose well, for anyone starting from zero:
/// the big goal, which areas matter and how much, one small step, and when
/// the guide should reach them.
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
  String? _stepArea; // area name
  String? _time; // nightly nudge, off unless the person turns it on
  String? _morning; // optional heads-up
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
      final areas = (results[0] as List<Area>).where((a) => a.isActive).toList();
      setState(() {
        _identity = results[1] as Identity;
        _goal.text = _identity.thisYearGoal ?? '';
        _rows.addAll(areas.map(
            (a) => _AreaRow(existing: a, name: a.name, colorHex: a.colorHex, tier: a.tier)));
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
          // The first area someone adds is usually the one they care about most.
          tier: _rows.any((r) => r.tier == 'MAIN') ? 'SECONDARY' : 'MAIN',
        ));
        _stepArea ??= name;
      });

  void _setTier(_AreaRow row, String tier) => setState(() {
        // One Main at a time keeps "what matters most" honest.
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
          final created = await _repo.createArea(name: r.name, color: r.colorHex, tier: r.tier);
          idByName[r.name] = created.id;
        } else {
          if (existing.tier != r.tier) await _repo.updateArea(existing.id, tier: r.tier);
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
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  InputDecoration _field(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: G.text(16, color: G.muted),
        filled: true,
        fillColor: G.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );

  Widget _timeRow(String text, VoidCallback onTap, {Widget? trailing}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text(text, style: G.text(16))),
            trailing ?? const Icon(Icons.schedule_rounded, color: G.muted),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: G.ink, strokeWidth: 2));
    }
    final taken = _rows.map((r) => r.name.toLowerCase()).toSet();
    final presets = _presets.where((p) => !taken.contains(p.$1.toLowerCase())).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Your guide', style: G.display(30)),
          const SizedBox(height: 6),
          Text('Tell me what matters. I pick one small thing each day, and you ask me for it whenever you like.',
              style: G.voice(17)),
          const SizedBox(height: 24),

          Text('WHAT DO YOU MOST WANT THIS YEAR?', style: G.label()),
          const SizedBox(height: 8),
          TextField(
            controller: _goal,
            style: G.text(16),
            decoration: _field('e.g. A better job, getting fit, speaking confidently'),
          ),
          const SizedBox(height: 24),

          Text('WHAT MATTERS IN YOUR LIFE', style: G.label()),
          const SizedBox(height: 4),
          Text('Nothing is dropped, only ordered. One Main, the rest get smaller doses.',
              style: G.text(14, color: G.muted)),
          const SizedBox(height: 10),
          for (final r in _rows) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration:
                  BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: r.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.name, style: G.display(18, w: FontWeight.w800))),
                    if (r.existing == null)
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _rows.remove(r)),
                        icon: const Icon(Icons.close_rounded, size: 18, color: G.muted),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (value, label) in _tiers)
                      ChoiceChip(
                        label: Text(label),
                        selected: r.tier == value,
                        onSelected: (_) => _setTier(r, value),
                        labelStyle: G.text(14,
                            w: FontWeight.w700, color: r.tier == value ? Colors.white : G.ink),
                        selectedColor: G.ink,
                        backgroundColor: G.soft,
                        showCheckmark: false,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_rows.isEmpty ? 'Tap the ones that matter to you' : 'Add more',
                style: G.text(14, color: G.muted, w: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (name, color) in presets)
                ActionChip(
                  label: Text('+ $name', style: G.text(15, w: FontWeight.w500)),
                  backgroundColor: G.card,
                  side: const BorderSide(color: G.line),
                  shape: const StadiumBorder(),
                  onPressed: () => _addPreset(name, color),
                ),
            ]),
          ],
          const SizedBox(height: 24),

          Text('ONE SMALL STEP TO START', style: G.label()),
          const SizedBox(height: 4),
          Text('Something that moves what matters most. Keep it small.',
              style: G.text(14, color: G.muted)),
          const SizedBox(height: 10),
          TextField(
            controller: _step,
            style: G.text(16),
            decoration: _field('e.g. Solve one easy coding problem'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _minimum,
            style: G.text(16),
            decoration: _field('The 2-minute version, e.g. Just read the problem'),
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _rows.any((r) => r.name == _stepArea) ? _stepArea : null,
              decoration: _field('Which area?'),
              style: G.text(16),
              dropdownColor: G.card,
              items: [
                for (final r in _rows) DropdownMenuItem(value: r.name, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _stepArea = v),
            ),
          ],
          const SizedBox(height: 24),

          Text('NUDGES (OPTIONAL)', style: G.label()),
          const SizedBox(height: 4),
          Text(
              "I never message you unless you turn this on. You can also just tell me in chat, "
              "like \"nudge me every night at 9:30\".",
              style: G.text(14, color: G.muted)),
          const SizedBox(height: 8),
          _timeRow(
            _time == null ? 'Nightly one thing: off' : 'Nightly one thing at $_time',
            () async {
              final t = await _pickTime(_time, NotificationService.suggestedNightlyTime);
              if (t != null) setState(() => _time = t);
            },
            trailing: Switch(
              value: _time != null,
              activeTrackColor: G.ink,
              onChanged: (on) async {
                if (!on) return setState(() => _time = null);
                final t = await _pickTime(null, NotificationService.suggestedNightlyTime);
                if (t != null) setState(() => _time = t);
              },
            ),
          ),
          const SizedBox(height: 8),
          _timeRow(
            _morning == null ? 'Morning heads-up: off' : 'Morning heads-up at $_morning',
            () async {
              final t = await _pickTime(_morning, '08:30');
              if (t != null) setState(() => _morning = t);
            },
            trailing: Switch(
              value: _morning != null,
              activeTrackColor: G.ink,
              onChanged: (on) async {
                if (!on) return setState(() => _morning = null);
                final t = await _pickTime(null, '08:30');
                if (t != null) setState(() => _morning = t);
              },
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: G.text(14, color: const Color(0xFFB3261E))),
          ],
          const SizedBox(height: 24),
          GButton(_saving ? 'Saving…' : 'Save', onTap: _saving ? null : _save),
        ],
      ),
    );
  }
}
