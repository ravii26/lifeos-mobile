import 'package:flutter/material.dart';

import '../../data/models/area.dart';
import '../../data/models/task.dart';
import '../guide/guide_style.dart';

/// Planar Nocturne task row with hairline border, square checkbox, and gentle actions.
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

  @override
  Widget build(BuildContext context) {
    final areaColor = area?.color ?? G.faint;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: G.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: G.lineSoft, width: 0.5),
      ),
      child: Row(
        children: [
          _Check(done: task.isDone, onTap: onComplete),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: G.text(
                    14,
                    w: FontWeight.w400,
                    color: task.isDone ? G.faint : G.ink,
                  ).copyWith(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: areaColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      area?.name ?? '—',
                      style: G.label(size: 10.5, color: areaColor),
                    ),
                    if (task.source != null &&
                        task.source!.toUpperCase() != 'MANUAL') ...[
                      const SizedBox(width: 6),
                      Text(
                        '↳ ${task.source}',
                        style: G.label(size: 9.5, color: G.faint),
                      ),
                    ],
                    if (task.kind == 'count') ...[
                      const SizedBox(width: 6),
                      Text(
                        '${task.completedCount}/${task.targetCount}',
                        style: G.label(size: 10, color: G.muted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (task.priorityLabel.isNotEmpty && task.priorityLabel != 'NONE') ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: G.inset,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: G.lineSoft, width: 0.5),
              ),
              child: Text(
                task.priorityLabel,
                style: G.label(size: 9.5, color: G.faint),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: left
            ? G.good.withValues(alpha: 0.15)
            : G.carried.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: left
            ? [
                Icon(Icons.check, size: 15, color: G.good),
                const SizedBox(width: 6),
                Text('Complete',
                    style: G.text(12,
                        w: FontWeight.w600, color: G.good)),
              ]
            : [
                Text('Remove',
                    style: G.text(12,
                        w: FontWeight.w600, color: G.carried)),
                const SizedBox(width: 6),
                Icon(Icons.delete_outline, size: 15, color: G.carried),
              ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _Check({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: done ? G.good : G.inset,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: done ? G.good : G.lineSoft,
              width: 0.8,
            ),
          ),
          child: done
              ? Icon(Icons.check, size: 13, color: G.onInk)
              : null,
        ),
      );
}
