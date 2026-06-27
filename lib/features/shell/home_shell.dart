import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/modules/module_registry.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../../data/repositories/life_repository.dart';
import '../appearance/appearance_cubit.dart';
import '../areas/areas_screen.dart';
import '../capture/capture_sheet.dart';
import '../habits/habits_screen.dart';
import '../home/home_screen.dart';
import '../more/more_sheet.dart';
import '../tasks/tasks_screen.dart';
import 'life_cubit.dart';

/// A bottom-nav destination. Built dynamically so optional modules (Habits)
/// drop out when the user disables them.
class _TabDef {
  final String label;
  final IconData icon;
  final IconData iconActive;
  final Widget screen;
  const _TabDef(this.label, this.icon, this.iconActive, this.screen);
}

class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.requestPermission();
    // Behaviour signal: the app was opened (once per session, on shell mount).
    getIt<LifeRepository>().recordBehavior('APP_OPEN').ignore();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LifeCubit(getIt<LifeRepository>())..load(),
      child: Builder(builder: (context) {
        return BlocBuilder<AppearanceCubit, AppearanceState>(
          buildWhen: (a, b) => a.rawModules != b.rawModules,
          builder: (context, appearance) {
            final tabs = _buildTabs(context, appearance);
            final index = _index.clamp(0, tabs.length - 1);
            return Scaffold(
              backgroundColor: AppColors.bg,
              extendBody: true,
              body: BlocListener<LifeCubit, LifeState>(
                listenWhen: (prev, curr) =>
                    curr.error != null && curr.error != prev.error,
                listener: (context, state) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(state.error!),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                    ));
                  context.read<LifeCubit>().clearError();
                },
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.85, -1),
                      radius: 1.1,
                      colors: [Color(0x22C5F23F), Colors.transparent],
                      stops: [0, 0.55],
                    ),
                  ),
                  child: IndexedStack(
                      index: index,
                      children: [for (final t in tabs) t.screen]),
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              floatingActionButton:
                  _CaptureFab(onTap: () => _openCapture(context)),
              bottomNavigationBar: _BottomNav(
                tabs: tabs,
                index: index,
                onTap: (i) => setState(() => _index = i),
              ),
            );
          },
        );
      }),
    );
  }

  /// Bottom-nav tabs: Home + Tasks (core) + Habits (optional) + Areas (core).
  List<_TabDef> _buildTabs(BuildContext context, AppearanceState appearance) {
    void openMore() => _openMore(context);
    return [
      _TabDef('Home', Icons.dashboard_outlined, Icons.dashboard,
          HomeScreen(user: widget.user, onOpenMore: openMore)),
      _TabDef('Tasks', Icons.check_circle_outline, Icons.check_circle,
          TasksScreen(onOpenMore: openMore)),
      if (appearance.isEnabled(ModuleId.habits))
        _TabDef('Habits', Icons.repeat_rounded, Icons.repeat_rounded,
            HabitsScreen(onOpenMore: openMore)),
      _TabDef('Areas', Icons.grid_view_outlined, Icons.grid_view_rounded,
          AreasScreen(onOpenMore: openMore)),
    ];
  }

  void _openCapture(BuildContext context) {
    final cubit = context.read<LifeCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const CaptureSheet(),
      ),
    );
  }

  void _openMore(BuildContext context) {
    final cubit = context.read<LifeCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: MoreSheet(user: widget.user),
      ),
    );
  }
}

class _CaptureFab extends StatelessWidget {
  final VoidCallback onTap;
  const _CaptureFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent2, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.accentGlow, blurRadius: 24, spreadRadius: 1),
              BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(Icons.bolt, color: AppColors.accentInk, size: 26),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final List<_TabDef> tabs;
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav(
      {required this.tabs, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final todo = context.select<LifeCubit, int>((c) => c.state.todayTasks.length);
    // Split tabs evenly around the center FAB slot.
    final split = (tabs.length / 2).ceil();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.glassBg2,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 30, offset: Offset(0, 14)),
              ],
            ),
            child: Row(
              children: [
                for (int i = 0; i < split; i++) _tab(i, todo),
                const SizedBox(width: 64), // FAB slot
                for (int i = split; i < tabs.length; i++) _tab(i, todo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, int todo) {
    final t = tabs[i];
    final active = index == i;
    final badge = t.label == 'Tasks' ? todo : 0;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(i),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(active ? t.iconActive : t.icon,
                    size: 22,
                    color: active ? AppColors.accent : AppColors.tx4),
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 15),
                      height: 15,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      child: Center(
                        child: Text('$badge',
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentInk)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(t.label,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.tx : AppColors.tx4)),
          ],
        ),
      ),
    );
  }
}
