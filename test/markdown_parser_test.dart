import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/models/sub_todo.dart';
import 'package:markdone/services/markdown_parser.dart';

void main() {
  group('MarkdownParser', () {
    test('parses content with no frontmatter', () {
      const content = '- [ ] Buy milk\n- [x] Pay rent\n\nSome notes.';
      final project = MarkdownParser.parse(content, '/tmp/tasks.md');

      expect(project.title, 'tasks');
      expect(project.created, isNotNull);
      expect(project.todos.length, 2);
      expect(project.todos[0].title, 'Buy milk');
      expect(project.todos[0].isCompleted, false);
      expect(project.todos[1].title, 'Pay rent');
      expect(project.todos[1].isCompleted, true);
    });

    test('parses content with empty frontmatter', () {
      const content = '---\n---\n\n- [ ] Task';
      final project = MarkdownParser.parse(content, '/tmp/tasks.md');

      expect(project.title, 'tasks');
      expect(project.todos.length, 1);
    });

    test('parses content with malformed YAML frontmatter', () {
      const content = '---\n: invalid yaml :::\n---\n\n- [ ] Task';
      final project = MarkdownParser.parse(content, '/tmp/tasks.md');

      expect(project.todos.length, 1);
      expect(project.title, 'tasks');
    });

    test('parses content with special characters in titles', () {
      const content = '- [ ] Task with <b>HTML</b> & "quotes"\n- [ ] ñoño 日本語 ✓';
      final project = MarkdownParser.parse(content, '/tmp/tasks.md');

      expect(project.todos.length, 2);
      expect(project.todos[0].title, 'Task with <b>HTML</b> & "quotes"');
      expect(project.todos[1].title, 'ñoño 日本語 ✓');
    });

    test('produces stable deterministic ids for same content', () {
      const content = '- [ ] Buy milk\n- [x] Pay rent';
      final project1 = MarkdownParser.parse(content, '/tmp/tasks.md');
      final project2 = MarkdownParser.parse(content, '/tmp/tasks.md');

      expect(project1.todos[0].id, project2.todos[0].id);
      expect(project1.todos[1].id, project2.todos[1].id);
    });

    test('produces different ids for different file paths', () {
      const content = '- [ ] Buy milk';
      final project1 = MarkdownParser.parse(content, '/tmp/a.md');
      final project2 = MarkdownParser.parse(content, '/tmp/b.md');

      expect(project1.todos[0].id, isNot(project2.todos[0].id));
    });

    test('parses frontmatter with all optional fields', () {
      const content = '''
---
title: My Project
created: 2026-03-14
dday: 2026-06-15
color: "#FF6B35"
bg_color: "#1E88E5"
description: A sample project
sync_calendar: true
---

- [ ] Task
''';
      final project = MarkdownParser.parse(content, '/tmp/test.md');

      expect(project.title, 'My Project');
      expect(project.created, DateTime(2026, 3, 14));
      expect(project.dday, DateTime(2026, 6, 15));
      expect(project.color, '#FF6B35');
      expect(project.bgColor, '#1E88E5');
      expect(project.description, 'A sample project');
      expect(project.syncWithCalendar, true);
    });

    test('ignores lines that are not checkboxes', () {
      const content = '''
# Header

Some paragraph text.

- [ ] Task 1

A blank line above.

- [x] Task 2

1. Numbered list item
- Just a bullet
''';
      final project = MarkdownParser.parse(content, '/tmp/test.md');

      expect(project.todos.length, 2);
    });

    test('preserves body markdown structure', () {
      const content = '# Notes\n\nSome text.\n\n- [ ] Task\n\nMore text.';
      final project = MarkdownParser.parse(content, '/tmp/test.md');

      expect(project.bodyMarkdown, contains('# Notes'));
      expect(project.bodyMarkdown, contains('Some text.'));
      expect(project.bodyMarkdown, contains('More text.'));
    });

    test('serialize round-trips simple content', () {
      const content = '- [ ] Buy milk\n- [x] Pay rent';
      final parsed = MarkdownParser.parse(content, '/tmp/tasks.md');
      final serialized = MarkdownParser.serialize(parsed);
      final reparsed = MarkdownParser.parse(serialized, '/tmp/tasks.md');

      expect(reparsed.todos.length, 2);
      expect(reparsed.todos[0].title, 'Buy milk');
      expect(reparsed.todos[0].isCompleted, false);
      expect(reparsed.todos[1].title, 'Pay rent');
      expect(reparsed.todos[1].isCompleted, true);
    });

    test('stripMetadata removes HTML comments', () {
      final line = '- [ ] Task <!-- {"id":"abc"} -->';
      final stripped = MarkdownParser.stripMetadata(line);
      expect(stripped, '- [ ] Task');
    });

    test('stripMetadata handles line without metadata', () {
      final line = '- [ ] Plain task';
      final stripped = MarkdownParser.stripMetadata(line);
      expect(stripped, '- [ ] Plain task');
    });

    test('handles only frontmatter with no body', () {
      const content = '---\ntitle: Empty\ncreated: 2026-01-01\n---';
      final project = MarkdownParser.parse(content, '/tmp/empty.md');

      expect(project.title, 'Empty');
      expect(project.todos, isEmpty);
    });

    test('handles completely empty content', () {
      final project = MarkdownParser.parse('', '/tmp/empty.md');

      expect(project.title, 'empty');
      expect(project.todos, isEmpty);
    });

    test('parses inline metadata JSON with all fields', () {
      const content = '- [ ] Task <!-- {"id":"custom-1","alarm":"2026-06-15T09:00:00.000","syncCalendar":false,"reminder":"30m","recurrence":{"frequency":"weekly"},"sortOrder":5} -->';
      final project = MarkdownParser.parse(content, '/tmp/test.md');
      final todo = project.todos.single;

      expect(todo.id, 'custom-1');
      expect(todo.alarm, DateTime(2026, 6, 15, 9, 0));
      expect(todo.syncToCalendar, false);
      expect(todo.reminderBefore, const Duration(minutes: 30));
      expect(todo.recurrence?.frequency, RecurrenceFrequency.weekly);
      expect(todo.sortOrder, 5);
    });

    test('gracefully handles malformed metadata JSON', () {
      const content = '- [ ] Task <!-- {bad json} -->';
      final project = MarkdownParser.parse(content, '/tmp/test.md');

      expect(project.todos.single.title, 'Task');
      expect(project.todos.single.id, isNotEmpty);
    });

    test('handles indented checkboxes', () {
      const content = '  - [ ] Indented\n    - [x] Deep';
      final project = MarkdownParser.parse(content, '/tmp/test.md');

      expect(project.todos.length, 2);
      expect(project.todos[0].title, 'Indented');
      expect(project.todos[1].title, 'Deep');
    });

    test('handles various checkbox formats [x] [X] [ ]', () {
      const content = '- [x] lowercase\n- [X] uppercase\n- [ ] unchecked';
      final project = MarkdownParser.parse(content, '/tmp/test.md');

      expect(project.todos[0].isCompleted, true);
      expect(project.todos[1].isCompleted, true);
      expect(project.todos[2].isCompleted, false);
    });

    test('serializes project with no frontmatter back correctly', () {
      const content = '- [ ] Task';
      final parsed = MarkdownParser.parse(content, '/tmp/test.md');
      final serialized = MarkdownParser.serialize(parsed);

      expect(serialized, contains('- [ ] Task'));
    });
  });
}
