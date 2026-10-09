import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/area.dart';
import '../guide/guide_style.dart';
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
  final VoidCallback? onOpenMore;
  const AreasScreen({super.key, this.onOpenMore});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LifeCubit, LifeState>(
      builder: (context, s) {
        return Scaffold(
          backgroundColor: G.bg,
          appBar: GTopBar(
            'Life Areas',
            subtitle: 'Balance · ${s.avgScore} avg',
            showBack: true,
            trailing: IconButton(
              icon: Icon(Icons.add, size: 20, color: G.accent),
              onPressed: () => openAreaForm(context),
            ),
          ),
          body: RefreshIndicator(
            color: G.accent,
            backgroundColor: G.card,
            onRefresh: () => context.read<LifeCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: G.inset,
                    border: Border.all(color: G.lineSoft, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.category_outlined, size: 16, color: G.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your life pillars. Ally balances daily suggestions across what matters most without guilt.',
                          style: G.voice(13.5, color: G.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (s.areas.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: G.card,
                      border: Border.all(color: G.lineSoft, width: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'No life areas set up yet.\nCreate areas like Health, Career, or Mind to organize goals.',
                        textAlign: TextAlign.center,
                        style: G.voice(14, color: G.muted),
                      ),
                    ),
                  )
                else
                  for (final a in s.areas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                        onLongPress: () => openAreaForm(context, area: a),
                        child: _AreaCard(area: a),
                      ),
                    ),
              ],
            ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: G.card,
        border: Border.all(color: G.lineSoft, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: area.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  area.name,
                  style: G.text(15, w: FontWeight.w600, color: G.ink),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: G.inset,
                  border: Border.all(color: G.lineSoft, width: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${area.score}%',
                  style: G.label(size: 11, color: G.faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${area.tasksDone}/${area.tasksTotal} tasks',
                style: G.label(size: 11, color: G.muted),
              ),
              Text(' · ', style: G.label(size: 11, color: G.faint)),
              Text(
                '${area.streak}d streak',
                style: G.label(size: 11, color: G.muted),
              ),
              Text(' · ', style: G.label(size: 11, color: G.faint)),
              Text(
                '${area.focusMins}m focus',
                style: G.label(size: 11, color: G.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: G.inset,
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (area.score / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: area.color.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
