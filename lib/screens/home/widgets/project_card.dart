import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/master_project.dart';
import '../../../models/sub_todo.dart';

/// A card representing a single master project on the home screen.
class ProjectCard extends StatelessWidget {
  final MasterProject project;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.onLongPress,
  });

  Color? get _projectColor {
    if (project.color == null) return null;
    try {
      final hex = project.color!.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectColor = _projectColor ?? theme.colorScheme.primary;
    final previewTodos = _previewTodos;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: projectColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    project.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (project.dday != null) ...[
                  const SizedBox(width: 8),
                  _DdayBadge(project: project),
                ],
              ],
            ),

            if (project.isCompletedProject) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Completed',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                project.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            if (previewTodos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Column(
                children: [
                  for (final todo in previewTodos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            todo.isCompleted
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 16,
                            color: todo.isCompleted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              todo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: todo.isCompleted
                                    ? theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.75)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            if (project.todos.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Progress bar
              _ProgressBar(progress: project.progress, color: projectColor),
              const SizedBox(height: 8),
              // Stats row
              Row(
                children: [
                  Text(
                    '${project.completedCount}/${project.todos.length} done',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${(project.progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: projectColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<SubTodo> get _previewTodos {
    final pending = project.todos.where((todo) => !todo.isCompleted).toList()
      ..sort((a, b) {
        if (a.alarm != null && b.alarm != null) {
          return a.alarm!.compareTo(b.alarm!);
        }
        if (a.alarm != null) return -1;
        if (b.alarm != null) return 1;
        return a.lineIndex.compareTo(b.lineIndex);
      });

    final completed = project.todos.where((todo) => todo.isCompleted).toList()
      ..sort((a, b) => a.lineIndex.compareTo(b.lineIndex));

    return [...pending, ...completed].take(2).toList();
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _ProgressBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: color.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class _DdayBadge extends StatelessWidget {
  final MasterProject project;
  const _DdayBadge({required this.project});

  @override
  Widget build(BuildContext context) {
    final days = project.daysUntilDday;
    if (days == null) return const SizedBox.shrink();

    Color color;
    if (days < 0) {
      color = AppColors.ddayUrgent;
    } else if (days <= 3) {
      color = AppColors.ddayUrgent;
    } else if (days <= 14) {
      color = AppColors.ddaySoon;
    } else {
      color = AppColors.ddayRelaxed;
    }

    String label;
    if (days == 0) {
      label = 'D-DAY';
    } else if (days > 0) {
      label = 'D-$days';
    } else {
      label = 'D+${days.abs()}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
