import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../models/master_project.dart';
import '../models/sub_todo.dart';

/// Parses and serializes `.md` files with YAML frontmatter and
/// inline HTML-comment metadata for sub-todos.
class MarkdownParser {
  // Regex patterns
  static final _frontmatterRegex = RegExp(
    r'^---\s*\n([\s\S]*?)\n---\s*\n?',
    multiLine: true,
  );

  static final _checkboxRegex = RegExp(r'^(\s*)-\s*\[([ xX])\]\s*(.*)$');

  static final _metadataCommentRegex = RegExp(r'<!--\s*(\{.*?\})\s*-->');

  /// Parses a full `.md` file string into a [MasterProject].
  static MasterProject parse(String content, String filePath) {
    // --- Extract frontmatter ---
    String frontmatterRaw = '';
    String body = content;

    final fmMatch = _frontmatterRegex.firstMatch(content);
    if (fmMatch != null) {
      frontmatterRaw = fmMatch.group(1) ?? '';
      body = content.substring(fmMatch.end);
    }

    // Parse YAML
    Map<String, dynamic> frontmatter = {};
    if (frontmatterRaw.isNotEmpty) {
      try {
        final yamlMap = loadYaml(frontmatterRaw);
        if (yamlMap is YamlMap) {
          frontmatter = _yamlMapToMap(yamlMap);
        }
      } catch (_) {
        // If YAML parsing fails, use defaults
      }
    }

    final title =
        frontmatter['title']?.toString() ?? _fileNameFromPath(filePath);
    final created =
        _parseDate(frontmatter['created']?.toString()) ?? DateTime.now();
    final dday = _parseDate(frontmatter['dday']?.toString());
    final color = frontmatter['color']?.toString();
    final bgColor = frontmatter['bg_color']?.toString();
    final description = frontmatter['description']?.toString();
    final syncWithCalendar = frontmatter['sync_calendar'] == true;

    // --- Parse sub-todos from body ---
    final lines = body.split('\n');
    final todos = <SubTodo>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _checkboxRegex.firstMatch(line);
      if (match != null) {
        final checkChar = match.group(2)!;
        final isCompleted = checkChar == 'x' || checkChar == 'X';
        String rawTitle = match.group(3)!.trim();

        // Extract hidden metadata comment
        String? persistentId;
        DateTime? alarm;
        var syncToCalendar = true;
        String? calendarEventId;
        Duration? reminderBefore;
        RecurrenceRule? recurrence;
        int? sortOrder;

        final metaMatch = _metadataCommentRegex.firstMatch(rawTitle);
        if (metaMatch != null) {
          // Remove the comment from the display title
          rawTitle = rawTitle.replaceAll(_metadataCommentRegex, '').trim();
          try {
            final metaJson =
                jsonDecode(metaMatch.group(1)!) as Map<String, dynamic>;
            if (metaJson['id'] != null) {
              persistentId = metaJson['id'].toString();
            }
            if (metaJson['alarm'] != null) {
              alarm = DateTime.tryParse(metaJson['alarm'].toString());
            }
            if (metaJson['syncCalendar'] != null) {
              syncToCalendar = metaJson['syncCalendar'] == true;
            }
            if (metaJson['calendarId'] != null) {
              calendarEventId = metaJson['calendarId'].toString();
            }
            if (metaJson['reminder'] != null) {
              reminderBefore = SubTodo.parseReminderString(
                metaJson['reminder'].toString(),
              );
            }
            recurrence = RecurrenceRule.fromJson(
              metaJson['recurrence'],
              fallbackAlarm: alarm,
            );
            if (metaJson['sortOrder'] is int) {
              sortOrder = metaJson['sortOrder'] as int;
            }
          } catch (_) {
            // Ignore malformed metadata
          }
        }

        final id =
            persistentId ??
            SubTodo.generateFallbackId(
              filePath: filePath,
              lineIndex: i,
              title: rawTitle,
            );
        todos.add(
          SubTodo(
            id: id,
            title: rawTitle,
            isCompleted: isCompleted,
            alarm: alarm,
            syncToCalendar: syncToCalendar,
            calendarEventId: calendarEventId,
            reminderBefore: reminderBefore,
            recurrence: recurrence,
            lineIndex: i,
            sortOrder: sortOrder,
          ).normalizedSchedule(),
        );
      }
    }

    return MasterProject(
      filePath: filePath,
      title: title,
      created: created,
      dday: dday,
      color: color,
      bgColor: bgColor,
      description: description,
      syncWithCalendar: syncWithCalendar,
      todos: todos,
      bodyMarkdown: body,
    );
  }

  /// Serializes a [MasterProject] back to a `.md` file string.
  static String serialize(MasterProject project) {
    final buffer = StringBuffer();

    // --- Write frontmatter ---
    buffer.writeln('---');
    final fm = project.toFrontmatterMap();
    for (final entry in fm.entries) {
      if (entry.value is String &&
          (entry.value.toString().contains(':') ||
              entry.value.toString().contains('#'))) {
        buffer.writeln('${entry.key}: "${entry.value}"');
      } else {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
    }
    buffer.writeln('---');
    buffer.writeln();

    final preservedBody = _serializeBody(project);
    if (preservedBody.isNotEmpty) {
      buffer.write(preservedBody);
      if (!preservedBody.endsWith('\n')) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  static String _serializeBody(MasterProject project) {
    if (project.bodyMarkdown.trim().isEmpty) {
      return _serializeFreshBody(project);
    }

    final originalLines = project.bodyMarkdown.split('\n');
    final renderedLines = <String>[];
    var todoIndex = 0;

    for (final line in originalLines) {
      final match = _checkboxRegex.firstMatch(line);
      if (match != null) {
        if (todoIndex < project.todos.length) {
          renderedLines.add(
            _renderTodoLine(
              project.todos[todoIndex],
              indent: match.group(1) ?? '',
            ),
          );
          todoIndex++;
        }
        continue;
      }

      renderedLines.add(line);
    }

    if (todoIndex < project.todos.length) {
      if (renderedLines.isNotEmpty && renderedLines.last.trim().isNotEmpty) {
        renderedLines.add('');
      }
      for (final todo in project.todos.skip(todoIndex)) {
        renderedLines.add(_renderTodoLine(todo));
      }
    }

    return renderedLines.join('\n');
  }

  static String _serializeFreshBody(MasterProject project) {
    final lines = <String>[];

    if (project.description != null && project.description!.isNotEmpty) {
      lines.add(project.description!);
      if (project.todos.isNotEmpty) {
        lines.add('');
      }
    }

    for (final todo in project.todos) {
      lines.add(_renderTodoLine(todo));
    }

    return lines.join('\n');
  }

  static String _renderTodoLine(SubTodo todo, {String indent = ''}) {
    final check = todo.isCompleted ? 'x' : ' ';
    final buffer = StringBuffer('$indent- [$check] ${todo.title}');

    final meta = todo.toMetadataMap();
    if (meta.isNotEmpty) {
      buffer.write(' <!-- ${jsonEncode(meta)} -->');
    }

    return buffer.toString();
  }

  /// Strips metadata comments from a line, returning clean display text.
  static String stripMetadata(String line) {
    return line.replaceAll(_metadataCommentRegex, '').trim();
  }

  // --- Private helpers ---

  static Map<String, dynamic> _yamlMapToMap(YamlMap yaml) {
    final map = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      if (entry.value is YamlMap) {
        map[key] = _yamlMapToMap(entry.value as YamlMap);
      } else if (entry.value is YamlList) {
        map[key] = (entry.value as YamlList).toList();
      } else {
        map[key] = entry.value;
      }
    }
    return map;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String _fileNameFromPath(String path) {
    final name = path.split('/').last;
    if (name.endsWith('.md')) return name.substring(0, name.length - 3);
    return name;
  }
}
