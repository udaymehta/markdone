import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/master_project.dart';
import '../models/sub_todo.dart';
import '../services/file_service.dart';
import '../services/notification_service.dart';
import '../services/calendar_service.dart';
import '../services/recurrence_service.dart';
import 'settings_providers.dart';

// --- Service providers ---

final fileServiceProvider = Provider<FileService>((ref) {
  final fileService = FileService();
  // Wire custom path from settings into file service (now synchronous)
  final storagePath = ref.watch(storagePathProvider);
  fileService.customBasePath = storagePath;
  return fileService;
});

final effectiveStoragePathProvider = FutureProvider<String>((ref) async {
  final fileService = ref.watch(fileServiceProvider);
  return fileService.effectiveStoragePath;
});

final archiveStoragePathProvider = FutureProvider<String>((ref) async {
  final fileService = ref.watch(fileServiceProvider);
  return fileService.archivePath;
});

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final calendarServiceProvider = Provider<CalendarService>(
  (ref) => CalendarService(),
);

final backgroundProjectSyncProvider =
    NotifierProvider<BackgroundProjectSyncNotifier, bool>(
      BackgroundProjectSyncNotifier.new,
    );

class BackgroundProjectSyncNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setSyncing(bool value) => state = value;
}

// --- Projects state ---

/// Holds the list of all loaded projects.
final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<MasterProject>>(
      ProjectsNotifier.new,
    );

class ProjectsNotifier extends AsyncNotifier<List<MasterProject>> {
  StreamSubscription<FileSystemEvent>? _watchSub;
  StreamSubscription<FileSystemEvent>? _archiveWatchSub;
  bool _calendarSyncInProgress = false;
  Map<String, MasterProject> _scheduledProjectsByPath = const {};

  @override
  Future<List<MasterProject>> build() async {
    // Use ref.watch so provider rebuilds when storage path changes
    final fileService = ref.watch(fileServiceProvider);
    final projects = await fileService.readAllProjects();

    // Apply any pending "Done!" completions queued by the background
    // notification handler while the app was closed.
    final withCompletions = await _applyNotificationCompletionQueue(projects);

    // Auto-advance any recurring tasks whose alarm has passed
    final advancedProjects = await _autoAdvanceOverdueRecurringTodos(
      withCompletions,
    );

    // Wire the foreground "Done!" notification action so tapping it while the
    // app is open immediately toggles the task without going through the queue.
    NotificationService.onDoneAction = (filePath, todoId) async {
      if (ref.mounted) await toggleTodo(filePath, todoId);
    };

    // Schedule notifications in the background – don't block UI
    _scheduleAllNotificationsInBackground(advancedProjects);

    // Sync calendar changes in the background after fast file load
    _syncCalendarInBackground(advancedProjects);

    // Watch for external file changes (set up after writes so auto-advance
    // doesn't trigger an immediate spurious reload)
    _startWatching();

    // Cancel watching when provider is disposed
    ref.onDispose(() {
      _watchSub?.cancel();
      _archiveWatchSub?.cancel();
    });

    return advancedProjects;
  }

  /// Fire-and-forget notification scheduling so it never blocks build/reload.
  void _scheduleAllNotificationsInBackground(List<MasterProject> projects) {
    Future(() async {
      final notifService = ref.read(notificationServiceProvider);
      await notifService.init();

      final previousProjects = _scheduledProjectsByPath;
      final nextProjects = <String, MasterProject>{
        for (final project in projects) project.filePath: project,
      };

      final removedProjects = previousProjects.keys.toSet().difference(
        nextProjects.keys.toSet(),
      );
      for (final filePath in removedProjects) {
        final removedProject = previousProjects[filePath];
        if (removedProject == null) continue;
        for (final todo in removedProject.todos) {
          await notifService.cancelSubTodoNotifications(todo);
        }
      }

      for (final project in projects) {
        if (previousProjects[project.filePath] != project) {
          await notifService.rescheduleProjectNotifications(project);
        }
      }

      _scheduledProjectsByPath = nextProjects;
    });
  }

  /// Pulls latest changes from file storage and calendar.
  Future<List<MasterProject>> _syncProjectsFromSources(
    List<MasterProject> projects,
  ) async {
    final calSyncEnabled = ref.read(calendarSyncEnabledProvider);
    if (!calSyncEnabled) return projects;

    final calendarId = ref.read(selectedCalendarIdProvider);
    if (calendarId == null) return projects;

    final calService = ref.read(calendarServiceProvider);
    final fileService = ref.read(fileServiceProvider);

    try {
      final changes = await calService.syncAllProjects(
        projects: projects,
        calendarId: calendarId,
      );

      if (changes.isEmpty) return projects;

      for (final updated in changes.values) {
        await fileService.writeProject(updated);
      }

      return fileService.readAllProjects();
    } catch (e) {
      debugPrint('[ProjectsNotifier] calendar sync error: $e');
      return projects;
    }
  }

  /// Runs calendar sync after initial file load so startup stays responsive.
  void _syncCalendarInBackground(List<MasterProject> projects) {
    if (_calendarSyncInProgress) return;

    final calSyncEnabled = ref.read(calendarSyncEnabledProvider);
    final calendarId = ref.read(selectedCalendarIdProvider);
    if (!calSyncEnabled || calendarId == null) return;

    _calendarSyncInProgress = true;
    ref.read(backgroundProjectSyncProvider.notifier).setSyncing(true);

    Future(() async {
      try {
        final syncedProjects = await _syncProjectsFromSources(projects);
        if (!ref.mounted) return;

        if (!_sameProjectSnapshot(projects, syncedProjects)) {
          state = AsyncData(syncedProjects);
          ref.invalidate(archivedProjectsProvider);
          _scheduleAllNotificationsInBackground(syncedProjects);
        }
      } finally {
        _calendarSyncInProgress = false;
        if (ref.mounted) {
          ref.read(backgroundProjectSyncProvider.notifier).setSyncing(false);
        }
      }
    });
  }

  bool _sameProjectSnapshot(
    List<MasterProject> previous,
    List<MasterProject> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;

    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != next[index]) return false;
    }

    return true;
  }

  void _startWatching() {
    _watchSub?.cancel();
    _archiveWatchSub?.cancel();
    final fileService = ref.read(fileServiceProvider);
    _watchSub = fileService.watchDirectory().listen((event) {
      // Debounce: reload after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        reload();
      });
    });
    _archiveWatchSub = fileService.watchArchiveDirectory().listen((event) {
      Future.delayed(const Duration(milliseconds: 500), () {
        reload();
      });
    });
  }

  /// Syncs a sub-todo to the device calendar if sync is enabled.
  /// Returns the updated todo with calendarEventId set.
  Future<SubTodo> _syncTodoToCalendar({
    required SubTodo todo,
    required MasterProject project,
  }) async {
    final calSyncEnabled = ref.read(calendarSyncEnabledProvider);
    if (!calSyncEnabled || !project.syncWithCalendar) return todo;
    if (!todo.syncToCalendar) {
      await _removeTodoFromCalendar(todo);
      return todo.copyWith(clearCalendarEventId: true);
    }
    if (todo.alarm == null) return todo;

    final calendarId = ref.read(selectedCalendarIdProvider);
    if (calendarId == null) return todo;

    final calService = ref.read(calendarServiceProvider);
    try {
      final eventId = await calService.upsertEvent(
        calendarId: calendarId,
        todo: todo,
        projectTitle: project.title,
        existingEventId: todo.calendarEventId,
      );
      if (eventId != null) {
        return todo.copyWith(calendarEventId: eventId);
      }
    } catch (_) {
      // Calendar sync failure shouldn't block the operation
    }
    return todo;
  }

  /// Removes a sub-todo's calendar event if it exists.
  Future<void> _removeTodoFromCalendar(SubTodo todo) async {
    if (todo.calendarEventId == null) return;
    final calendarId = ref.read(selectedCalendarIdProvider);
    if (calendarId == null) return;

    final calService = ref.read(calendarServiceProvider);
    try {
      await calService.deleteEvent(
        calendarId: calendarId,
        eventId: todo.calendarEventId!,
      );
    } catch (_) {
      // Ignore calendar deletion failures
    }
  }

  Future<SubTodo> _prepareTodoForSave({
    required SubTodo todo,
    required MasterProject project,
    SubTodo? previousTodo,
  }) async {
    final normalizedTodo = todo.normalizedSchedule();
    final notifService = ref.read(notificationServiceProvider);

    await notifService.cancelSubTodoNotifications(normalizedTodo);

    final todoForCleanup = previousTodo ?? normalizedTodo;

    if (normalizedTodo.isCompleted || normalizedTodo.alarm == null) {
      await _removeTodoFromCalendar(todoForCleanup);
      return normalizedTodo.copyWith(clearCalendarEventId: true);
    }

    final syncedTodo = await _syncTodoToCalendar(
      todo: normalizedTodo,
      project: project,
    );

    await notifService.scheduleSubTodoAlarm(
      todo: syncedTodo,
      projectTitle: project.title,
      projectFilePath: project.filePath,
    );
    await notifService.scheduleSubTodoReminder(
      todo: syncedTodo,
      projectTitle: project.title,
      projectFilePath: project.filePath,
    );

    return syncedTodo;
  }

  Future<MasterProject> _persistProjectUpdate({
    required MasterProject project,
    required List<SubTodo> todos,
  }) async {
    final preparedTodos = <SubTodo>[];
    for (var index = 0; index < todos.length; index++) {
      final withLineIndex = todos[index].copyWith(lineIndex: index);
      final previousTodo = project.todos
          .where((todo) => todo.id == withLineIndex.id)
          .firstOrNull;
      final preparedTodo = await _prepareTodoForSave(
        todo: withLineIndex,
        project: project,
        previousTodo: previousTodo,
      );
      preparedTodos.add(preparedTodo.copyWith(lineIndex: index));
    }

    final updatedProject = project.copyWith(todos: preparedTodos);
    final fileService = ref.read(fileServiceProvider);
    await fileService.writeProject(updatedProject);
    return updatedProject;
  }

  /// Reads the pending-completion queue file that the background notification
  /// handler writes to when the user taps "Done!" while the app is closed.
  /// Applies each queued toggle to [projects] and returns the updated list.
  Future<List<MasterProject>> _applyNotificationCompletionQueue(
    List<MasterProject> projects,
  ) async {
    try {
      final fileService = ref.read(fileServiceProvider);
      final basePath = await fileService.effectiveStoragePath;
      final queueFile = File('$basePath/.markdone_queue');
      if (!await queueFile.exists()) return projects;

      final contents = await queueFile.readAsString();
      await queueFile.delete();

      var updatedProjects = projects;
      for (final rawLine in contents.trim().split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;
        final sep = line.indexOf('|||');
        if (sep < 0) continue;
        final filePath = line.substring(0, sep);
        final todoId = line.substring(sep + 3);
        updatedProjects = await _toggleTodoInProjects(
          updatedProjects,
          filePath,
          todoId,
        );
      }
      return updatedProjects;
    } catch (_) {
      return projects;
    }
  }

  /// Applies a single toggle (complete or recurring-advance) to [projects]
  /// without touching Riverpod state — safe to call during [build].
  Future<List<MasterProject>> _toggleTodoInProjects(
    List<MasterProject> projects,
    String filePath,
    String todoId,
  ) async {
    final projectIdx = projects.indexWhere((p) => p.filePath == filePath);
    if (projectIdx < 0) return projects;

    final project = projects[projectIdx];
    final todoIdx = project.todos.indexWhere((t) => t.id == todoId);
    if (todoIdx < 0) return projects;

    final todo = project.todos[todoIdx];
    final updatedTodo = todo.isRecurring
        ? _advanceRecurringTodo(todo)
        : todo.copyWith(isCompleted: true);

    final updatedTodos = List<SubTodo>.from(project.todos);
    updatedTodos[todoIdx] = updatedTodo;

    final updatedProject = await _persistProjectUpdate(
      project: project,
      todos: updatedTodos,
    );

    final updatedProjects = List<MasterProject>.from(projects);
    updatedProjects[projectIdx] = updatedProject;
    return updatedProjects;
  }

  /// Scans all projects on load and advances any recurring tasks whose alarm
  /// has already passed, so the user sees up-to-date dates without having to
  /// manually tap the checkbox.
  Future<List<MasterProject>> _autoAdvanceOverdueRecurringTodos(
    List<MasterProject> projects,
  ) async {
    final now = DateTime.now();
    final updatedProjects = <MasterProject>[];
    var anyChanged = false;

    for (final project in projects) {
      final hasOverdue = project.todos.any(
        (t) =>
            t.isRecurring &&
            !t.isCompleted &&
            t.alarm != null &&
            t.alarm!.isBefore(now),
      );

      if (!hasOverdue) {
        updatedProjects.add(project);
        continue;
      }

      anyChanged = true;
      final updatedTodos = project.todos.map((todo) {
        if (todo.isRecurring &&
            !todo.isCompleted &&
            todo.alarm != null &&
            todo.alarm!.isBefore(now)) {
          return _advanceRecurringTodo(todo);
        }
        return todo;
      }).toList();

      final updatedProject = await _persistProjectUpdate(
        project: project,
        todos: updatedTodos,
      );
      updatedProjects.add(updatedProject);
    }

    return anyChanged ? updatedProjects : projects;
  }

  SubTodo _advanceRecurringTodo(SubTodo todo) {
    final alarm = todo.alarm;
    final recurrence = todo.recurrence;
    if (alarm == null || recurrence == null) return todo;

    final now = DateTime.now();
    final advanceAfter = alarm.isAfter(now) ? alarm : now;

    final nextAlarm = RecurrenceService.nextOccurrence(
      alarm: alarm,
      rule: recurrence,
      after: advanceAfter,
    );
    if (nextAlarm == null) return todo;

    return todo.copyWith(
      isCompleted: false,
      alarm: nextAlarm,
      recurrence: recurrence.retargetToAlarm(alarm),
    );
  }

  /// Reloads all projects from disk.
  Future<void> reload() async {
    state = const AsyncLoading();
    final fileService = ref.read(fileServiceProvider);
    try {
      final projects = await fileService.readAllProjects();
      final withCompletions = await _applyNotificationCompletionQueue(projects);
      final advancedProjects = await _autoAdvanceOverdueRecurringTodos(
        withCompletions,
      );
      state = AsyncData(advancedProjects);
      ref.invalidate(archivedProjectsProvider);
      // Reschedule notifications in the background
      _scheduleAllNotificationsInBackground(advancedProjects);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Forces a refresh from files and calendar sources.
  Future<void> syncEverything() async {
    state = const AsyncLoading();
    final fileService = ref.read(fileServiceProvider);
    try {
      ref.read(backgroundProjectSyncProvider.notifier).setSyncing(true);
      final projects = await fileService.readAllProjects();
      final syncedProjects = await _syncProjectsFromSources(projects);
      state = AsyncData(syncedProjects);
      ref.invalidate(archivedProjectsProvider);
      _scheduleAllNotificationsInBackground(syncedProjects);
    } catch (e, st) {
      state = AsyncError(e, st);
    } finally {
      if (ref.mounted) {
        ref.read(backgroundProjectSyncProvider.notifier).setSyncing(false);
      }
    }
  }

  /// Creates a new project.
  Future<MasterProject> createProject({
    required String title,
    DateTime? dday,
    String? color,
    String? description,
    String? bgColor,
    bool syncWithCalendar = false,
  }) async {
    final fileService = ref.read(fileServiceProvider);
    final project = await fileService.createProject(
      title: title,
      dday: dday,
      color: color,
      description: description,
      bgColor: bgColor,
      syncWithCalendar: syncWithCalendar,
    );
    await reload();
    return project;
  }

  /// Deletes a project.
  Future<void> deleteProject(String filePath) async {
    final fileService = ref.read(fileServiceProvider);
    final notifService = ref.read(notificationServiceProvider);

    // Cancel all notifications for this project
    final current = state.value ?? [];
    final project = current.where((p) => p.filePath == filePath).firstOrNull;
    if (project != null) {
      for (final todo in project.todos) {
        await notifService.cancelSubTodoNotifications(todo);
      }
    }

    await fileService.deleteProject(filePath);
    await reload();
  }

  /// Moves a project into the archive folder.
  Future<void> archiveProject(String filePath) async {
    final fileService = ref.read(fileServiceProvider);
    await fileService.archiveProject(filePath);
    await reload();
  }

  /// Restores an archived project to the active projects folder.
  Future<void> restoreProject(String filePath) async {
    final fileService = ref.read(fileServiceProvider);
    await fileService.restoreProject(filePath);
    await reload();
  }

  /// Toggles a sub-todo's completion state.
  Future<void> toggleTodo(String filePath, String todoId) async {
    final current = state.value ?? [];
    final projectIdx = current.indexWhere((p) => p.filePath == filePath);
    if (projectIdx < 0) return;

    final project = current[projectIdx];
    final todoIdx = project.todos.indexWhere((t) => t.id == todoId);
    if (todoIdx < 0) return;

    final todo = project.todos[todoIdx];
    final toggledCompleted = !todo.isCompleted;
    final updatedTodo = toggledCompleted && todo.isRecurring
        ? _advanceRecurringTodo(todo)
        : todo.copyWith(isCompleted: toggledCompleted);

    final updatedTodos = List<SubTodo>.from(project.todos);
    updatedTodos[todoIdx] = updatedTodo;
    final updatedProject = await _persistProjectUpdate(
      project: project,
      todos: updatedTodos,
    );

    // Optimistic update
    final updatedProjects = List<MasterProject>.from(current);
    updatedProjects[projectIdx] = updatedProject;
    state = AsyncData(updatedProjects);
  }

  /// Adds a new sub-todo to a project.
  Future<void> addTodo(String filePath, SubTodo todo) async {
    final current = state.value ?? [];
    final projectIdx = current.indexWhere((p) => p.filePath == filePath);
    if (projectIdx < 0) return;

    final project = current[projectIdx];
    final updatedTodos = List<SubTodo>.from(project.todos)..add(todo);
    final updatedProject = await _persistProjectUpdate(
      project: project,
      todos: updatedTodos,
    );

    final updatedProjects = List<MasterProject>.from(current);
    updatedProjects[projectIdx] = updatedProject;
    state = AsyncData(updatedProjects);
  }

  /// Updates a sub-todo within a project.
  Future<void> updateTodo(String filePath, SubTodo updatedTodo) async {
    final current = state.value ?? [];
    final projectIdx = current.indexWhere((p) => p.filePath == filePath);
    if (projectIdx < 0) return;

    final project = current[projectIdx];
    final todoIdx = project.todos.indexWhere((t) => t.id == updatedTodo.id);
    if (todoIdx < 0) return;

    final updatedTodos = List<SubTodo>.from(project.todos);
    updatedTodos[todoIdx] = updatedTodo;
    final updatedProject = await _persistProjectUpdate(
      project: project,
      todos: updatedTodos,
    );

    final updatedProjects = List<MasterProject>.from(current);
    updatedProjects[projectIdx] = updatedProject;
    state = AsyncData(updatedProjects);
  }

  /// Removes a sub-todo from a project.
  Future<void> removeTodo(String filePath, String todoId) async {
    final current = state.value ?? [];
    final projectIdx = current.indexWhere((p) => p.filePath == filePath);
    if (projectIdx < 0) return;

    final project = current[projectIdx];
    final todo = project.todos.firstWhere((t) => t.id == todoId);

    final notifService = ref.read(notificationServiceProvider);
    await notifService.cancelSubTodoNotifications(todo);
    // Remove calendar event
    await _removeTodoFromCalendar(todo);

    final updatedTodos = project.todos.where((t) => t.id != todoId).toList();
    final updatedProject = await _persistProjectUpdate(
      project: project,
      todos: updatedTodos,
    );

    final updatedProjects = List<MasterProject>.from(current);
    updatedProjects[projectIdx] = updatedProject;
    state = AsyncData(updatedProjects);
  }

  /// Reorders a pending sub-todo within a project (drag-to-reorder).
  /// [oldIndex] and [newIndex] are indices within the pending (non-completed)
  /// todo list. Persists the new order via sortOrder metadata.
  Future<void> reorderTodo(String filePath, int oldIndex, int newIndex) async {
    final current = state.value ?? [];
    final projectIdx = current.indexWhere((p) => p.filePath == filePath);
    if (projectIdx < 0) return;

    final project = current[projectIdx];

    // Split into pending and completed, preserving their relative order
    final pending = project.todos.where((t) => !t.isCompleted).toList();
    final completed = project.todos.where((t) => t.isCompleted).toList();

    if (oldIndex < 0 || oldIndex >= pending.length) return;
    if (newIndex < 0 || newIndex > pending.length) return;

    // Flutter's ReorderableList uses newIndex after removal semantics
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;

    final item = pending.removeAt(oldIndex);
    pending.insert(adjusted, item);

    // Stamp sortOrder so custom order survives a reload
    final reorderedPending = <SubTodo>[];
    for (var i = 0; i < pending.length; i++) {
      reorderedPending.add(pending[i].copyWith(sortOrder: i));
    }

    final updatedTodos = [...reorderedPending, ...completed];
    final updatedProject = await _persistProjectUpdate(
      project: project,
      todos: updatedTodos,
    );

    final updatedProjects = List<MasterProject>.from(current);
    updatedProjects[projectIdx] = updatedProject;
    state = AsyncData(updatedProjects);
  }

  /// Updates project metadata (title, dday, color etc.).
  Future<void> updateProjectMetadata(MasterProject updated) async {
    final fileService = ref.read(fileServiceProvider);
    await fileService.writeProject(updated);
    await reload();
  }
}

// --- Derived providers ---

/// Provider for a single project by file path.
final projectByPathProvider = Provider.family<MasterProject?, String>((
  ref,
  filePath,
) {
  final projects = ref.watch(projectsProvider).value ?? [];
  final archivedProjects = ref
      .watch(archivedProjectsProvider)
      .maybeWhen(data: (projects) => projects, orElse: () => <MasterProject>[]);
  return [
    ...projects,
    ...archivedProjects,
  ].where((p) => p.filePath == filePath).firstOrNull;
});

/// Provider for archived projects.
final archivedProjectsProvider = FutureProvider<List<MasterProject>>((
  ref,
) async {
  ref.watch(projectsProvider);
  final fileService = ref.watch(fileServiceProvider);
  return fileService.readAllProjects(archived: true);
});

/// Provider for active projects, keeping completed ones at the bottom.
final sortedProjectsProvider = Provider<List<MasterProject>>((ref) {
  final projectsAsync = ref.watch(projectsProvider);
  final projects = projectsAsync.value ?? [];

  if (projects.isEmpty) return [];

  final sorted = List<MasterProject>.from(projects);

  sorted.sort((a, b) {
    final aCompleted = a.isCompletedProject;
    final bCompleted = b.isCompletedProject;
    if (aCompleted != bCompleted) {
      return aCompleted ? 1 : -1;
    }

    final aHasDday = a.dday != null;
    final bHasDday = b.dday != null;
    if (aHasDday != bHasDday) {
      return bHasDday ? 1 : -1;
    }

    if (aHasDday && bHasDday) {
      final ddayOrder = _compareDdayPriority(a, b);
      if (ddayOrder != 0) return ddayOrder;
    }

    return a.title.compareTo(b.title);
  });

  return sorted;
});

int _compareDdayPriority(MasterProject a, MasterProject b) {
  final aDays = a.daysUntilDday!;
  final bDays = b.daysUntilDday!;
  final aPast = aDays < 0;
  final bPast = bDays < 0;

  if (aPast != bPast) {
    return aPast ? 1 : -1;
  }

  if (!aPast) {
    return aDays.compareTo(bDays);
  }

  return bDays.compareTo(aDays);
}

/// Provider for projects with D-Day events, sorted by nearest upcoming date first.
final ddayProjectsProvider = Provider<List<MasterProject>>((ref) {
  final projects = ref.watch(sortedProjectsProvider);

  final ddayProjects = <MasterProject>[];
  for (final p in projects) {
    if (p.dday != null) {
      ddayProjects.add(p);
    }
  }

  ddayProjects.sort(_compareDdayPriority);

  return ddayProjects;
});

/// Provider for upcoming sub-todo alarms across all projects.
final upcomingAlarmsProvider =
    Provider<List<({MasterProject project, SubTodo todo})>>((ref) {
      final projectsAsync = ref.watch(projectsProvider);
      final projects = projectsAsync.value ?? [];
      final now = DateTime.now();
      final items = <({MasterProject project, SubTodo todo})>[];

      for (final project in projects) {
        for (final todo in project.todos) {
          if (!todo.isCompleted &&
              todo.alarm != null &&
              todo.alarm!.isAfter(now)) {
            items.add((project: project, todo: todo));
          }
        }
      }

      if (items.length > 1) {
        items.sort((a, b) => a.todo.alarm!.compareTo(b.todo.alarm!));
      }
      return items;
    });
