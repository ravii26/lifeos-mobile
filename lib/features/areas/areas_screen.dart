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

/// One plain line about a part of life. Says what happened and never scores it.
String areaLine(int done, int total, int focusMinutes) {
  final todos = total == 0 ? 'No to-dos yet' : '$done of $total to-dos done';
  return focusMinutes > 0 ? '$todos. $focusMinutes min focused.' : '$todos.';
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
          appBar: gBar(actions: [
            IconButton(
              tooltip: 'Add a part of life',
              icon: Icon(Icons.add_rounded, size: 28, color: G.accent),
              onPressed: () => openAreaForm(context),
            ),
          ]),
          body: RefreshIndicator(
            color: G.accent,
            backgroundColor: G.card,
            onRefresh: () => context.read<LifeCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              children: [
                const GTitle('Parts of my life', sub: 'Ally spreads your days across these, so nothing important goes quiet.'),
                if (s.areas.isEmpty)
                  const GEmpty('Nothing here yet. Add the big parts of your life, like Health, Work or Family.')
                else
                  for (final a in s.areas)
                    GCard(
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
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: a.color)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(a.name, style: G.text(23, w: FontWeight.w500, height: 1.2))),
                        ]),
                        const SizedBox(height: 6),
                        Text(areaLine(a.tasksDone, a.tasksTotal, a.focusMins), style: G.text(16, color: G.muted, height: 1.3)),
                      ]),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
