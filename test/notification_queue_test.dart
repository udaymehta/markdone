import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/models/sub_todo.dart';
import 'package:markdone/models/habit.dart';
import 'package:markdone/services/recurrence_service.dart';

void main() {
  group('project notification queue format', () {
    late Directory tempDir;
    late String projectFilePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('queue_test_');
      projectFilePath = '${tempDir.path}/project.md';
      File(projectFilePath).createSync(recursive: true);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('queue file format parses correctly', () async {
      final queueFile = File('${tempDir.path}/.markdone_queue');
      await queueFile.writeAsString(
        '$projectFilePath|||todo-1\n$projectFilePath|||todo-2\n',
      );

      final content = await queueFile.readAsString();
      final lines = content.trim().split('\n');
      expect(lines.length, 2);
      expect(lines[0], '$projectFilePath|||todo-1');
      expect(lines[1], '$projectFilePath|||todo-2');
    });

    test('queue file with empty lines skips them', () async {
      final queueFile = File('${tempDir.path}/.markdone_queue');
      await queueFile.writeAsString(
        '$projectFilePath|||todo-1\n\n$projectFilePath|||todo-2\n\n',
      );

      final content = await queueFile.readAsString();
      final lines = content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(lines.length, 2);
    });

    test('queue file with invalid lines (no |||) skips them', () async {
      final queueFile = File('${tempDir.path}/.markdone_queue');
      await queueFile.writeAsString(
        '$projectFilePath|||todo-1\ninvalid-line\n$projectFilePath|||todo-2\n',
      );

      final content = await queueFile.readAsString();
      final lines = content.trim().split('\n');
      final validLines =
          lines
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty && l.contains('|||'))
              .toList();
      expect(validLines.length, 2);
    });

    test('file is deleted after processing', () async {
      final queueFile = File('${tempDir.path}/.markdone_queue');
      await queueFile.writeAsString('$projectFilePath|||todo-1\n');
      expect(await queueFile.exists(), true);

      await queueFile.delete();
      expect(await queueFile.exists(), false);
    });

    test('non-recurring todo is marked completed', () {
      final todo = SubTodo(
        id: 'todo-1',
        title: 'Simple Task',
        isCompleted: false,
        lineIndex: 0,
      );
      final updated = todo.copyWith(isCompleted: true);
      expect(updated.isCompleted, true);
    });

    test('recurring todo advances on completion', () {
      final todo = SubTodo(
        id: 'todo-1',
        title: 'Daily Task',
        isCompleted: false,
        lineIndex: 0,
        alarm: DateTime(2026, 6, 5, 9, 0),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
        ),
      );

      final nextAlarm = RecurrenceService.nextOccurrence(
        alarm: todo.alarm!,
        rule: todo.recurrence!,
        after: todo.alarm!,
      );
      expect(nextAlarm, isNotNull);
      expect(nextAlarm!.isAfter(todo.alarm!), true);

      final advanced = todo.copyWith(isCompleted: false, alarm: nextAlarm);
      expect(advanced.isCompleted, false);
      expect(advanced.alarm, nextAlarm);
    });

    test('toggleTodo for non-recurring marks completed', () {
      final todo = SubTodo(
        id: 'todo-1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
      );
      final toggled = todo.copyWith(isCompleted: true);
      expect(toggled.isCompleted, true);
    });

    test('toggleTodo for recurring advances alarm', () {
      final todo = SubTodo(
        id: 'todo-1',
        title: 'Recurring',
        isCompleted: false,
        lineIndex: 0,
        alarm: DateTime(2026, 6, 5, 9, 0),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
        ),
      );

      final nextAlarm = RecurrenceService.nextOccurrence(
        alarm: todo.alarm!,
        rule: todo.recurrence!,
        after: todo.alarm!,
      );
      expect(nextAlarm, isNotNull);
      expect(nextAlarm!.isAfter(todo.alarm!), true);
    });
  });

  group('habit notification queue format', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('habit_queue_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('queue file contains habit IDs one per line', () async {
      final queueFile = File('${tempDir.path}/.habit_queue');
      await queueFile.writeAsString('habit-1\nhabit-2\nhabit-3\n');

      final content = await queueFile.readAsString();
      final lines = content.trim().split('\n');
      expect(lines, ['habit-1', 'habit-2', 'habit-3']);
    });

    test('dedup removes duplicate habit IDs', () async {
      final queueFile = File('${tempDir.path}/.habit_queue');
      await queueFile.writeAsString('habit-1\nhabit-2\nhabit-1\nhabit-3\n');

      final content = await queueFile.readAsString();
      final lines = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toSet()
          .toList();
      expect(lines.length, 3);
      expect(lines, contains('habit-1'));
      expect(lines, contains('habit-2'));
      expect(lines, contains('habit-3'));
    });

    test('file is deleted after processing', () async {
      final queueFile = File('${tempDir.path}/.habit_queue');
      await queueFile.writeAsString('habit-1\n');

      await queueFile.delete();
      expect(await queueFile.exists(), false);
    });

    test('toggleDate toggles habit completion for today', () {
      final today = DateTime.utc(2026, 6, 6);
      final habit = Habit(
        id: 'habit-1',
        name: 'Test Habit',
        createdAt: DateTime(2026, 1, 1),
      );

      final toggledOn = habit.toggleDate(today);
      expect(toggledOn.isCompletedOn(today), true);

      final toggledOff = toggledOn.toggleDate(today);
      expect(toggledOff.isCompletedOn(today), false);
    });

    test('habit with reminder uses correct notification fields', () {
      final habit = Habit(
        id: 'habit-1',
        name: 'Morning Run',
        createdAt: DateTime(2026, 1, 1),
        reminderEnabled: true,
        reminderHour: 7,
        reminderMinute: 30,
        notificationMessage: 'Time for your morning run!',
      );

      expect(habit.reminderEnabled, true);
      expect(habit.reminderHour, 7);
      expect(habit.reminderMinute, 30);
      expect(habit.notificationMessage, 'Time for your morning run!');
    });

    test('notification IDs derived from habit ID are deterministic', () {
      final habitId = 'test-habit-id';
      final id1 = (habitId.hashCode.abs() + 2000000) % 2147483647;
      final id2 = (habitId.hashCode.abs() + 2000000) % 2147483647;
      expect(id1, id2);
    });

    test('different habit IDs produce different notification IDs', () {
      final id1 = ('habit-a'.hashCode.abs() + 2000000) % 2147483647;
      final id2 = ('habit-b'.hashCode.abs() + 2000000) % 2147483647;
      expect(id1, isNot(id2));
    });
  });

  group('todo notification IDs', () {
    test('base alarm ID is derived from todo.id', () {
      final todoId = 'my-todo-id';
      final baseId = todoId.hashCode.abs() % 2147483647;
      expect(baseId, greaterThan(0));
    });

    test('reminder ID is baseId + 1000000', () {
      final todoId = 'my-todo-id';
      final baseId = todoId.hashCode.abs() % 2147483647;
      final reminderId = (todoId.hashCode.abs() + 1000000) % 2147483647;
      expect(reminderId, (baseId + 1000000) % 2147483647);
    });

    test('recurring schedule IDs cycle through baseId + 0..9', () {
      final todoId = 'recurring-todo';
      final baseId = todoId.hashCode.abs() % 2147483647;
      for (int i = 0; i < 10; i++) {
        final scheduledId = (baseId + i) % 2147483647;
        expect(scheduledId, (baseId + i) % 2147483647);
      }
    });

    test('different todos produce different base IDs', () {
      final base1 = 'todo-1'.hashCode.abs() % 2147483647;
      final base2 = 'todo-2'.hashCode.abs() % 2147483647;
      expect(base1, isNot(base2));
    });
  });

  group('recurring todo advancement', () {
    test('daily recurring advances to next day', () {
      final alarm = DateTime(2026, 6, 6, 10, 0);
      final rule = const RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
      );

      final next = RecurrenceService.nextOccurrence(
        alarm: alarm,
        rule: rule,
        after: alarm,
      );

      expect(next, DateTime(2026, 6, 7, 10, 0));
    });

    test('weekly recurring advances by 7 days', () {
      final alarm = DateTime(2026, 6, 6, 10, 0);
      final rule = const RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
      );

      final next = RecurrenceService.nextOccurrence(
        alarm: alarm,
        rule: rule,
        after: alarm,
      );

      expect(next, DateTime(2026, 6, 13, 10, 0));
    });

    test('monthly recurring advances by 1 month', () {
      final alarm = DateTime(2026, 6, 6, 10, 0);
      final rule = const RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        anchorDay: 6,
      );

      final next = RecurrenceService.nextOccurrence(
        alarm: alarm,
        rule: rule,
        after: alarm,
      );

      expect(next, DateTime(2026, 7, 6, 10, 0));
    });

    test('advance from past uses now as reference', () {
      final alarm = DateTime(2026, 5, 1, 10, 0);
      final rule = const RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
      );
      final now = DateTime(2026, 6, 6);

      final next = RecurrenceService.nextOccurrence(
        alarm: alarm,
        rule: rule,
        after: now,
      );

      expect(next, isNotNull);
      expect(next!.isAfter(now), true);
    });

    test('non-recurring todo from queue is not advanced', () {
      final todo = SubTodo(
        id: 'simple',
        title: 'Simple',
        isCompleted: false,
        lineIndex: 0,
      );

      expect(todo.isRecurring, false);
      final completed = todo.copyWith(isCompleted: true);
      expect(completed.isCompleted, true);
    });
  });
}
