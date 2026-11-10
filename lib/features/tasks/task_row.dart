import 'package:flutter/material.dart';

import '../../data/models/area.dart';
import '../../data/models/task.dart';
import '../guide/guide_style.dart';

/// One to-do in a list: a round tick, the title, and a quiet line about it.
class TaskRow extends StatelessWidget {
  final Task task;
  final Area? area;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  const TaskRow({
    super.key,
    required this.task,
    this.area,
    required this.onComplete,
    required this.onDelete,
  });

  String get _meta => [
        if (area != null) area!.name,
        if (task.kind == 'count') '${task.completedCount} of ${task.targetCount}',
        if (task.priorityLabel == 'P1') 'High',
      ].join(', ');

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(color: G.card, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          _Check(done: task.isDone, onTap: onComplete),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: G.text(19, color: task.isDone ? G.muted : G.ink, height: 1.25).copyWith(
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: G.muted,
                      ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: G.text(15, color: G.muted, height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (task.isDone) return content;

    return Dismissible(
      key: ValueKey(task.id),
      background: _swipeBg(left: true),
      secondaryBackground: _swipeBg(left: false),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onComplete();
          return false;
        }
        onDelete();
        return true;
      },
      child: content,
    );
  }

  Widget _swipeBg({required bool left}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: G.surfaceHigh),
      child: Text(left ? 'Done' : 'Remove', style: G.text(17, w: FontWeight.w500, color: left ? G.accent : G.ink, height: 1.2)),
    );
  }
}

class _Check extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _Check({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? G.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: done ? G.accent : G.faint, width: 2),
              ),
              child: done ? Icon(Icons.check_rounded, size: 19, color: G.onInk) : null,
            ),
          ),
        ),
      );
}
