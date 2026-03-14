import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

    final pendingTodos = project.todos.where((t) => !t.isCompleted).toList()
      ..sort((a, b) {
        // Sort by alarm date: tasks with alarms first, then by alarm time
        if (a.alarm != null && b.alarm != null) {
          return a.alarm!.compareTo(b.alarm!);
        }
        if (a.alarm != null) return -1;
        if (b.alarm != null) return 1;
        return 0;
      });

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

    return Scaffold(
      appBar: AppBar(
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
                ),
              ),
            ),

          // Pending tasks header
          if (pendingTodos.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'To Do',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

          // Pending tasks
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final todo = pendingTodos[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SubTodoTile(
                  todo: todo,
                  onToggle: () => _handleToggleTodo(project, todo),
                  onTap: () => _showEditTodoSheet(context, todo),
                  onDismissed: () => ref
                      .read(projectsProvider.notifier)
                      .removeTodo(widget.filePath, todo.id),
                ),
              );
            }, childCount: pendingTodos.length),
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
        child: const Icon(Icons.add_rounded),
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
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: !isEditing,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Task name',
                    prefixIcon: Icon(
                      isEditing
                          ? Icons.edit_outlined
                          : Icons.check_circle_outline_rounded,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                Text('Schedule', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: alarm ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
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
                        icon: Icon(
                          isEditing
                              ? Icons.notifications_outlined
                              : Icons.alarm_rounded,
                          size: 18,
                        ),
                        label: Text(
                          alarm != null
                              ? DateFormat('EEE, MMM d - h:mm a').format(alarm!)
                              : 'Set alarm',
                        ),
                      ),
                    ),
                    if (alarm != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.colorScheme.error,
                        ),
                        tooltip: 'Clear alarm',
                        onPressed: () => setSheetState(() {
                          alarm = null;
                          reminderEnabled = false;
                          recurrenceEnabled = false;
                          addToCalendar = false;
                        }),
                      ),
                    ],
                  ],
                ),
                if (alarm != null) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 420;
                      final reminderCard = _ScheduleOptionCard(
                        icon: Icons.notifications_active_outlined,
                        title: 'Reminder',
                        subtitle: 'Before the alarm',
                        enabled: reminderEnabled,
                        onToggle: (enabled) {
                          setSheetState(() {
                            reminderEnabled = enabled;
                            if (enabled &&
                                _parsePositiveInt(
                                      reminderValueController.text,
                                    ) ==
                                    null) {
                              reminderValueController.text = '30';
                            }
                          });
                        },
                        child: _IntervalEditor<ReminderUnit>(
                          enabled: reminderEnabled,
                          valueController: reminderValueController,
                          onValueChanged: () => setSheetState(() {}),
                          valueLabel: 'Amount',
                          valueErrorText: reminderError,
                          selectedUnit: reminderUnit,
                          units: ReminderUnit.values,
                          onChanged: (value) =>
                              setSheetState(() => reminderUnit = value),
                          itemLabelBuilder: (unit) =>
                              _capitalize(unit.pluralUnit),
                          icon: Icons.timelapse_rounded,
                        ),
                      );
                      final repeatCard = _ScheduleOptionCard(
                        icon: Icons.repeat_rounded,
                        title: 'Repeat',
                        subtitle: 'Next occurrence rule',
                        enabled: recurrenceEnabled,
                        onToggle: (enabled) {
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
                        child: _IntervalEditor<RecurrenceFrequency>(
                          enabled: recurrenceEnabled,
                          valueController: recurrenceIntervalController,
                          onValueChanged: () => setSheetState(() {}),
                          valueLabel: 'Every',
                          valueErrorText: recurrenceError,
                          selectedUnit: recurrenceFrequency,
                          units: RecurrenceFrequency.values,
                          onChanged: (value) =>
                              setSheetState(() => recurrenceFrequency = value),
                          itemLabelBuilder: (frequency) =>
                              _capitalize(frequency.pluralUnit),
                          icon: Icons.schedule_rounded,
                        ),
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: reminderCard),
                            const SizedBox(width: 12),
                            Expanded(child: repeatCard),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          reminderCard,
                          const SizedBox(height: 12),
                          repeatCard,
                        ],
                      );
                    },
                  ),
                  if (scheduleValidation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      scheduleValidation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Set an alarm to unlock custom reminders and repeat intervals.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (alarm != null && canSyncTaskToCalendar) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: addToCalendar,
                    onChanged: (value) =>
                        setSheetState(() => addToCalendar = value ?? false),
                    title: const Text('Add to calendar'),
                    subtitle: const Text(
                      'Turn this off to keep the schedule inside the app only.',
                    ),
                    secondary: const Icon(Icons.event_outlined),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (isEditing) ...[
                      OutlinedButton.icon(
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

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
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
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: 'Project name',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    hintText: 'Description',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate:
                                dday ??
                                DateTime.now().add(const Duration(days: 30)),
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
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          dday != null
                              ? 'D-Day: ${dday!.day}/${dday!.month}/${dday!.year}'
                              : 'Set D-Day',
                        ),
                      ),
                    ),
                    if (dday != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => setSheetState(() => dday = null),
                      ),
                    ],
                  ],
                ),
                if (calSyncEnabled) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: syncWithCalendar,
                    onChanged: (v) =>
                        setSheetState(() => syncWithCalendar = v ?? false),
                    title: const Text('Sync with Calendar'),
                    subtitle: const Text(
                      'Task reminders will be added to your device calendar',
                    ),
                    secondary: const Icon(Icons.calendar_month_outlined),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                const SizedBox(height: 20),
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

  const _ProgressSummary({
    required this.total,
    required this.completed,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
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
      color = Colors.red;
    } else if (daysUntil <= 7) {
      color = Colors.orange;
    } else {
      color = Colors.green;
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

class _ScheduleOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Widget child;

  const _ScheduleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: enabled
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _IntervalEditor<T> extends StatelessWidget {
  final bool enabled;
  final TextEditingController valueController;
  final VoidCallback onValueChanged;
  final String valueLabel;
  final String? valueErrorText;
  final T selectedUnit;
  final List<T> units;
  final ValueChanged<T> onChanged;
  final String Function(T unit) itemLabelBuilder;
  final IconData icon;

  const _IntervalEditor({
    required this.enabled,
    required this.valueController,
    required this.onValueChanged,
    required this.valueLabel,
    required this.valueErrorText,
    required this.selectedUnit,
    required this.units,
    required this.onChanged,
    required this.itemLabelBuilder,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.56,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !enabled,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackFields = constraints.maxWidth < 260;

            final valueField = TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              onChanged: (_) => onValueChanged(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: valueLabel,
                prefixIcon: Icon(icon),
                errorText: valueErrorText,
              ),
            );

            final unitField = DropdownButtonFormField<T>(
              key: ValueKey<Object?>('${selectedUnit}_$enabled'),
              initialValue: selectedUnit,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: units
                  .map(
                    (unit) => DropdownMenuItem<T>(
                      value: unit,
                      child: Text(itemLabelBuilder(unit)),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (value) {
                      if (value != null) {
                        onChanged(value);
                      }
                    }
                  : null,
            );

            if (stackFields) {
              return Column(
                children: [valueField, const SizedBox(height: 10), unitField],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: valueField),
                const SizedBox(width: 10),
                Expanded(child: unitField),
              ],
            );
          },
        ),
      ),
    );
  }
}
