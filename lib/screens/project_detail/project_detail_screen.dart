import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    final titleController = TextEditingController();
    final project = ref.read(projectByPathProvider(widget.filePath));
    if (project == null) return;

    final calendarSyncEnabled = ref.read(calendarSyncEnabledProvider);
    final canSyncTaskToCalendar =
        calendarSyncEnabled && project.syncWithCalendar && !project.isArchived;
    DateTime? alarm;
    String? reminderStr = '30m';
    var addToCalendar = canSyncTaskToCalendar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('New Task', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Task name',
                    prefixIcon: Icon(Icons.check_circle_outline_rounded),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
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
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setSheetState(() {
                                alarm = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        icon: const Icon(Icons.alarm_rounded, size: 18),
                        label: Text(
                          alarm != null
                              ? DateFormat('MMM d, h:mm a').format(alarm!)
                              : 'Set Alarm',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (alarm != null) ...[
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: reminderStr,
                        hint: const Text(
                          'Reminder',
                          style: TextStyle(fontSize: 13),
                        ),
                        items: const [
                          DropdownMenuItem(value: '5m', child: Text('5 min')),
                          DropdownMenuItem(value: '15m', child: Text('15 min')),
                          DropdownMenuItem(value: '30m', child: Text('30 min')),
                          DropdownMenuItem(value: '1h', child: Text('1 hour')),
                          DropdownMenuItem(value: '1d', child: Text('1 day')),
                        ],
                        onChanged: (v) => setSheetState(() => reminderStr = v),
                      ),
                    ],
                  ],
                ),
                if (canSyncTaskToCalendar) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: addToCalendar,
                    onChanged: (value) =>
                        setSheetState(() => addToCalendar = value ?? false),
                    title: const Text('Add to calendar'),
                    subtitle: Text(
                      alarm == null
                          ? 'Set an alarm if you want this task on your calendar'
                          : 'Keep this task as an app-only notification by turning this off',
                    ),
                    secondary: const Icon(Icons.event_outlined),
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

                    final newTodo = SubTodo(
                      id: '${widget.filePath.hashCode}_${project.todos.length}',
                      title: title,
                      isCompleted: false,
                      alarm: alarm,
                      syncToCalendar: addToCalendar,
                      reminderBefore: SubTodo.parseReminderString(reminderStr),
                      lineIndex: project.todos.length,
                    );

                    ref
                        .read(projectsProvider.notifier)
                        .addTodo(widget.filePath, newTodo);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add Task'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditTodoSheet(BuildContext context, SubTodo todo) {
    final titleController = TextEditingController(text: todo.title);
    final project = ref.read(projectByPathProvider(widget.filePath));
    if (project == null) return;

    final calendarSyncEnabled = ref.read(calendarSyncEnabledProvider);
    final canSyncTaskToCalendar =
        calendarSyncEnabled && project.syncWithCalendar && !project.isArchived;
    DateTime? alarm = todo.alarm;
    String? reminderStr = todo.reminderString;
    var addToCalendar = todo.syncToCalendar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Edit Task', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    hintText: 'Task name',
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
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
                                alarm = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.notifications_outlined,
                          size: 18,
                        ),
                        label: Text(
                          alarm != null
                              ? DateFormat('MMM d, h:mm a').format(alarm!)
                              : 'Set Reminder',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    if (alarm != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => setSheetState(() => alarm = null),
                      ),
                      DropdownButton<String>(
                        value: reminderStr,
                        hint: const Text(
                          'Reminder',
                          style: TextStyle(fontSize: 13),
                        ),
                        items: const [
                          DropdownMenuItem(value: '5m', child: Text('5 min')),
                          DropdownMenuItem(value: '15m', child: Text('15 min')),
                          DropdownMenuItem(value: '30m', child: Text('30 min')),
                          DropdownMenuItem(value: '1h', child: Text('1 hour')),
                          DropdownMenuItem(value: '1d', child: Text('1 day')),
                        ],
                        onChanged: (v) => setSheetState(() => reminderStr = v),
                      ),
                    ],
                  ],
                ),
                if (canSyncTaskToCalendar) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: addToCalendar,
                    onChanged: (value) =>
                        setSheetState(() => addToCalendar = value ?? false),
                    title: const Text('Add to calendar'),
                    subtitle: Text(
                      alarm == null
                          ? 'Set an alarm if you want this task on your calendar'
                          : 'Turn this off to keep the reminder inside the app only',
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
                    OutlinedButton.icon(
                      onPressed: () async {
                        final shouldDelete = await showDialog<bool>(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Delete Task'),
                            content: Text(
                              'Delete "${todo.title}"? This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogCtx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx, true),
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
                            .removeTodo(widget.filePath, todo.id);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final updated = todo.copyWith(
                            title: title,
                            alarm: alarm,
                            syncToCalendar: addToCalendar,
                            clearAlarm: alarm == null,
                            reminderBefore: SubTodo.parseReminderString(
                              reminderStr,
                            ),
                            clearReminder: reminderStr == null,
                          );

                          ref
                              .read(projectsProvider.notifier)
                              .updateTodo(widget.filePath, updated);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
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
