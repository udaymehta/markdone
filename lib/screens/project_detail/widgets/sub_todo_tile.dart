import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/sub_todo.dart';
import 'animated_checkbox.dart';

/// A single sub-todo tile with animated checkbox and metadata display.
class SubTodoTile extends StatelessWidget {
  final SubTodo todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onDismissed;

  const SubTodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.error,
        ),
      ),
      onDismissed: onDismissed != null ? (_) => onDismissed!() : null,
      confirmDismiss: onDismissed != null
          ? (_) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Task'),
                  content: Text('Delete "${todo.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            }
          : null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              AnimatedCheckbox(
                value: todo.isCompleted,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: todo.isCompleted
                            ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              )
                            : null,
                      ),
                    ),
                    if (todo.alarm != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaChip(
                            icon: Icons.alarm_rounded,
                            label: DateFormat(
                              'MMM d, h:mm a',
                            ).format(todo.alarm!),
                            color: _alarmColor(context),
                          ),
                          if (todo.reminderBefore != null)
                            _MetaChip(
                              icon: Icons.notifications_active_outlined,
                              label:
                                  '${todo.reminderLabel ?? todo.reminderString} before',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          if (todo.recurrence != null)
                            _MetaChip(
                              icon: Icons.repeat_rounded,
                              label: todo.recurrence!.label,
                              color: theme.colorScheme.secondary,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (todo.calendarEventId != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _alarmColor(BuildContext context) {
    if (todo.isCompleted) {
      return Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    }
    if (todo.alarm!.isBefore(DateTime.now())) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.primary;
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
