import 'package:flutter/material.dart';
import '../../../core/color_utils.dart';
import '../../../core/date_formatters.dart';
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

  /// Parses bgColor and returns a very subtle tint suitable for card background.
  /// The stored alpha is halved further so the card tint is barely visible.
  Color? _cardBgTint(Color cardBase) {
    final parsed = parseBgColor(project.bgColor);
    if (parsed == null) return null;
    // Use half the stored alpha for a subtle card tint
    final tintAlpha = (parsed.a * 0.5).clamp(0.0, 0.15);
    return Color.lerp(cardBase, parsed.withValues(alpha: 1.0), tintAlpha);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectColor = _projectColor ?? theme.colorScheme.primary;
    final cardBg = _cardBgTint(theme.cardColor) ?? theme.cardColor;
    final previewTodos = _previewTodos;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with optional D-day badge inline
            Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: projectColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (project.isCompletedProject) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.task_alt_rounded,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                ],
                if (project.dday != null) ...[
                  const SizedBox(width: 8),
                  _DdayBadge(project: project),
                ],
              ],
            ),

            // Due date inline text (below title, compact)
            if (project.dday != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 11, top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      MarkdoneDateFormatter.formatDate(project.dday!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Text(
                  project.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],

            if (previewTodos.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final todo in previewTodos)
                Padding(
                  padding: const EdgeInsets.only(left: 11, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        todo.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: todo.isCompleted
                            ? theme.colorScheme.primary.withValues(alpha: 0.6)
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          todo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            decoration: todo.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: todo.isCompleted
                                ? theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  )
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            if (project.todos.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Progress row: bar + stats inline
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: project.progress,
                        minHeight: 4,
                        backgroundColor: projectColor.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation(projectColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${project.completedCount}/${project.todos.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
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

/// Compact D-day pill badge shown inline in the title row.
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}
