import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../appearance/appearance_cubit.dart';
import '../auth/bloc/auth_bloc.dart';
import '../goals/goals_screen.dart';
import '../shell/life_cubit.dart';
import '../vault/vault_screen.dart';
import '../chat/memories_screen.dart';
import 'settings_screen.dart';
import 'taught_notes_screen.dart';
import 'where_you_stand_screen.dart';
import 'your_day_screen.dart';

class MoreSheet extends StatelessWidget {
  final AppUser user;
  const MoreSheet({super.key, required this.user});

  // Ally keeps only what helps you act. Removed from the app (data and server
  // kept, so they can return): Home, What now, Projects, Learn, Library,
  // Notebooks, Graph, Behaviour, Calendar, Review, Identity, Focus, Modules.

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: AppColors.glassBg2,
            border: Border(top: BorderSide(color: AppColors.glassBorder)),
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 34 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: AppColors.line3,
                    borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [AppColors.accent, AppColors.career],
                      ),
                    ),
                    child: Center(
                      child: Text(user.initial,
                          style: GoogleFonts.hankenGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0A0C08))),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.tx3)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: BlocBuilder<AppearanceCubit, AppearanceState>(
                    builder: (context, appearance) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _row(context, 'Goals', "What you're aiming at",
                          Icons.flag_outlined, () => const GoalsScreen()),
                      _row(context, 'What Ally remembers', 'See or delete what Ally knows about you',
                          Icons.psychology_alt_outlined, () => const MemoriesScreen()),
                      _row(context, 'Notes you taught Ally', 'Lists, routines and info Ally answers from',
                          Icons.sticky_note_2_outlined, () => const TaughtNotesScreen()),
                      _row(context, 'Where you stand', 'Stage, trend and pace on each goal',
                          Icons.trending_up_rounded, () => const WhereYouStandScreen()),
                      _row(context, 'Your day', 'How Ally thinks your days run',
                          Icons.schedule_rounded, () => const YourDayScreen()),
                      _row(context, 'Hard days', 'What helps when a day is heavy',
                          Icons.favorite_border_rounded, () => const VaultScreen()),
                      const SizedBox(height: 6),
                      const Divider(height: 24),
                      _row(context, 'Settings', 'Profile, vibe & preferences',
                          Icons.settings_outlined,
                          () => SettingsScreen(user: user)),
                      const SizedBox(height: 6),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.logout, color: AppColors.danger),
                        title: const Text('Sign out',
                            style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.of(context).pop();
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                      ),
                    ],
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String name, String desc, IconData icon,
      Widget Function() destination) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        final cubit = context.read<LifeCubit>();
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: destination(),
          ),
        ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: AppColors.tx),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(desc,
                      style:
                          TextStyle(fontSize: 12, color: AppColors.tx3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.tx4),
          ],
        ),
      ),
    );
  }
}
