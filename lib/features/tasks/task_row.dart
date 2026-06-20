import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/area.dart';
import '../../data/models/task.dart';
import '../../widgets/bits.dart';

/// Swipe-right-to-complete, swipe-left-to-delete task row — `MTaskRow`.
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
    final areaColor = area?.color ?? AppColors.tx3;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    color: task.isDone ? AppColors.tx4 : AppColors.tx,
                    decoration:
                        task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    AreaDot(areaColor, size: 6),
                    const SizedBox(width: 5),
                    Text(area?.name ?? '—',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: areaColor)),
                    if (task.source != null &&
                        task.source!.toUpperCase() != 'MANUAL') ...[
                      const SizedBox(width: 8),
                      Text('↳ ${task.source}',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 9, color: AppColors.tx3)),
                    ],
                    if (task.kind == 'count') ...[
                      const SizedBox(width: 8),
                      Text('${task.completedCount}/${task.targetCount}',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5, color: AppColors.tx3)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PriorityTag(task.priorityLabel),
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
          return false; // keep row; list refresh will remove it
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: left
              ? [AppColors.accent, AppColors.accent2]
              : [const Color(0xFF2A2D34), AppColors.danger],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: left
            ? [
                Icon(Icons.check, size: 16, color: AppColors.accentInk),
                SizedBox(width: 8),
                Text('Complete',
                    style: TextStyle(
                        color: AppColors.accentInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]
            : const [
                Text('Delete',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, size: 16, color: Colors.white),
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: done ? AppColors.accent : AppColors.line3, width: 1.6),
          ),
          child: done
              ? Icon(Icons.check, size: 15, color: AppColors.accentInk)
              : null,
        ),
      );
}
