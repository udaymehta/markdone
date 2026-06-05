import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../providers/settings_providers.dart';

class HabitService {
  static const _fileName = 'habits.csv';

  /// May be set by the provider to mirror the project storage path.
  String? customBasePath;

  Future<String> get _baseDir async {
    if (customBasePath != null && customBasePath!.isNotEmpty) {
      final dir = Directory(customBasePath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return customBasePath!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  Future<File> get _file async {
    final base = await _baseDir;
    return File(p.join(base, _fileName));
  }

  Future<List<Habit>> loadHabits() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final lines =
          content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return [];
      final dataLines = lines[0].startsWith('id|') ? lines.sublist(1) : lines;
      return dataLines
          .map(Habit.fromCsvRow)
          .whereType<Habit>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHabits(List<Habit> habits) async {
    final file = await _file;
    // Ensure parent directory exists
    await file.parent.create(recursive: true);
    final buffer = StringBuffer('id|name|created_at|color|completed_dates|reminder_enabled|reminder_hour|reminder_minute|notification_message|sort_order|goal\n');
    for (final h in habits) {
      buffer.writeln(h.toCsvRow());
    }
    await file.writeAsString(buffer.toString());
  }

  Future<Habit> addHabit(
    String name,
    String color, {
    bool reminderEnabled = false,
    int reminderHour = 0,
    int reminderMinute = 0,
    String notificationMessage = 'Did you complete this habit today?',
    int goal = 0,
  }) async {
    final habits = await loadHabits();
    final maxOrder = habits.isEmpty ? 0 : habits.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b);
    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      color: color,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      notificationMessage: notificationMessage,
      sortOrder: maxOrder + 1,
      goal: goal,
    );
    habits.add(habit);
    await saveHabits(habits);
    return habit;
  }

  Future<void> updateHabit(Habit updated) async {
    final habits = await loadHabits();
    final index = habits.indexWhere((h) => h.id == updated.id);
    if (index != -1) {
      habits[index] = updated;
      await saveHabits(habits);
    }
  }

  Future<void> deleteHabit(String id) async {
    final habits = await loadHabits();
    habits.removeWhere((h) => h.id == id);
    await saveHabits(habits);
  }

  Future<Habit> toggleDate(String habitId, DateTime date) async {
    final habits = await loadHabits();
    final index = habits.indexWhere((h) => h.id == habitId);
    if (index == -1) throw Exception('Habit not found');
    habits[index] = habits[index].toggleDate(date);
    await saveHabits(habits);
    return habits[index];
  }
}

final habitServiceProvider = Provider<HabitService>((ref) {
  // Mirror the storage path used by FileService so habits.csv lives
  // alongside the project .md files.
  final storagePath = ref.watch(storagePathProvider);
  final service = HabitService();
  service.customBasePath = storagePath;
  return service;
});
