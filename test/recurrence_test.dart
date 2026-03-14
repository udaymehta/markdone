import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/models/master_project.dart';
import 'package:markdone/models/sub_todo.dart';
import 'package:markdone/services/markdown_parser.dart';
import 'package:markdone/services/recurrence_service.dart';

void main() {
  group('RecurrenceService', () {
    test('supports custom hourly intervals', () {
      final next = RecurrenceService.nextOccurrence(
        alarm: DateTime(2026, 1, 1, 8),
        rule: RecurrenceRule.fromAlarm(
          frequency: RecurrenceFrequency.hourly,
          alarm: DateTime(2026, 1, 1, 8),
          interval: 2,
        ),
        after: DateTime(2026, 1, 1, 9, 30),
      );

      expect(next, DateTime(2026, 1, 1, 10));
    });

    test('moves monthly recurrence to valid last day', () {
      final next = RecurrenceService.nextOccurrence(
        alarm: DateTime(2026, 1, 31, 9),
        rule: RecurrenceRule.fromAlarm(
          frequency: RecurrenceFrequency.monthly,
          alarm: DateTime(2026, 1, 31, 9),
        ),
        after: DateTime(2026, 1, 31, 9),
      );

      expect(next, DateTime(2026, 2, 28, 9));
    });

    test('preserves yearly anchor month and day when possible', () {
      final next = RecurrenceService.nextOccurrence(
        alarm: DateTime(2024, 2, 29, 8, 30),
        rule: RecurrenceRule.fromAlarm(
          frequency: RecurrenceFrequency.yearly,
          alarm: DateTime(2024, 2, 29, 8, 30),
        ),
        after: DateTime(2025, 3, 1),
      );

      expect(next, DateTime(2026, 2, 28, 8, 30));
    });
  });

  group('ReminderConfig', () {
    test('parses week reminders', () {
      final reminder = ReminderConfig.fromString('2w');

      expect(reminder?.duration, const Duration(days: 14));
      expect(reminder?.label, '2 weeks');
    });

    test('prefers compact week labels for divisible durations', () {
      final reminder = ReminderConfig.fromDuration(const Duration(days: 14));

      expect(reminder?.compact, '2w');
      expect(reminder?.label, '2 weeks');
    });
  });

  group('MarkdownParser', () {
    test('round-trips recurring task metadata including stable id', () {
      final project = MasterProject(
        filePath: '/tmp/demo.md',
        title: 'Demo',
        created: DateTime(2026, 3, 14),
        todos: [
          SubTodo(
            id: 'task-123',
            title: 'Pay rent',
            isCompleted: false,
            alarm: DateTime(2026, 3, 31, 9, 15),
            reminderBefore: const Duration(days: 14),
            recurrence: RecurrenceRule.fromAlarm(
              frequency: RecurrenceFrequency.hourly,
              alarm: DateTime(2026, 3, 31, 9, 15),
              interval: 3,
            ),
            lineIndex: 0,
          ),
        ],
      );

      final serialized = MarkdownParser.serialize(project);
      final parsed = MarkdownParser.parse(serialized, project.filePath);
      final todo = parsed.todos.single;

      expect(todo.id, 'task-123');
      expect(todo.recurrence?.frequency, RecurrenceFrequency.hourly);
      expect(todo.recurrence?.interval, 3);
      expect(todo.recurrence?.anchorDay, isNull);
      expect(todo.alarm, DateTime(2026, 3, 31, 9, 15));
      expect(todo.reminderBefore, const Duration(days: 14));
      expect(todo.reminderString, '2w');
    });

    test('backfills legacy tasks with deterministic id', () {
      const content = '''
---
title: Legacy
created: 2026-03-14
---

- [ ] Legacy task <!-- {"alarm":"2026-03-20T09:00:00.000"} -->
''';

      final parsed = MarkdownParser.parse(content, '/tmp/legacy.md');

      expect(parsed.todos.single.id, isNotEmpty);
      expect(parsed.todos.single.toMetadataMap()['id'], isNotEmpty);
    });

    test('accepts legacy recurrence strings and custom reminder units', () {
      const content = '''
---
title: Legacy
created: 2026-03-14
---

- [ ] Water plants <!-- {"alarm":"2026-03-20T09:00:00.000","reminder":"2w","recurrence":"weekly"} -->
''';

      final parsed = MarkdownParser.parse(content, '/tmp/legacy-custom.md');
      final todo = parsed.todos.single;

      expect(todo.recurrence?.frequency, RecurrenceFrequency.weekly);
      expect(todo.recurrence?.interval, 1);
      expect(todo.reminderBefore, const Duration(days: 14));
    });
  });
}
