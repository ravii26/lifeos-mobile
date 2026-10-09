import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/user.dart';
import '../appearance/appearance_cubit.dart';
import '../appearance/tweaks_sheet.dart';
import '../auth/bloc/auth_bloc.dart';
import '../guide/guide_style.dart';

class SettingsScreen extends StatelessWidget {
  final AppUser user;
  const SettingsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: G.bg,
      appBar: const GTopBar(
        'Settings',
        subtitle: 'Account & preferences',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: G.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: G.lineSoft, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: G.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: G.accent.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.initial,
                      style: G.text(18,
                          w: FontWeight.w700, color: G.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: G.text(16,
                            w: FontWeight.w600, color: G.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: G.label(size: 11, color: G.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: G.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: G.lineSoft, width: 0.5),
            ),
            child: Row(
              children: [
                BlocBuilder<AppearanceCubit, AppearanceState>(
                  builder: (context, s) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: s.accent.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance & Taste',
                        style: G.text(14,
                            w: FontWeight.w500, color: G.ink),
                      ),
                      Text(
                        'Accent tone, dark mode & font',
                        style: G.label(size: 11, color: G.faint),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    final cubit = context.read<AppearanceCubit>();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BlocProvider.value(
                        value: cubit,
                        child: const TweaksSheet(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: G.lineSoft, width: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  child: Text('Adjust',
                      style: G.label(size: 11, color: G.accent)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<AuthBloc>().add(const AuthLogoutRequested());
              },
              icon: Icon(Icons.logout_rounded, size: 16, color: G.carried),
              label: Text('Sign out',
                  style: G.text(13.5,
                      w: FontWeight.w500, color: G.carried)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: G.carried.withValues(alpha: 0.35),
                  width: 0.5,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Ally · Personal Assistant · Nocturne Sanctuary',
              style: G.label(size: 10, color: G.faint),
            ),
          ),
        ],
      ),
    );
  }
}
