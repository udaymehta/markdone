import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/models/habit.dart';
import 'package:markdone/models/master_project.dart';
import 'package:markdone/models/sub_todo.dart';

void main() {
  group('MasterProject', () {
    test('progress returns 0 for empty todos', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Test',
        created: DateTime(2026, 1, 1),
      );
      expect(project.progress, 0.0);
      expect(project.completedCount, 0);
      expect(project.pendingCount, 0);
      expect(project.isCompletedProject, false);
    });

    test('progress calculates correctly', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Test',
        created: DateTime(2026, 1, 1),
        todos: [
          SubTodo(id: '1', title: 'A', isCompleted: true, lineIndex: 0),
          SubTodo(id: '2', title: 'B', isCompleted: false, lineIndex: 1),
          SubTodo(id: '3', title: 'C', isCompleted: true, lineIndex: 2),
          SubTodo(id: '4', title: 'D', isCompleted: false, lineIndex: 3),
        ],
      );
      expect(project.progress, 0.5);
      expect(project.completedCount, 2);
      expect(project.pendingCount, 2);
    });

    test('isCompletedProject true when all todos done', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Test',
        created: DateTime(2026, 1, 1),
        todos: [
          SubTodo(id: '1', title: 'A', isCompleted: true, lineIndex: 0),
          SubTodo(id: '2', title: 'B', isCompleted: true, lineIndex: 1),
        ],
      );
      expect(project.isCompletedProject, true);
    });

    test('isCompletedProject false when empty todos', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Test',
        created: DateTime(2026, 1, 1),
      );
      expect(project.isCompletedProject, false);
    });

    test('isArchived true when path contains archive', () {
      final project = MasterProject(
        filePath: '/tmp/archive/test.md',
        title: 'Archived',
        created: DateTime(2026, 1, 1),
      );
      expect(project.isArchived, true);
    });

    test('fileName strips .md extension', () {
      final project = MasterProject(
        filePath: '/some/path/my_project.md',
        title: 'My Project',
        created: DateTime(2026, 1, 1),
      );
      expect(project.fileName, 'my_project');
    });

    test('fileName returns last segment for non-md paths', () {
      final project = MasterProject(
        filePath: '/some/path/data',
        title: 'Data',
        created: DateTime(2026, 1, 1),
      );
      expect(project.fileName, 'data');
    });

    test('daysUntilDday returns null when no dday', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Test',
        created: DateTime(2026, 1, 1),
      );
      expect(project.daysUntilDday, isNull);
    });

    test('toFrontmatterMap includes title and created', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'My Project',
        created: DateTime(2026, 3, 14),
      );
      final map = project.toFrontmatterMap();
      expect(map['title'], 'My Project');
      expect(map['created'], '2026-03-14');
      expect(map.containsKey('dday'), false);
      expect(map.containsKey('color'), false);
    });

    test('toFrontmatterMap includes optional fields', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Project',
        created: DateTime(2026, 1, 1),
        dday: DateTime(2026, 6, 15),
        color: '#FF6B35',
        bgColor: '#1E88E5',
        description: 'A test',
        syncWithCalendar: true,
      );
      final map = project.toFrontmatterMap();
      expect(map['dday'], '2026-06-15');
      expect(map['color'], '#FF6B35');
      expect(map['bg_color'], '#1E88E5');
      expect(map['description'], 'A test');
      expect(map['sync_calendar'], true);
    });

    test('copyWith preserves unchanged fields', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Original',
        created: DateTime(2026, 1, 1),
        dday: DateTime(2026, 6, 15),
      );
      final copy = project.copyWith(title: 'Updated');
      expect(copy.title, 'Updated');
      expect(copy.filePath, '/tmp/test.md');
      expect(copy.dday, DateTime(2026, 6, 15));
    });

    test('copyWith clearDday clears dday', () {
      final project = MasterProject(
        filePath: '/tmp/test.md',
        title: 'Test',
        created: DateTime(2026, 1, 1),
        dday: DateTime(2026, 6, 15),
      );
      final copy = project.copyWith(clearDday: true);
      expect(copy.dday, isNull);
    });
  });

  group('Habit', () {
    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);
    final yesterday = todayUtc.subtract(const Duration(days: 1));
    final twoDaysAgo = todayUtc.subtract(const Duration(days: 2));
    final threeDaysAgo = todayUtc.subtract(const Duration(days: 3));

    test('totalCompletions counts completed dates', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc, yesterday, twoDaysAgo],
      );
      expect(habit.totalCompletions, 3);
    });

    test('currentStreak returns 0 when no completions', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(habit.currentStreak, 0);
    });

    test('currentStreak returns 0 when neither today nor yesterday completed',
        () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [threeDaysAgo],
      );
      expect(habit.currentStreak, 0);
    });

    test('currentStreak counts consecutive days ending today', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc, yesterday, twoDaysAgo],
      );
      expect(habit.currentStreak, 3);
    });

    test('currentStreak counts from yesterday if today not completed', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [yesterday, twoDaysAgo],
      );
      expect(habit.currentStreak, 2);
    });

    test('longestStreak handles scattered dates', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [
          todayUtc,
          yesterday,
          twoDaysAgo,
          threeDaysAgo.subtract(const Duration(days: 5)),
          threeDaysAgo.subtract(const Duration(days: 6)),
        ],
      );
      expect(habit.longestStreak, 3);
    });

    test('longestStreak returns 1 for single date', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc],
      );
      expect(habit.longestStreak, 1);
    });

    test('completionRate returns 0 for non-positive days', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc],
      );
      expect(habit.completionRate(0), 0);
      expect(habit.completionRate(-1), 0);
    });

    test('completionRate calculates correctly over given window', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc, yesterday],
      );
      final rate = habit.completionRate(7);
      expect(rate, 2 / 7);
    });

    test('isCompletedOn checks normalized dates', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc],
      );
      expect(habit.isCompletedOn(today), true);
      expect(habit.isCompletedOn(yesterday), false);
    });

    test('toggleDate adds new date', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
      );
      final updated = habit.toggleDate(todayUtc);
      expect(updated.isCompletedOn(todayUtc), true);
      expect(updated.totalCompletions, 1);
    });

    test('toggleDate removes existing date', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [todayUtc],
      );
      final updated = habit.toggleDate(todayUtc);
      expect(updated.isCompletedOn(todayUtc), false);
      expect(updated.totalCompletions, 0);
    });

    test('monthlyBreakdown groups by year-month', () {
      final habit = Habit(
        id: '1',
        name: 'Exercise',
        createdAt: DateTime(2026, 1, 1),
        completedDates: [
          DateTime.utc(2026, 1, 5),
          DateTime.utc(2026, 1, 10),
          DateTime.utc(2026, 2, 3),
        ],
      );
      final breakdown = habit.monthlyBreakdown;
      expect(breakdown['2026-01'], 2);
      expect(breakdown['2026-02'], 1);
    });

    test('CSV round-trip preserves data', () {
      final habit = Habit(
        id: 'test-id',
        name: 'Test Habit',
        createdAt: DateTime(2026, 3, 14),
        color: '#FF6B35',
        completedDates: [todayUtc, yesterday],
        reminderEnabled: true,
        reminderHour: 9,
        reminderMinute: 30,
        notificationMessage: 'Custom message',
        sortOrder: 2,
        goal: 5,
      );
      final csv = habit.toCsvRow();
      final parsed = Habit.fromCsvRow(csv)!;
      expect(parsed.id, habit.id);
      expect(parsed.name, habit.name);
      expect(parsed.color, habit.color);
      expect(parsed.totalCompletions, habit.totalCompletions);
      expect(parsed.reminderEnabled, habit.reminderEnabled);
      expect(parsed.reminderHour, habit.reminderHour);
      expect(parsed.reminderMinute, habit.reminderMinute);
      expect(parsed.sortOrder, habit.sortOrder);
      expect(parsed.goal, habit.goal);
    });
  });

  group('SubTodo', () {
    group('normalizedSchedule', () {
      test('returns same when no alarm, recurrence, or reminder', () {
        final todo = SubTodo(
          id: '1',
          title: 'Task',
          isCompleted: false,
          lineIndex: 0,
        );
        expect(todo.normalizedSchedule(), same(todo));
      });

      test('clears recurrence and reminder when alarm is null', () {
        final todo = SubTodo(
          id: '1',
          title: 'Task',
          isCompleted: false,
          lineIndex: 0,
          recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
          reminderBefore: const Duration(days: 1),
        );
        final normalized = todo.normalizedSchedule();
        expect(normalized.recurrence, isNull);
        expect(normalized.reminderBefore, isNull);
        expect(normalized.title, todo.title);
      });

      test('returns same when alarm exists but no recurrence', () {
        final todo = SubTodo(
          id: '1',
          title: 'Task',
          isCompleted: false,
          lineIndex: 0,
          alarm: DateTime(2026, 6, 15, 9, 0),
          reminderBefore: const Duration(hours: 1),
        );
        expect(todo.normalizedSchedule(), same(todo));
      });

    test('filled missing anchor from alarm when retargeting', () {
      final todo = SubTodo(
        id: '1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
        alarm: DateTime(2026, 6, 15, 9, 0),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
        ),
      );
      final normalized = todo.normalizedSchedule();
      expect(normalized.recurrence!.anchorDay, 15);
      expect(normalized.recurrence!.anchorMonth, isNull);
    });

    test('fills missing yearly anchor month from alarm', () {
      final todo = SubTodo(
        id: '1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
        alarm: DateTime(2026, 7, 4, 9, 0),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
        ),
      );
      final normalized = todo.normalizedSchedule();
      expect(normalized.recurrence!.anchorDay, 4);
      expect(normalized.recurrence!.anchorMonth, 7);
    });

    test('keeps existing anchor when it already matches', () {
      final todo = SubTodo(
        id: '1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
        alarm: DateTime(2026, 6, 15, 9, 0),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          anchorDay: 15,
        ),
      );
      expect(todo.normalizedSchedule(), same(todo));
    });

    test('does not overwrite existing anchor day', () {
      final todo = SubTodo(
        id: '1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
        alarm: DateTime(2026, 7, 4, 9, 0),
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          anchorDay: 10,
        ),
      );
      final normalized = todo.normalizedSchedule();
      expect(normalized.recurrence!.anchorDay, 10);
    });
    });

    test('generateId produces non-empty string', () {
      final id = SubTodo.generateId();
      expect(id, isNotEmpty);
    });

    test('isRecurring returns true when recurrence is set', () {
      final todo = SubTodo(
        id: '1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.daily),
      );
      expect(todo.isRecurring, true);
    });

    test('reminderString formats correctly', () {
      final todo = SubTodo(
        id: '1',
        title: 'Task',
        isCompleted: false,
        lineIndex: 0,
        reminderBefore: const Duration(days: 2),
      );
      expect(todo.reminderString, '2d');
      expect(todo.reminderLabel, '2 days');
    });
  });

  group('ReminderConfig', () {
    test('fromString parses duration suffixes', () {
      expect(ReminderConfig.fromString('30m')?.duration, const Duration(minutes: 30));
      expect(ReminderConfig.fromString('2h')?.duration, const Duration(hours: 2));
      expect(ReminderConfig.fromString('3d')?.duration, const Duration(days: 3));
      expect(ReminderConfig.fromString('2w')?.duration, const Duration(days: 14));
    });

    test('fromString returns null for invalid input', () {
      expect(ReminderConfig.fromString(null), isNull);
      expect(ReminderConfig.fromString(''), isNull);
      expect(ReminderConfig.fromString('abc'), isNull);
      expect(ReminderConfig.fromString('0d'), isNull);
      expect(ReminderConfig.fromString('-1h'), isNull);
    });

    test('fromDuration selects largest clean unit', () {
      expect(ReminderConfig.fromDuration(const Duration(minutes: 90))?.compact, '90m');
      expect(ReminderConfig.fromDuration(const Duration(minutes: 120))?.compact, '2h');
      expect(ReminderConfig.fromDuration(const Duration(days: 5))?.compact, '5d');
      expect(ReminderConfig.fromDuration(const Duration(days: 14))?.compact, '2w');
    });

    test('fromDuration returns null for zero or negative', () {
      expect(ReminderConfig.fromDuration(Duration.zero), isNull);
      expect(ReminderConfig.fromDuration(const Duration(minutes: -5)), isNull);
    });
  });

  group('RecurrenceRule', () {
    test('fromJson parses string frequency', () {
      final rule = RecurrenceRule.fromJson('daily');
      expect(rule?.frequency, RecurrenceFrequency.daily);
      expect(rule?.interval, 1);
    });

    test('fromJson returns null for unknown string', () {
      expect(RecurrenceRule.fromJson('fortnightly'), isNull);
    });

    test('fromJson parses map with all fields', () {
      final rule = RecurrenceRule.fromJson({
        'frequency': 'monthly',
        'interval': 3,
        'anchorDay': 15,
      });
      expect(rule?.frequency, RecurrenceFrequency.monthly);
      expect(rule?.interval, 3);
      expect(rule?.anchorDay, 15);
    });

    test('fromJson stores anchorDay regardless of frequency', () {
      final rule = RecurrenceRule.fromJson({
        'frequency': 'daily',
        'anchorDay': 15,
      });
      expect(rule?.anchorDay, 15);
      expect(rule?.usesAnchorDay, false);
    });
  });

  group('RecurrenceFrequency parsing', () {
    test('recurrenceFrequencyFromKey handles all variants', () {
      expect(recurrenceFrequencyFromKey('minutely'), RecurrenceFrequency.minutely);
      expect(recurrenceFrequencyFromKey('hourly'), RecurrenceFrequency.hourly);
      expect(recurrenceFrequencyFromKey('daily'), RecurrenceFrequency.daily);
      expect(recurrenceFrequencyFromKey('weekly'), RecurrenceFrequency.weekly);
      expect(recurrenceFrequencyFromKey('monthly'), RecurrenceFrequency.monthly);
      expect(recurrenceFrequencyFromKey('yearly'), RecurrenceFrequency.yearly);
      expect(recurrenceFrequencyFromKey('day'), RecurrenceFrequency.daily);
      expect(recurrenceFrequencyFromKey('week'), RecurrenceFrequency.weekly);
      expect(recurrenceFrequencyFromKey('month'), RecurrenceFrequency.monthly);
      expect(recurrenceFrequencyFromKey(null), isNull);
      expect(recurrenceFrequencyFromKey('unknown'), isNull);
    });
  });

  group('ReminderUnit parsing', () {
    test('reminderUnitFromKey handles all variants', () {
      expect(reminderUnitFromKey('m'), ReminderUnit.minutes);
      expect(reminderUnitFromKey('h'), ReminderUnit.hours);
      expect(reminderUnitFromKey('d'), ReminderUnit.days);
      expect(reminderUnitFromKey('w'), ReminderUnit.weeks);
      expect(reminderUnitFromKey('minute'), ReminderUnit.minutes);
      expect(reminderUnitFromKey('hour'), ReminderUnit.hours);
      expect(reminderUnitFromKey('day'), ReminderUnit.days);
      expect(reminderUnitFromKey('week'), ReminderUnit.weeks);
      expect(reminderUnitFromKey(null), isNull);
    });
  });
}
