import 'package:flutter/material.dart';
import '../../../core/date_formatters.dart';
import '../../../models/sub_todo.dart';
import 'animated_checkbox.dart';

/// A single sub-todo tile with animated checkbox and metadata display.
class SubTodoTile extends StatelessWidget {
  final SubTodo todo;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onDismissed;
  final DateTime? projectDday;

  /// Optional drag handle widget placed at the trailing edge.
  /// Pass a [ReorderableDragStartListener] wrapping an icon here.
  final Widget? dragHandle;

  const SubTodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onTap,
    this.onDismissed,
    this.projectDday,
    this.dragHandle,
  });

  Widget _buildMetadata(BuildContext context) {
    final baseColor = todo.isCompleted
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: baseColor, height: 1.35);

    final dateText = MarkdoneDateFormatter.formatDateTime(todo.alarm!);
    final extras = <String>[];
    if (todo.reminderBefore != null) {
      extras.add('${todo.reminderLabel ?? todo.reminderString} before');
    }
    if (todo.recurrence != null) {
      extras.add(todo.recurrence!.label);
    }

    if (extras.isEmpty) {
      return Text(
        dateText,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: dateText),
          TextSpan(text: '  ·  ${extras.join("  ·  ")}'),
        ],
      ),
      style: baseStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.horizontal,
      // Right swipe (start → end): complete/uncomplete
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          todo.isCompleted
              ? Icons.undo_rounded
              : Icons.check_circle_outline_rounded,
          color: const Color(0xFF34C759),
        ),
      ),
      // Left swipe (end → start): delete
      secondaryBackground: Container(
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
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Right swipe → toggle completion (don't actually dismiss)
          onToggle();
          return false;
        }
        // Left swipe → confirm delete
        if (onDismissed == null) return false;
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
      },
      onDismissed: onDismissed != null ? (_) => onDismissed!() : null,
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
                      const SizedBox(height: 2),
                      _buildMetadata(context),
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
              ?dragHandle,
            ],
          ),
        ),
      ),
    );
  }
}
