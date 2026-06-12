import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';
import 'project_providers.dart';
import 'settings_providers.dart';

/// Emits the current [DateTime] every 30 seconds so widgets that depend on
/// wall-clock time (heatmaps, day headers) rebuild automatically.
final nowProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield DateTime.now();
  }
});

final habitListProvider = AsyncNotifierProvider<HabitListNotifier, List<Habit>>(
  HabitListNotifier.new,
);

class HabitListNotifier extends AsyncNotifier<List<Habit>> {
  @override
  Future<List<Habit>> build() async {
    // Watch the storage path so the list reloads when the project folder changes.
    ref.watch(storagePathProvider);
    final service = ref.read(habitServiceProvider);
    final notifService = ref.read(notificationServiceProvider);

    // Process any pending habit completions from background notification actions
    await _processHabitQueue(service);

    final habits = await service.loadHabits();

    // Wire foreground "Done" button for habit notifications
    NotificationService.onHabitDoneAction = _handleForegroundHabitDone;

    // Cancel stale + reschedule enabled habit reminders
    for (final h in habits) {
      notifService.cancelHabitReminder(h.id);
      if (h.reminderEnabled) {
        notifService.scheduleHabitReminder(
          habitId: h.id,
          habitName: h.name,
          hour: h.reminderHour,
          minute: h.reminderMinute,
          notificationMessage: h.notificationMessage,
        );
      }
    }

    return habits;
  }

  Future<void> _handleForegroundHabitDone(
    String habitId,
    [String? notificationDate,
  ]) async {
    final service = ref.read(habitServiceProvider);
    final date = _parseDateOrToday(notificationDate);
    try {
      final updated = await service.toggleDate(habitId, date);
      final current = state.asData?.value;
      if (current == null) return;
      state = AsyncData(
        current.map((h) => h.id == habitId ? updated : h).toList(),
      );
    } catch (_) {}
  }

  Future<void> _processHabitQueue(HabitService service) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final queueFile = File('${dir.path}/.habit_queue');
      if (!await queueFile.exists()) return;

      final content = await queueFile.readAsString();
      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toSet()
          .toList();

      await queueFile.delete();

      for (final line in lines) {
        try {
          final parts = line.trim().split('|||');
          final habitId = parts[0];
          final dateStr = parts.length >= 2 ? parts[1] : null;
          final date = _parseDateOrToday(dateStr);
          await service.toggleDate(habitId, date);
        } catch (_) {}
      }
    } catch (_) {}
  }

  static DateTime _parseDateOrToday(String? dateStr) {
    if (dateStr != null) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return DateTime.utc(y, m, d);
        }
      }
    }
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  Future<void> addHabit(
    String name,
    String color, {
    bool reminderEnabled = false,
    int reminderHour = 0,
    int reminderMinute = 0,
    String notificationMessage = 'Did you complete this habit today?',
    int goal = 0,
  }) async {
    final service = ref.read(habitServiceProvider);
    final notifService = ref.read(notificationServiceProvider);
    final habit = await service.addHabit(
      name,
      color,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      notificationMessage: notificationMessage,
      goal: goal,
    );
    state = AsyncData([...state.value ?? [], habit]);

    if (reminderEnabled) {
      notifService.scheduleHabitReminder(
        habitId: habit.id,
        habitName: habit.name,
        hour: reminderHour,
        minute: reminderMinute,
        notificationMessage: notificationMessage,
      );
    }
  }

  Future<void> toggleDate(String habitId, DateTime date) async {
    final service = ref.read(habitServiceProvider);
    final updated = await service.toggleDate(habitId, date);
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.map((h) => h.id == habitId ? updated : h).toList(),
    );
  }

  Future<void> updateHabit(Habit habit) async {
    final service = ref.read(habitServiceProvider);
    final notifService = ref.read(notificationServiceProvider);
    await service.updateHabit(habit);
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.map((h) => h.id == habit.id ? habit : h).toList(),
    );

    notifService.cancelHabitReminder(habit.id);
    if (habit.reminderEnabled) {
      notifService.scheduleHabitReminder(
        habitId: habit.id,
        habitName: habit.name,
        hour: habit.reminderHour,
        minute: habit.reminderMinute,
        notificationMessage: habit.notificationMessage,
      );
    }
  }

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    final service = ref.read(habitServiceProvider);
    final current = state.asData?.value;
    if (current == null) return;
    final habits = [...current];
    final item = habits.removeAt(oldIndex);
    habits.insert(newIndex, item);
    state = AsyncData(habits);
    await service.saveHabits(habits);
  }

  Future<void> deleteHabit(String id) async {
    final service = ref.read(habitServiceProvider);
    final notifService = ref.read(notificationServiceProvider);
    await service.deleteHabit(id);
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.where((h) => h.id != id).toList());

    notifService.cancelHabitReminder(id);
  }
}

final habitByIdProvider = Provider.family<Habit?, String>((ref, id) {
  final habits = ref.watch(habitListProvider).asData?.value ?? [];
  return habits.where((h) => h.id == id).firstOrNull;
});
