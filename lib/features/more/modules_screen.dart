import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/modules/module_registry.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../appearance/appearance_cubit.dart';

/// Lets the user choose which optional modules LifeOS shows. Core modules are
/// listed as always-on (locked). Turning a module off only hides it — its data
/// is never deleted.
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocBuilder<AppearanceCubit, AppearanceState>(
        builder: (context, s) {
          final cubit = context.read<AppearanceCubit>();
          final core = Modules.all.where((m) => m.core).toList();
          final optional = Modules.all.where((m) => !m.core).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              const BackHeader(
                eyebrow: 'Personalize',
                title: 'Modules',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Pick what LifeOS shows. Turning a module off hides it everywhere — '
                  'your data stays safe and comes back when you re-enable it.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.tx3, height: 1.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _eyebrow('Always on'),
                    for (final m in core) _tile(context, m, true, null),
                    const SizedBox(height: 18),
                    _eyebrow('Optional'),
                    for (final m in optional)
                      _tile(context, m, s.enabled.contains(m.key),
                          (on) => cubit.toggleModule(m.key, on)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _eyebrow(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 0, 10),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.tx4)),
      );

  Widget _tile(BuildContext context, ModuleDef m, bool on,
      ValueChanged<bool>? onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(m.icon, size: 19, color: AppColors.tx),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(m.desc,
                      style: TextStyle(fontSize: 12, color: AppColors.tx3)),
                ],
              ),
            ),
            if (onChanged == null)
              Icon(Icons.lock_outline, size: 18, color: AppColors.tx4)
            else
              Switch(
                value: on,
                onChanged: onChanged,
                activeThumbColor: AppColors.accentInk,
                activeTrackColor: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}
