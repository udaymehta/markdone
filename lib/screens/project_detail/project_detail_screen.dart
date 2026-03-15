import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/color_utils.dart';
import '../../core/date_formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/centered_popup.dart';
import '../../models/master_project.dart';
import '../../models/sub_todo.dart';
import '../../providers/project_providers.dart';
import '../../providers/settings_providers.dart';
import 'widgets/sub_todo_tile.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String filePath;

  const ProjectDetailScreen({super.key, required this.filePath});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  bool _sortByDueDate = false;

  /// Local copy of pending todos for optimistic drag-reorder.
  /// When non-null, this takes precedence over the provider snapshot
  /// to avoid flicker between drag-end and async persist.
  List<SubTodo>? _localPendingTodos;

  Future<void> _queueArchive(MasterProject project) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    try {
      await ref
          .read(projectsProvider.notifier)
          .archiveProject(project.filePath);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not archive "${project.title}": $e')),
      );
    }
  }

  Future<void> _queueDelete(MasterProject project) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    try {
      await ref.read(projectsProvider.notifier).deleteProject(project.filePath);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete "${project.title}": $e')),
      );
    }
  }

  Future<void> _handleToggleTodo(MasterProject project, SubTodo todo) async {
    final wasCompleted = project.isCompletedProject;

    await ref
        .read(projectsProvider.notifier)
        .toggleTodo(widget.filePath, todo.id);

    final updatedProject = ref.read(projectByPathProvider(widget.filePath));
    if (!mounted || updatedProject == null) return;

    if (!wasCompleted &&
        updatedProject.isCompletedProject &&
        !updatedProject.isArchived) {
      await _showArchivePrompt(context, updatedProject);
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectByPathProvider(widget.filePath));
    final theme = Theme.of(context);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Project not found')),
      );
    }

    final providerPendingTodos =
        project.todos.where((t) => !t.isCompleted).toList()..sort((a, b) {
          if (_sortByDueDate) {
            if (a.alarm != null && b.alarm != null) {
              return a.alarm!.compareTo(b.alarm!);
            }
            if (a.alarm != null) return -1;
            if (b.alarm != null) return 1;
            return 0;
          } else {
            final aOrder = a.sortOrder ?? a.lineIndex;
            final bOrder = b.sortOrder ?? b.lineIndex;
            return aOrder.compareTo(bOrder);
          }
        });

    // Use local optimistic list if available (drag-reorder in progress),
    // otherwise fall back to provider snapshot and clear local override.
    final pendingTodos = _localPendingTodos ?? providerPendingTodos;

    final hideCompleted = ref.watch(hideCompletedProvider);
    final completedTodos = project.todos.where((t) => t.isCompleted).toList()
      ..sort((a, b) {
        if (a.alarm != null && b.alarm != null) {
          return a.alarm!.compareTo(b.alarm!);
        }
        if (a.alarm != null) return -1;
        if (b.alarm != null) return 1;
        return 0;
      });

    // Project background tint
    final bgTint = parseBgColor(project.bgColor);
    final scaffoldBg = bgTint != null
        ? Color.lerp(
            theme.scaffoldBackgroundColor,
            bgTint.withValues(alpha: 1.0),
            bgTint.a,
          )
        : null;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        title: Text(project.title),
        actions: [
          if (project.dday != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _DdayChip(
                  daysUntil: project.daysUntilDday!,
                  date: project.dday!,
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showEditProjectDialog(context);
                case 'archive':
                  _archiveProject(project);
                case 'delete':
                  _confirmDelete(context, project);
                case 'refresh':
                  ref.read(projectsProvider.notifier).reload();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit Project'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (!project.isArchived)
                const PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                    leading: Icon(Icons.archive_outlined),
                    title: Text('Archive Project'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete Project'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh_rounded),
                  title: Text('Reload from file'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Description
          if (project.description != null && project.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Text(
                  project.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),

          // Progress summary
          if (project.todos.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: _ProgressSummary(
                  total: project.todos.length,
                  completed: project.completedCount,
                  progress: project.progress,
                  bgTint: bgTint,
                ),
              ),
            ),

          // Pending tasks header
          if (pendingTodos.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                child: Row(
                  children: [
                    Text(
                      'To Do',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _sortByDueDate = !_sortByDueDate),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _sortByDueDate
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _sortByDueDate
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.4,
                                  )
                                : theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sortByDueDate
                                  ? Icons.sort_rounded
                                  : Icons.drag_handle_rounded,
                              size: 14,
                              color: _sortByDueDate
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortByDueDate ? 'Due date' : 'Custom',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _sortByDueDate
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Pending tasks
          if (_sortByDueDate)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final todo = pendingTodos[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SubTodoTile(
                    todo: todo,
                    projectDday: project.dday,
                    onToggle: () => _handleToggleTodo(project, todo),
                    onTap: () => _showEditTodoSheet(context, todo),
                    onDismissed: () => ref
                        .read(projectsProvider.notifier)
                        .removeTodo(widget.filePath, todo.id),
                  ),
                );
              }, childCount: pendingTodos.length),
            )
          else
            SliverReorderableList(
              itemCount: pendingTodos.length,
              onReorder: (oldIndex, newIndex) {
                // Optimistic local update to prevent flicker
                final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
                final reordered = List<SubTodo>.from(pendingTodos);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(adjusted, item);
                setState(() => _localPendingTodos = reordered);

                // Fire async persist, then clear local override
                ref
                    .read(projectsProvider.notifier)
                    .reorderTodo(widget.filePath, oldIndex, newIndex)
                    .whenComplete(() {
                      if (mounted) {
                        setState(() => _localPendingTodos = null);
                      }
                    });
              },
              itemBuilder: (context, index) {
                final todo = pendingTodos[index];
                return Padding(
                  key: ValueKey(todo.id),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SubTodoTile(
                    todo: todo,
                    projectDday: project.dday,
                    onToggle: () => _handleToggleTodo(project, todo),
                    onTap: () => _showEditTodoSheet(context, todo),
                    onDismissed: () => ref
                        .read(projectsProvider.notifier)
                        .removeTodo(widget.filePath, todo.id),
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Icon(
                          Icons.reorder_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Completed tasks header
          if (completedTodos.isNotEmpty && !hideCompleted)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: Row(
                  children: [
                    Text(
                      'Completed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${completedTodos.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

          // Completed tasks
          if (!hideCompleted)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final todo = completedTodos[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SubTodoTile(
                    todo: todo,
                    projectDday: project.dday,
                    onToggle: () => _handleToggleTodo(project, todo),
                    onTap: () => _showEditTodoSheet(context, todo),
                    onDismissed: () => ref
                        .read(projectsProvider.notifier)
                        .removeTodo(widget.filePath, todo.id),
                  ),
                );
              }, childCount: completedTodos.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTodoSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showAddTodoSheet(BuildContext context) {
    _showTodoSheet(context);
  }

  void _showEditTodoSheet(BuildContext context, SubTodo todo) {
    _showTodoSheet(context, existingTodo: todo);
  }

  void _showTodoSheet(BuildContext context, {SubTodo? existingTodo}) {
    final isEditing = existingTodo != null;
    final titleController = TextEditingController();
    final reminderConfig = ReminderConfig.fromDuration(
      existingTodo?.reminderBefore,
    );
    final reminderValueController = TextEditingController(
      text: '${reminderConfig?.value ?? 30}',
    );
    final recurrenceIntervalController = TextEditingController(
      text: '${existingTodo?.recurrence?.interval ?? 1}',
    );
    if (isEditing) {
      titleController.text = existingTodo.title;
    }

    final project = ref.read(projectByPathProvider(widget.filePath));
    if (project == null) {
      titleController.dispose();
      reminderValueController.dispose();
      recurrenceIntervalController.dispose();
      return;
    }

    final calendarSyncEnabled = ref.read(calendarSyncEnabledProvider);
    final canSyncTaskToCalendar =
        calendarSyncEnabled && project.syncWithCalendar && !project.isArchived;
    DateTime? alarm = existingTodo?.alarm;
    var addToCalendar = isEditing
        ? existingTodo.syncToCalendar && alarm != null
        : canSyncTaskToCalendar;
    var reminderEnabled = alarm != null && reminderConfig != null;
    var reminderUnit = reminderConfig?.unit ?? ReminderUnit.minutes;
    var recurrenceEnabled = existingTodo?.recurrence != null;
    var recurrenceFrequency =
        existingTodo?.recurrence?.frequency ?? RecurrenceFrequency.daily;

    showCenteredPopup<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final reminderValue = _parsePositiveInt(reminderValueController.text);
          final recurrenceInterval = _parsePositiveInt(
            recurrenceIntervalController.text,
          );
          final activeReminder =
              alarm != null && reminderEnabled && reminderValue != null
              ? ReminderConfig(value: reminderValue, unit: reminderUnit)
              : null;
          final activeRecurrence =
              alarm != null && recurrenceEnabled && recurrenceInterval != null
              ? RecurrenceRule.fromAlarm(
                  frequency: recurrenceFrequency,
                  alarm: alarm!,
                  interval: recurrenceInterval,
                )
              : null;
          final reminderError =
              alarm != null && reminderEnabled && reminderValue == null
              ? 'Enter a positive number'
              : null;
          final recurrenceError =
              alarm != null && recurrenceEnabled && recurrenceInterval == null
              ? 'Enter a positive number'
              : null;
          final scheduleValidation = _scheduleValidationMessage(
            reminder: activeReminder,
            recurrence: activeRecurrence,
          );
          final canSave =
              titleController.text.trim().isNotEmpty &&
              reminderError == null &&
              recurrenceError == null &&
              scheduleValidation == null;

          return CenteredPopupContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Edit Task' : 'New Task',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                // Task name
                TextField(
                  controller: titleController,
                  autofocus: !isEditing,
                  onChanged: (_) => setSheetState(() {}),
                  maxLines: null,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Task name',
                    prefixIcon: Icon(
                      isEditing
                          ? Icons.edit_outlined
                          : Icons.check_circle_outline_rounded,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                _CompactScheduleSection(
                  theme: theme,
                  alarm: alarm,
                  onAlarmRemoved: () => setSheetState(() {
                    alarm = null;
                    reminderEnabled = false;
                    recurrenceEnabled = false;
                    addToCalendar = false;
                  }),
                  onAlarmDateTap: () async {
                    if (!ctx.mounted) return;
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: alarm ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null && ctx.mounted) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: alarm != null
                            ? TimeOfDay.fromDateTime(alarm!)
                            : TimeOfDay.now(),
                      );
                      if (time != null) {
                        setSheetState(() {
                          final hadAlarm = alarm != null;
                          alarm = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          if (!hadAlarm) {
                            reminderEnabled = true;
                            if (_parsePositiveInt(
                                  reminderValueController.text,
                                ) ==
                                null) {
                              reminderValueController.text = '30';
                            }
                          }
                          if (!hadAlarm && canSyncTaskToCalendar) {
                            addToCalendar = true;
                          }
                        });
                      }
                    }
                  },
                  reminderEnabled: reminderEnabled,
                  onReminderToggle: (enabled) {
                    setSheetState(() {
                      reminderEnabled = enabled;
                      if (enabled &&
                          _parsePositiveInt(reminderValueController.text) ==
                              null) {
                        reminderValueController.text = '30';
                      }
                    });
                  },
                  reminderValueController: reminderValueController,
                  onReminderValueChanged: () => setSheetState(() {}),
                  reminderUnit: reminderUnit,
                  onReminderUnitChanged: (unit) =>
                      setSheetState(() => reminderUnit = unit),
                  reminderError: reminderError,
                  recurrenceEnabled: recurrenceEnabled,
                  onRecurrenceToggle: (enabled) {
                    setSheetState(() {
                      recurrenceEnabled = enabled;
                      if (enabled &&
                          _parsePositiveInt(
                                recurrenceIntervalController.text,
                              ) ==
                              null) {
                        recurrenceIntervalController.text = '1';
                      }
                    });
                  },
                  recurrenceIntervalController: recurrenceIntervalController,
                  onRecurrenceValueChanged: () => setSheetState(() {}),
                  recurrenceFrequency: recurrenceFrequency,
                  onRecurrenceFreqChanged: (freq) =>
                      setSheetState(() => recurrenceFrequency = freq),
                  recurrenceError: recurrenceError,
                  scheduleValidation: scheduleValidation,
                  showCalendarSync: canSyncTaskToCalendar,
                  calendarSyncValue: addToCalendar,
                  onCalendarSyncChanged: (value) =>
                      setSheetState(() => addToCalendar = value),
                ),
                const SizedBox(height: 16),
                // Delete + Save buttons (equal width)
                Row(
                  children: [
                    if (isEditing) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: ctx,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Delete Task'),
                                content: Text(
                                  'Delete "${existingTodo.title}"? This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, true),
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Theme.of(
                                          dialogCtx,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (shouldDelete != true) return;

                            await ref
                                .read(projectsProvider.notifier)
                                .removeTodo(widget.filePath, existingTodo.id);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: canSave
                            ? () {
                                final title = titleController.text.trim();
                                if (title.isEmpty) return;

                                final reminderBefore = activeReminder?.duration;

                                if (!isEditing) {
                                  final newTodo = SubTodo(
                                    id: SubTodo.generateId(),
                                    title: title,
                                    isCompleted: false,
                                    alarm: alarm,
                                    syncToCalendar:
                                        alarm != null && addToCalendar,
                                    reminderBefore: reminderBefore,
                                    recurrence: activeRecurrence,
                                    lineIndex: project.todos.length,
                                  ).normalizedSchedule();

                                  ref
                                      .read(projectsProvider.notifier)
                                      .addTodo(widget.filePath, newTodo);
                                  Navigator.pop(ctx);
                                  return;
                                }

                                final updated = existingTodo
                                    .copyWith(
                                      title: title,
                                      alarm: alarm,
                                      syncToCalendar:
                                          alarm != null && addToCalendar,
                                      clearAlarm: alarm == null,
                                      reminderBefore: reminderBefore,
                                      clearReminder:
                                          alarm == null ||
                                          activeReminder == null,
                                      recurrence: activeRecurrence,
                                      clearRecurrence:
                                          alarm == null ||
                                          activeRecurrence == null,
                                      clearCalendarEventId: alarm == null,
                                    )
                                    .normalizedSchedule();

                                ref
                                    .read(projectsProvider.notifier)
                                    .updateTodo(widget.filePath, updated);
                                Navigator.pop(ctx);
                              }
                            : null,
                        child: Text(isEditing ? 'Save' : 'Add Task'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      titleController.dispose();
      reminderValueController.dispose();
      recurrenceIntervalController.dispose();
    });
  }

  static int? _parsePositiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static String? _scheduleValidationMessage({
    ReminderConfig? reminder,
    RecurrenceRule? recurrence,
  }) {
    if (reminder == null || recurrence == null) return null;

    final recurrenceCycle = switch (recurrence.frequency) {
      RecurrenceFrequency.minutely => Duration(minutes: recurrence.interval),
      RecurrenceFrequency.hourly => Duration(hours: recurrence.interval),
      RecurrenceFrequency.daily => Duration(days: recurrence.interval),
      RecurrenceFrequency.weekly => Duration(days: recurrence.interval * 7),
      RecurrenceFrequency.monthly || RecurrenceFrequency.yearly => null,
    };

    if (recurrenceCycle != null && reminder.duration >= recurrenceCycle) {
      return 'Reminder must be shorter than the repeat interval.';
    }

    return null;
  }

  void _showEditProjectDialog(BuildContext context) {
    final project = ref.read(projectByPathProvider(widget.filePath));
    if (project == null) return;

    final titleController = TextEditingController(text: project.title);
    final descController = TextEditingController(
      text: project.description ?? '',
    );
    DateTime? dday = project.dday;
    bool syncWithCalendar = project.syncWithCalendar;
    Color? bgColor = parseBgColor(project.bgColor);

    // Check if calendar sync is globally enabled
    final calSyncEnabled = ref.read(calendarSyncEnabledProvider);

    showCenteredPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return CenteredPopupContent(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit Project', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 14),
                // Title field
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Project name',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Description field (compact)
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    hintText: 'Description',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 10),
                // Settings container (compact bordered box)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.dividerTheme.color ?? Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // D-Day row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              dday != null
                                  ? Icons.event_rounded
                                  : Icons.event_outlined,
                              size: 17,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate:
                                        dday ??
                                        DateTime.now().add(
                                          const Duration(days: 30),
                                        ),
                                    firstDate: DateTime.now().subtract(
                                      const Duration(days: 365),
                                    ),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 3650),
                                    ),
                                  );
                                  if (picked != null) {
                                    setSheetState(() => dday = picked);
                                  }
                                },
                                child: Text(
                                  dday != null
                                      ? 'D-Day: ${MarkdoneDateFormatter.formatDate(dday!)}'
                                      : 'Set D-Day',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 13,
                                    color: dday != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: dday != null,
                                onChanged: (checked) async {
                                  if (checked == true) {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 365),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 3650),
                                      ),
                                    );
                                    if (picked != null) {
                                      setSheetState(() => dday = picked);
                                    }
                                  } else {
                                    setSheetState(() => dday = null);
                                  }
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (calSyncEnabled) ...[
                        Divider(
                          height: 12,
                          thickness: 1,
                          color: theme.dividerTheme.color ?? Colors.transparent,
                        ),
                        // Calendar sync row
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 17,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sync with calendar',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 13,
                                  color: syncWithCalendar
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: syncWithCalendar,
                                  onChanged: (v) => setSheetState(
                                    () => syncWithCalendar = v ?? false,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Divider(
                        height: 12,
                        thickness: 1,
                        color: theme.dividerTheme.color ?? Colors.transparent,
                      ),
                      // Background color row
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.palette_outlined,
                              size: 17,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await showBgColorPicker(
                                    ctx,
                                    bgColor,
                                  );
                                  if (picked != null) {
                                    setSheetState(() => bgColor = picked);
                                  }
                                },
                                child: Text(
                                  bgColor != null
                                      ? 'Background color'
                                      : 'Set background color',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 13,
                                    color: bgColor != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            if (bgColor != null) ...[
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showBgColorPicker(
                                    ctx,
                                    bgColor,
                                  );
                                  if (picked != null) {
                                    setSheetState(() => bgColor = picked);
                                  }
                                },
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: bgColor != null,
                                onChanged: (checked) async {
                                  if (checked == true) {
                                    final picked = await showBgColorPicker(
                                      ctx,
                                      null,
                                    );
                                    if (picked != null) {
                                      setSheetState(() => bgColor = picked);
                                    }
                                  } else {
                                    setSheetState(() => bgColor = null);
                                  }
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final updated = project.copyWith(
                      title: title,
                      description: descController.text.trim().isNotEmpty
                          ? descController.text.trim()
                          : null,
                      clearDescription: descController.text.trim().isEmpty,
                      dday: dday,
                      clearDday: dday == null,
                      syncWithCalendar: syncWithCalendar,
                      bgColor: bgColor != null
                          ? colorToHexString(bgColor!)
                          : null,
                      clearBgColor: bgColor == null,
                    );

                    ref
                        .read(projectsProvider.notifier)
                        .updateProjectMetadata(updated);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showArchivePrompt(
    BuildContext context,
    MasterProject project,
  ) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Project completed'),
        content: Text(
          'You completed "${project.title}". Do you want to archive it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Here'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (shouldArchive == true) {
      await _archiveProject(project);
    }
  }

  Future<void> _archiveProject(MasterProject project) async {
    await _queueArchive(project);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MasterProject project,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Delete "${project.title}" and its .md file? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    await _queueDelete(project);
  }
}

class _ProgressSummary extends StatelessWidget {
  final int total;
  final int completed;
  final double progress;
  final Color? bgTint;

  const _ProgressSummary({
    required this.total,
    required this.completed,
    required this.progress,
    this.bgTint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tint the card background to match the project bg color
    final containerBg = bgTint != null
        ? Color.lerp(
            theme.cardColor,
            bgTint!.withValues(alpha: 1.0),
            (bgTint!.a * 1.2).clamp(0.0, 1.0),
          )!
        : theme.cardColor;

    // Use the tint color for the progress indicator if available
    final accentColor = bgTint != null
        ? Color.lerp(
            theme.colorScheme.primary,
            bgTint!.withValues(alpha: 1.0),
            0.5,
          )!
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(accentColor),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$completed of $total tasks completed',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${total - completed} remaining',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DdayChip extends StatelessWidget {
  final int daysUntil;
  final DateTime date;

  const _DdayChip({required this.daysUntil, required this.date});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (daysUntil < 0) {
      color = AppColors.ddayUrgent;
    } else if (daysUntil <= 3) {
      color = AppColors.ddayUrgent;
    } else if (daysUntil <= 14) {
      color = AppColors.ddaySoon;
    } else {
      color = AppColors.ddayRelaxed;
    }

    String label;
    if (daysUntil == 0) {
      label = 'D-DAY';
    } else if (daysUntil > 0) {
      label = 'D-$daysUntil';
    } else {
      label = 'D+${daysUntil.abs()}';
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A single compact container with Reminder + Repeat as two inline rows.
class _CompactScheduleSection extends StatelessWidget {
  final ThemeData theme;
  final bool reminderEnabled;
  final ValueChanged<bool> onReminderToggle;
  final TextEditingController reminderValueController;
  final VoidCallback onReminderValueChanged;
  final ReminderUnit reminderUnit;
  final ValueChanged<ReminderUnit> onReminderUnitChanged;
  final String? reminderError;
  final bool recurrenceEnabled;
  final ValueChanged<bool> onRecurrenceToggle;
  final TextEditingController recurrenceIntervalController;
  final VoidCallback onRecurrenceValueChanged;
  final RecurrenceFrequency recurrenceFrequency;
  final ValueChanged<RecurrenceFrequency> onRecurrenceFreqChanged;
  final String? recurrenceError;
  final String? scheduleValidation;
  final bool showCalendarSync;
  final bool calendarSyncValue;
  final ValueChanged<bool>? onCalendarSyncChanged;
  final DateTime? alarm;
  final VoidCallback? onAlarmRemoved;
  final VoidCallback? onAlarmDateTap;

  const _CompactScheduleSection({
    required this.theme,
    required this.reminderEnabled,
    required this.onReminderToggle,
    required this.reminderValueController,
    required this.onReminderValueChanged,
    required this.reminderUnit,
    required this.onReminderUnitChanged,
    required this.reminderError,
    required this.recurrenceEnabled,
    required this.onRecurrenceToggle,
    required this.recurrenceIntervalController,
    required this.onRecurrenceValueChanged,
    required this.recurrenceFrequency,
    required this.onRecurrenceFreqChanged,
    required this.recurrenceError,
    required this.scheduleValidation,
    this.showCalendarSync = false,
    this.calendarSyncValue = false,
    this.onCalendarSyncChanged,
    this.alarm,
    this.onAlarmRemoved,
    this.onAlarmDateTap,
  });

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerTheme.color ?? Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alarm row — always visible
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  alarm != null
                      ? Icons.alarm_on_rounded
                      : Icons.alarm_add_rounded,
                  size: 17,
                  color: alarm != null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: onAlarmDateTap,
                    child: Text(
                      alarm != null
                          ? MarkdoneDateFormatter.formatDateTimeShort(alarm!)
                          : 'Set alarm',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        color: alarm != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: alarm != null,
                    onChanged: (checked) {
                      if (checked == true) {
                        onAlarmDateTap?.call();
                      } else {
                        onAlarmRemoved?.call();
                      }
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 12,
            thickness: 1,
            color: theme.dividerTheme.color ?? Colors.transparent,
          ),
          // Reminder row
          IgnorePointer(
            ignoring: alarm == null,
            child: AnimatedOpacity(
              opacity: alarm != null ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ScheduleRow(
                    theme: theme,
                    icon: Icons.notifications_active_outlined,
                    label: 'Remind',
                    enabled: reminderEnabled,
                    onToggle: onReminderToggle,
                    valueController: reminderValueController,
                    onValueChanged: onReminderValueChanged,
                    errorText: reminderError,
                    selectedUnit: reminderUnit,
                    units: ReminderUnit.values,
                    unitLabelBuilder: (u) => _capitalize(u.pluralUnit),
                    onUnitChanged: onReminderUnitChanged,
                    hintText: 'min',
                  ),
                  Divider(
                    height: 12,
                    thickness: 1,
                    color: theme.dividerTheme.color ?? Colors.transparent,
                  ),
                  // Recurrence row
                  _ScheduleRow(
                    theme: theme,
                    icon: Icons.repeat_rounded,
                    label: 'Repeat',
                    enabled: recurrenceEnabled,
                    onToggle: onRecurrenceToggle,
                    valueController: recurrenceIntervalController,
                    onValueChanged: onRecurrenceValueChanged,
                    errorText: recurrenceError,
                    selectedUnit: recurrenceFrequency,
                    units: RecurrenceFrequency.values,
                    unitLabelBuilder: (f) => _capitalize(f.pluralUnit),
                    onUnitChanged: onRecurrenceFreqChanged,
                    hintText: '#',
                  ),
                  if (showCalendarSync) ...[
                    Divider(
                      height: 12,
                      thickness: 1,
                      color: theme.dividerTheme.color ?? Colors.transparent,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 17,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Add to calendar',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              color: calendarSyncValue
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: calendarSyncValue,
                              onChanged: (value) =>
                                  onCalendarSyncChanged?.call(value ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (scheduleValidation != null) ...[
            const SizedBox(height: 6),
            Text(
              scheduleValidation!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single row: [icon] [label] [number field] [unit dropdown] [checkbox]
class _ScheduleRow<T> extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final TextEditingController valueController;
  final VoidCallback onValueChanged;
  final String? errorText;
  final T selectedUnit;
  final List<T> units;
  final String Function(T) unitLabelBuilder;
  final ValueChanged<T> onUnitChanged;
  final String hintText;

  const _ScheduleRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onToggle,
    required this.valueController,
    required this.onValueChanged,
    required this.errorText,
    required this.selectedUnit,
    required this.units,
    required this.unitLabelBuilder,
    required this.onUnitChanged,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 150),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // Icon + label
            Icon(icon, size: 17, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
            const SizedBox(width: 10),
            // Value input (compact)
            SizedBox(
              width: 48,
              height: 34,
              child: IgnorePointer(
                ignoring: !enabled,
                child: TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onValueChanged(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    errorText: null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Unit dropdown (compact)
            Expanded(
              child: SizedBox(
                height: 34,
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: DropdownButtonFormField<T>(
                    key: ValueKey<Object?>('${selectedUnit}_$enabled'),
                    initialValue: selectedUnit,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    items: units
                        .map(
                          (unit) => DropdownMenuItem<T>(
                            value: unit,
                            child: Text(
                              unitLabelBuilder(unit),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (value) {
                            if (value != null) onUnitChanged(value);
                          }
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Checkbox on far right
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: enabled,
                onChanged: (v) => onToggle(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
