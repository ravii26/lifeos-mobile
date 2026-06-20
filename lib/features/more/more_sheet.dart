import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../../widgets/bits.dart';
import '../auth/bloc/auth_bloc.dart';
import '../behavior/behavior_screen.dart';
import '../calendar/calendar_screen.dart';
import '../goals/goals_screen.dart';
import '../graph/graph_screen.dart';
import '../identity/identity_screen.dart';
import '../learn/learn_screen.dart';
import '../notebooks/notebooks_screen.dart';
import '../now/now_screen.dart';
import '../projects/projects_screen.dart';
import '../review/review_screen.dart';
import '../shell/life_cubit.dart';
import '../vault/vault_screen.dart';
import 'settings_screen.dart';

class MoreSheet extends StatelessWidget {
  final AppUser user;
  const MoreSheet({super.key, required this.user});

  static const _items = [
    ('What now', 'Your next best move', Icons.bolt_outlined),
    ('Goals', 'What you\'re aiming at', Icons.flag_outlined),
    ('Projects', 'Bodies of work in motion', Icons.account_tree_outlined),
    ('Notebooks', 'Topics, notebooks & notes', Icons.menu_book_outlined),
    ('Identity', 'Purpose, values & vision', Icons.self_improvement),
    ('Graph', 'How everything connects', Icons.hub_outlined),
    ('Behaviour', 'Your activity signals', Icons.insights_outlined),
    ('Calendar', 'Time-blocked day', Icons.calendar_today_outlined),
    ('Weekly Review', 'Reflect & integrate insights', Icons.refresh),
    ('Learn', 'Courses, notes & resources', Icons.school_outlined),
    ('Vault', 'Wins, quotes & protocols', Icons.lock_outline),
    ('Settings', 'Profile, vibe & preferences', Icons.settings_outlined),
  ];

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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
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
              for (final item in _items)
                _row(context, item.$1, item.$2, item.$3,
                    badge: item.$1 == 'Weekly Review' ? 0 : 0),
              const SizedBox(height: 6),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Sign out',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String name, String desc, IconData icon,
      {int badge = 0}) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        final cubit = context.read<LifeCubit>();
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: _destination(name),
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
            if (badge > 0) Chip3('$badge', color: AppColors.accent, bg: AppColors.accentSoft),
            Icon(Icons.chevron_right, color: AppColors.tx4),
          ],
        ),
      ),
    );
  }

  Widget _destination(String name) => switch (name) {
        'Settings' => SettingsScreen(user: user),
        'What now' => const NowScreen(),
        'Goals' => const GoalsScreen(),
        'Projects' => const ProjectsScreen(),
        'Notebooks' => const KnowledgeScreen(),
        'Identity' => const IdentityScreen(),
        'Graph' => const GraphScreen(),
        'Behaviour' => const BehaviorScreen(),
        'Calendar' => const CalendarScreen(),
        'Weekly Review' => const ReviewScreen(),
        'Learn' => const LearnScreen(),
        'Vault' => const VaultScreen(),
        _ => SettingsScreen(user: user),
      };
}
