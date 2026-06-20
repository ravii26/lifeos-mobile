import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../appearance/appearance_cubit.dart';
import '../appearance/tweaks_sheet.dart';
import '../auth/bloc/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const BackHeader(eyebrow: 'Support', title: 'Settings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                              colors: [AppColors.accent, AppColors.career]),
                        ),
                        child: Center(
                          child: Text(user.initial,
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0A0C08))),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            Text(user.email,
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.tx3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Row(
                    children: [
                      BlocBuilder<AppearanceCubit, AppearanceState>(
                        builder: (context, s) => Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: s.accent.color, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Appearance',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            Text('Accent, font & vibe',
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.tx3)),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          final cubit = context.read<AppearanceCubit>();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => BlocProvider.value(
                              value: cubit, child: const TweaksSheet()),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surface3,
                          foregroundColor: AppColors.tx,
                        ),
                        child: const Text('Tweaks'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context
                          .read<AuthBloc>()
                          .add(const AuthLogoutRequested());
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: Color(0x4DFF5D62)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('LifeOS Mobile · v1.0 · Personal Operating System',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.tx4, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
