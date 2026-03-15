import 'package:flutter/foundation.dart';
import 'sub_todo.dart';

/// Represents a Master Project – one `.md` file.
///
/// The YAML frontmatter stores project-level metadata:
/// ```yaml
/// ---
/// title: My Project
/// created: 2026-01-15
/// dday: 2026-06-01
/// color: "#FF6B35"
/// ---
/// ```
@immutable
class MasterProject {
  final String filePath;
  final String title;
  final DateTime created;
  final DateTime? dday; // D-Day target date
  final String? color; // Hex color override for this project
  final String? bgColor; // Hex+alpha background tint for project page
  final String? description; // Optional description from frontmatter
  final List<SubTodo> todos;
  final String bodyMarkdown; // Raw body (non-frontmatter) content
  final bool syncWithCalendar; // Whether to sync todos with device calendar

  const MasterProject({
    required this.filePath,
    required this.title,
    required this.created,
    this.dday,
    this.color,
    this.bgColor,
    this.description,
    this.todos = const [],
    this.bodyMarkdown = '',
    this.syncWithCalendar = false,
  });

  MasterProject copyWith({
    String? filePath,
    String? title,
    DateTime? created,
    DateTime? dday,
    String? color,
    String? bgColor,
    String? description,
    List<SubTodo>? todos,
    String? bodyMarkdown,
    bool? syncWithCalendar,
    bool clearDday = false,
    bool clearColor = false,
    bool clearBgColor = false,
    bool clearDescription = false,
  }) {
    return MasterProject(
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      created: created ?? this.created,
      dday: clearDday ? null : (dday ?? this.dday),
      color: clearColor ? null : (color ?? this.color),
      bgColor: clearBgColor ? null : (bgColor ?? this.bgColor),
      description: clearDescription ? null : (description ?? this.description),
      todos: todos ?? this.todos,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      syncWithCalendar: syncWithCalendar ?? this.syncWithCalendar,
    );
  }

  /// File name without path and extension.
  String get fileName {
    final name = filePath.split('/').last;
    if (name.endsWith('.md')) return name.substring(0, name.length - 3);
    return name;
  }

  /// Progress as a fraction (0.0 – 1.0).
  double get progress {
    if (todos.isEmpty) return 0.0;
    final done = todos.where((t) => t.isCompleted).length;
    return done / todos.length;
  }

  /// Number of completed todos.
  int get completedCount => todos.where((t) => t.isCompleted).length;

  /// Number of pending todos.
  int get pendingCount => todos.where((t) => !t.isCompleted).length;

  /// Whether all tasks in the project are completed.
  bool get isCompletedProject => todos.isNotEmpty && pendingCount == 0;

  /// Whether this project is stored in the archive folder.
  bool get isArchived => filePath.split('/').contains('archive');

  /// Days until D-Day (negative = past).
  int? get daysUntilDday {
    if (dday == null) return null;
    return dday!.difference(DateTime.now()).inDays;
  }

  /// Whether the D-Day has passed.
  bool get isDdayPast => daysUntilDday != null && daysUntilDday! < 0;

  /// YAML frontmatter map for serialization.
  Map<String, dynamic> toFrontmatterMap() {
    final map = <String, dynamic>{
      'title': title,
      'created': created.toIso8601String().split('T').first,
    };
    if (dday != null) {
      map['dday'] = dday!.toIso8601String().split('T').first;
    }
    if (color != null) map['color'] = color;
    if (bgColor != null) map['bg_color'] = bgColor;
    if (description != null) map['description'] = description;
    if (syncWithCalendar) map['sync_calendar'] = true;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterProject &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          title == other.title &&
          created == other.created &&
          dday == other.dday &&
          color == other.color &&
          bgColor == other.bgColor &&
          description == other.description &&
          syncWithCalendar == other.syncWithCalendar &&
          listEquals(todos, other.todos);

  @override
  int get hashCode => Object.hash(
    filePath,
    title,
    created,
    dday,
    color,
    bgColor,
    description,
    syncWithCalendar,
    Object.hashAll(todos),
  );

  @override
  String toString() =>
      'MasterProject(title: $title, todos: ${todos.length}, progress: ${(progress * 100).toStringAsFixed(0)}%)';
}
