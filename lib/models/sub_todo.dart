import 'package:flutter/foundation.dart';

/// Represents a single sub-todo (checkbox item) within a master project.
///
/// In the `.md` file, a sub-todo looks like:
/// ```
/// - [ ] Buy groceries <!-- {"alarm":"2026-03-10T09:00:00","calendarId":"abc123","reminder":"30m"} -->
/// - [x] Clean kitchen <!-- {"alarm":"2026-03-05T08:00:00"} -->
/// ```
@immutable
class SubTodo {
  final String id; // Generated from content hash + index for stability
  final String title;
  final bool isCompleted;
  final DateTime? alarm;
  final bool syncToCalendar;
  final String? calendarEventId;
  final Duration? reminderBefore;
  final int lineIndex; // Line position in the .md file

  const SubTodo({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.alarm,
    this.syncToCalendar = true,
    this.calendarEventId,
    this.reminderBefore,
    required this.lineIndex,
  });

  SubTodo copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? alarm,
    bool? syncToCalendar,
    String? calendarEventId,
    Duration? reminderBefore,
    int? lineIndex,
    bool clearAlarm = false,
    bool clearCalendarEventId = false,
    bool clearReminder = false,
  }) {
    return SubTodo(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      alarm: clearAlarm ? null : (alarm ?? this.alarm),
      syncToCalendar: syncToCalendar ?? this.syncToCalendar,
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
      reminderBefore: clearReminder
          ? null
          : (reminderBefore ?? this.reminderBefore),
      lineIndex: lineIndex ?? this.lineIndex,
    );
  }

  /// Converts reminder duration to a short string like "30m", "1h", "1d".
  String? get reminderString {
    if (reminderBefore == null) return null;
    final minutes = reminderBefore!.inMinutes;
    if (minutes < 60) return '${minutes}m';
    if (minutes < 1440) return '${minutes ~/ 60}h';
    return '${minutes ~/ 1440}d';
  }

  /// Parses a reminder string like "30m", "1h", "1d" into a Duration.
  static Duration? parseReminderString(String? value) {
    if (value == null || value.isEmpty) return null;
    final num = int.tryParse(value.substring(0, value.length - 1));
    if (num == null) return null;
    final unit = value[value.length - 1];
    switch (unit) {
      case 'm':
        return Duration(minutes: num);
      case 'h':
        return Duration(hours: num);
      case 'd':
        return Duration(days: num);
      default:
        return null;
    }
  }

  /// Builds the hidden HTML comment metadata JSON string.
  Map<String, dynamic> toMetadataMap() {
    final map = <String, dynamic>{};
    if (alarm != null) map['alarm'] = alarm!.toIso8601String();
    if (!syncToCalendar) map['syncCalendar'] = false;
    if (calendarEventId != null) map['calendarId'] = calendarEventId;
    if (reminderBefore != null) map['reminder'] = reminderString;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubTodo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          isCompleted == other.isCompleted &&
          alarm == other.alarm &&
          syncToCalendar == other.syncToCalendar &&
          calendarEventId == other.calendarEventId &&
          reminderBefore == other.reminderBefore &&
          lineIndex == other.lineIndex;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    isCompleted,
    alarm,
    syncToCalendar,
    calendarEventId,
    reminderBefore,
    lineIndex,
  );

  @override
  String toString() =>
      'SubTodo(title: $title, done: $isCompleted, alarm: $alarm)';
}
