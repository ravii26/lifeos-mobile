import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../widgets/bits.dart';
import '../../widgets/glass.dart';
import '../../widgets/screen_header.dart';
import '../shell/life_cubit.dart';
import 'area_detail_screen.dart';
import 'area_form.dart';

void openAreaForm(BuildContext context, {Area? area}) {
  final cubit = context.read<LifeCubit>();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: AreaForm(area: area),
    ),
  );
}

class AreasScreen extends StatelessWidget {
  final VoidCallback onOpenMore;
  const AreasScreen({super.key, required this.onOpenMore});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface2,
          onRefresh: () => context.read<LifeCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                eyebrow: 'Insights',
                title: 'Life areas',
                avatarInitial: '·',
                onMore: onOpenMore,
                subtitle: Text('Overall balance · ${s.avgScore} avg'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (s.areas.isEmpty)
                      SurfaceCard(
                        padding: EdgeInsets.all(26),
                        child: Center(
                            child: Text('No areas yet.',
                                style: TextStyle(
                                    color: AppColors.tx4, fontSize: 13))),
                      )
                    else
                      for (final a in s.areas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: GestureDetector(
                            onTap: () {
                              final cubit = context.read<LifeCubit>();
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: cubit,
                                  child: AreaDetailScreen(areaId: a.id),
                                ),
                              ));
                            },
                            onLongPress: () =>
                                openAreaForm(context, area: a),
                            child: _AreaCard(area: a),
                          ),
                        ),
                    const SizedBox(height: 4),
                    AddTile(
                        label: 'New area',
                        onTap: () => openAreaForm(context)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AreaCard extends StatelessWidget {
  final Area area;
  const _AreaCard({required this.area});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Donut(
            value: area.score.toDouble(),
            size: 64,
            stroke: 6,
            color: area.color,
            center: Text('${area.score}',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.tx)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AreaDot(area.color, size: 9),
                    const SizedBox(width: 8),
                    Text(area.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: area.color)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip3('${area.tasksDone}/${area.tasksTotal} tasks'),
                    Chip3('${area.streak}d streak',
                        icon: Icons.local_fire_department),
                    Chip3('${area.focusMins}m focus'),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressBar(area.score / 100, color: area.color),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
