import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/bits.dart';
import 'appearance_cubit.dart';

/// Bottom-sheet "Tweaks" panel — accent, display font, and session vibe.
/// All changes persist to the backend /settings and re-skin the app live.
class TweaksSheet extends StatelessWidget {
  const TweaksSheet({super.key});

  static const _fonts = [
    ('inter', 'Sans'),
    ('mono', 'Mono'),
    ('serif', 'Serif'),
  ];
  static const _vibes = ['calm', 'focused', 'energetic'];
  static const _densities = ['compact', 'cozy', 'comfy'];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg2,
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          child: BlocBuilder<AppearanceCubit, AppearanceState>(
            builder: (context, s) {
              final cubit = context.read<AppearanceCubit>();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: AppColors.line3,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tweaks',
                      style: GoogleFonts.hankenGrotesk(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  Eyebrow('Mode'),
                  const SizedBox(height: 12),
                  _segment(
                    options: const ['Dark', 'Light'],
                    selectedIndex: s.light ? 1 : 0,
                    onSelect: (i) => cubit.setLight(i == 1),
                  ),
                  const SizedBox(height: 22),
                  Eyebrow('Accent'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final a in AppAccent.all)
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () => cubit.setAccent(a),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: a.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: s.accent.color == a.color
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: s.accent.color == a.color
                                  ? Icon(Icons.check, size: 18, color: a.ink)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Eyebrow('Display font'),
                  const SizedBox(height: 12),
                  _segment(
                    options: _fonts.map((f) => f.$2).toList(),
                    selectedIndex:
                        _fonts.indexWhere((f) => f.$1 == s.font).clamp(0, 2),
                    onSelect: (i) => cubit.setFont(_fonts[i].$1),
                  ),
                  const SizedBox(height: 22),
                  Eyebrow('Density'),
                  const SizedBox(height: 12),
                  _segment(
                    options: _densities
                        .map((d) => d[0].toUpperCase() + d.substring(1))
                        .toList(),
                    selectedIndex: _densities.indexOf(s.density).clamp(0, 2),
                    onSelect: (i) => cubit.setDensity(_densities[i]),
                  ),
                  const SizedBox(height: 22),
                  Eyebrow('Session vibe'),
                  const SizedBox(height: 12),
                  _segment(
                    options: _vibes
                        .map((v) => v[0].toUpperCase() + v.substring(1))
                        .toList(),
                    selectedIndex: _vibes.indexOf(s.vibe).clamp(0, 2),
                    onSelect: (i) => cubit.setVibe(_vibes[i]),
                  ),
                  const SizedBox(height: 18),
                  Text(
                      'Saved to your account — the web app reads the same preferences.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.tx4)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _segment({
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? AppColors.surface4
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(options[i],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: i == selectedIndex
                                ? AppColors.tx
                                : AppColors.tx3)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
