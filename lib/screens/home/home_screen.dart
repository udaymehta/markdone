import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/color_utils.dart';
import '../../core/date_formatters.dart';
import '../../core/widgets/centered_popup.dart';
import '../../models/master_project.dart';
import '../../providers/project_providers.dart';
import '../../providers/settings_providers.dart';
import '../archive/archive_screen.dart';
import '../project_detail/project_detail_screen.dart';
import '../dday/dday_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/project_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _queueArchive(
    BuildContext context,
    MasterProject project,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    try {
      await ref
          .read(projectsProvider.notifier)
          .archiveProject(project.filePath);
      if (!context.mounted) return;
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not archive "${project.title}": $e')),
      );
    }
  }

  Future<void> _queueDelete(BuildContext context, MasterProject project) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    try {
      await ref.read(projectsProvider.notifier).deleteProject(project.filePath);
      if (!context.mounted) return;
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete "${project.title}": $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);
    final projects = ref.watch(sortedProjectsProvider);
    final isBackgroundSyncing = ref.watch(backgroundProjectSyncProvider);
    final theme = Theme.of(context);
    final ddayProjects = ref.watch(ddayProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('MarkDone!', style: theme.textTheme.headlineMedium),
        actions: [
          if (ddayProjects.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.event_note_rounded),
              tooltip: 'D-Day Events',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DdayScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Archive',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text('Error loading projects', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                err.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(projectsProvider.notifier).syncEverything(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (_) {
          if (projects.isEmpty) {
            return _EmptyState(
              onCreatePressed: () => _showCreateDialog(context),
              isSyncing: isBackgroundSyncing,
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(projectsProvider.notifier).syncEverything(),
            child: CustomScrollView(
              slivers: [
                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Projects',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${projects.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Project cards
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final project = projects[index];
                    return ProjectCard(
                      project: project,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProjectDetailScreen(filePath: project.filePath),
                          ),
                        );
                      },
                      onLongPress: () => _showProjectOptions(context, project),
                    );
                  }, childCount: projects.length),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? dday;
    bool syncWithCalendar = false;
    Color? bgColor;

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
                Text('New Project', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 14),
                // Title field
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Project name',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),
                // Description field (compact)
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
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
                                    firstDate: DateTime.now(),
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
                                      firstDate: DateTime.now(),
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
                    ref
                        .read(projectsProvider.notifier)
                        .createProject(
                          title: title,
                          dday: dday,
                          description: descController.text.trim().isNotEmpty
                              ? descController.text.trim()
                              : null,
                          bgColor: bgColor != null
                              ? colorToHexString(bgColor!)
                              : null,
                          syncWithCalendar: syncWithCalendar,
                        );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Create Project'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProjectOptions(BuildContext context, MasterProject project) {
    final theme = Theme.of(context);

    showCenteredPopup(
      context: context,
      builder: (ctx) => CenteredPopupContent(
        scrollable: false,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Project'),
              onTap: () async {
                Navigator.pop(ctx);
                await _queueArchive(context, project);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Reload Project'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(projectsProvider.notifier).reload();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete Project',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, project);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Delete "${project.title}" and its .md file? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _queueDelete(context, project);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreatePressed;
  final bool isSyncing;

  const _EmptyState({required this.onCreatePressed, this.isSyncing = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text('No projects yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Create a project or point MarkDone! to a folder with Markdown files.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (isSyncing) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Checking calendar changes in the background…',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Project'),
            ),
          ],
        ),
      ),
    );
  }
}
