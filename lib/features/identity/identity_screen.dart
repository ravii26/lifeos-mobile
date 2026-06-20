import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_exception.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/identity.dart';
import '../../data/repositories/life_repository.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/screen_header.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  late Future<Identity> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<LifeRepository>().identity();
  }

  void _reload() =>
      setState(() => _future = getIt<LifeRepository>().identity());

  Future<void> _edit(Identity current) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IdentityForm(identity: current),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<Identity>(
        future: _future,
        builder: (context, snap) {
          final id = snap.data ?? Identity.empty;
          return ListView(
            padding: const EdgeInsets.only(bottom: 60),
            children: [
              BackHeader(eyebrow: 'Foundation', title: 'Identity'),
              if (snap.connectionState != ConnectionState.done)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent)),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Who you are and who you are becoming. The compass the rest of LifeOS points to.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.tx3)),
                      const SizedBox(height: 16),
                      if (id.isEmpty)
                        _empty(id)
                      else ...[
                        _text('Purpose', id.purpose),
                        _text('This year', id.thisYearGoal),
                        _text('Life vision', id.lifeVision),
                        _text('Big picture', id.bigPicture),
                        _text('Personality', id.personality),
                        _chips('Values', id.values, AppColors.accent),
                        _chips('Strengths', id.strengths, AppColors.health),
                        _chips('Growth edges', id.weaknesses, AppColors.warn),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _edit(id),
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: const Text('Edit identity'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: BorderSide(color: AppColors.accentLine),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(Identity id) => SurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.self_improvement, size: 34, color: AppColors.tx4),
            const SizedBox(height: 12),
            Text('Define your foundation.',
                style: TextStyle(color: AppColors.tx2, fontSize: 14)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _edit(id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Set up identity'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentInk),
            ),
          ],
        ),
      );

  Widget _text(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label),
            const SizedBox(height: 7),
            Text(value,
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.tx)),
          ],
        ),
      ),
    );
  }

  Widget _chips(String label, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final i in items) Chip3(i, color: color)],
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityForm extends StatefulWidget {
  final Identity identity;
  const _IdentityForm({required this.identity});

  @override
  State<_IdentityForm> createState() => _IdentityFormState();
}

class _IdentityFormState extends State<_IdentityForm> {
  late final TextEditingController _purpose;
  late final TextEditingController _thisYear;
  late final TextEditingController _vision;
  late final TextEditingController _bigPicture;
  late final TextEditingController _personality;
  late final TextEditingController _values;
  late final TextEditingController _strengths;
  late final TextEditingController _weaknesses;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.identity;
    _purpose = TextEditingController(text: i.purpose ?? '');
    _thisYear = TextEditingController(text: i.thisYearGoal ?? '');
    _vision = TextEditingController(text: i.lifeVision ?? '');
    _bigPicture = TextEditingController(text: i.bigPicture ?? '');
    _personality = TextEditingController(text: i.personality ?? '');
    _values = TextEditingController(text: i.values.join(', '));
    _strengths = TextEditingController(text: i.strengths.join(', '));
    _weaknesses = TextEditingController(text: i.weaknesses.join(', '));
  }

  @override
  void dispose() {
    for (final c in [
      _purpose,
      _thisYear,
      _vision,
      _bigPicture,
      _personality,
      _values,
      _strengths,
      _weaknesses
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _list(TextEditingController c) => c.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String? _nullable(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await getIt<LifeRepository>().saveIdentity(
        purpose: _nullable(_purpose),
        thisYearGoal: _nullable(_thisYear),
        lifeVision: _nullable(_vision),
        bigPicture: _nullable(_bigPicture),
        personality: _nullable(_personality),
        values: _list(_values),
        strengths: _list(_strengths),
        weaknesses: _list(_weaknesses),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Edit identity',
      children: [
        formLabel('Purpose'),
        formField(_purpose, 'Why you do what you do', lines: 2),
        const SizedBox(height: 12),
        formLabel('This year'),
        formField(_thisYear, "This year's defining goal", lines: 2),
        const SizedBox(height: 12),
        formLabel('Life vision'),
        formField(_vision, 'The life you are building', lines: 2),
        const SizedBox(height: 12),
        formLabel('Big picture'),
        formField(_bigPicture, 'The wider arc', lines: 2),
        const SizedBox(height: 12),
        formLabel('Personality'),
        formField(_personality, 'How you tend to operate', lines: 2),
        const SizedBox(height: 12),
        formLabel('Values (comma-separated)'),
        formField(_values, 'e.g. honesty, growth, freedom'),
        const SizedBox(height: 12),
        formLabel('Strengths (comma-separated)'),
        formField(_strengths, 'e.g. focus, curiosity'),
        const SizedBox(height: 12),
        formLabel('Growth edges (comma-separated)'),
        formField(_weaknesses, 'e.g. patience, rest'),
        const SizedBox(height: 22),
        saveButton(_saving, _save, 'Save identity'),
      ],
    );
  }
}
