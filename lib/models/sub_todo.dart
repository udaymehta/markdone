import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum RecurrenceFrequency { minutely, hourly, daily, weekly, monthly, yearly }

enum ReminderUnit { minutes, hours, days, weeks }

extension ReminderUnitLabel on ReminderUnit {
  String get key => switch (this) {
    ReminderUnit.minutes => 'm',
    ReminderUnit.hours => 'h',
    ReminderUnit.days => 'd',
    ReminderUnit.weeks => 'w',
  };

  String get singularUnit => switch (this) {
    ReminderUnit.minutes => 'minute',
    ReminderUnit.hours => 'hour',
    ReminderUnit.days => 'day',
    ReminderUnit.weeks => 'week',
  };

  String get pluralUnit => switch (this) {
    ReminderUnit.minutes => 'minutes',
    ReminderUnit.hours => 'hours',
    ReminderUnit.days => 'days',
    ReminderUnit.weeks => 'weeks',
  };

  Duration durationFor(int value) {
    return switch (this) {
      ReminderUnit.minutes => Duration(minutes: value),
      ReminderUnit.hours => Duration(hours: value),
      ReminderUnit.days => Duration(days: value),
      ReminderUnit.weeks => Duration(days: value * 7),
    };
  }
}

ReminderUnit? reminderUnitFromKey(String? value) {
  return switch (value?.toLowerCase()) {
    'm' || 'minute' || 'minutes' => ReminderUnit.minutes,
    'h' || 'hour' || 'hours' => ReminderUnit.hours,
    'd' || 'day' || 'days' => ReminderUnit.days,
    'w' || 'week' || 'weeks' => ReminderUnit.weeks,
    _ => null,
  };
}

@immutable
class ReminderConfig {
  final int value;
  final ReminderUnit unit;

  const ReminderConfig({required this.value, required this.unit})
    : assert(value > 0, 'value must be positive');

  Duration get duration => unit.durationFor(value);

  String get compact => '$value${unit.key}';

  String get shortUnit => switch (unit) {
    ReminderUnit.minutes => 'min',
    ReminderUnit.hours => 'hr',
    ReminderUnit.days => value == 1 ? 'day' : 'days',
    ReminderUnit.weeks => value == 1 ? 'wk' : 'wks',
  };

  String get label => '$value $shortUnit';

  static ReminderConfig? fromDuration(Duration? duration) {
    if (duration == null) return null;

    final minutes = duration.inMinutes;
    if (minutes <= 0) return null;

    const minutesPerHour = 60;
    const minutesPerDay = 24 * minutesPerHour;
    const minutesPerWeek = 7 * minutesPerDay;

    if (minutes % minutesPerWeek == 0) {
      return ReminderConfig(
        value: minutes ~/ minutesPerWeek,
        unit: ReminderUnit.weeks,
      );
    }
    if (minutes % minutesPerDay == 0) {
      return ReminderConfig(
        value: minutes ~/ minutesPerDay,
        unit: ReminderUnit.days,
      );
    }
    if (minutes % minutesPerHour == 0) {
      return ReminderConfig(
        value: minutes ~/ minutesPerHour,
        unit: ReminderUnit.hours,
      );
    }

    return ReminderConfig(value: minutes, unit: ReminderUnit.minutes);
  }

  static ReminderConfig? fromString(String? value) {
    if (value == null || value.isEmpty) return null;

    final match = RegExp(r'^(\d+)([a-zA-Z]+)$').firstMatch(value.trim());
    if (match == null) return null;

    final amount = int.tryParse(match.group(1)!);
    final unit = reminderUnitFromKey(match.group(2));
    if (amount == null || amount <= 0 || unit == null) return null;

    return ReminderConfig(value: amount, unit: unit);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderConfig &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

extension RecurrenceFrequencyLabel on RecurrenceFrequency {
  String get key => switch (this) {
    RecurrenceFrequency.minutely => 'minutely',
    RecurrenceFrequency.hourly => 'hourly',
    RecurrenceFrequency.daily => 'daily',
    RecurrenceFrequency.weekly => 'weekly',
    RecurrenceFrequency.monthly => 'monthly',
    RecurrenceFrequency.yearly => 'yearly',
  };

  String get singularUnit => switch (this) {
    RecurrenceFrequency.minutely => 'minute',
    RecurrenceFrequency.hourly => 'hour',
    RecurrenceFrequency.daily => 'day',
    RecurrenceFrequency.weekly => 'week',
    RecurrenceFrequency.monthly => 'month',
    RecurrenceFrequency.yearly => 'year',
  };

  String get pluralUnit => switch (this) {
    RecurrenceFrequency.minutely => 'minutes',
    RecurrenceFrequency.hourly => 'hours',
    RecurrenceFrequency.daily => 'days',
    RecurrenceFrequency.weekly => 'weeks',
    RecurrenceFrequency.monthly => 'months',
    RecurrenceFrequency.yearly => 'years',
  };
}

RecurrenceFrequency? recurrenceFrequencyFromKey(String? value) {
  return switch (value?.toLowerCase()) {
    'minutely' || 'minute' || 'minutes' => RecurrenceFrequency.minutely,
    'hourly' || 'hour' || 'hours' => RecurrenceFrequency.hourly,
    'daily' => RecurrenceFrequency.daily,
    'day' || 'days' => RecurrenceFrequency.daily,
    'weekly' => RecurrenceFrequency.weekly,
    'week' || 'weeks' => RecurrenceFrequency.weekly,
    'monthly' => RecurrenceFrequency.monthly,
    'month' || 'months' => RecurrenceFrequency.monthly,
    'yearly' => RecurrenceFrequency.yearly,
    'year' || 'years' => RecurrenceFrequency.yearly,
    _ => null,
  };
}

@immutable
class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final int interval;
  final int? anchorDay;
  final int? anchorMonth;

  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.anchorDay,
    this.anchorMonth,
  }) : assert(interval > 0, 'interval must be positive');

  factory RecurrenceRule.fromAlarm({
    required RecurrenceFrequency frequency,
    required DateTime alarm,
    int interval = 1,
  }) {
    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      anchorDay: switch (frequency) {
        RecurrenceFrequency.monthly || RecurrenceFrequency.yearly => alarm.day,
        _ => null,
      },
      anchorMonth: switch (frequency) {
        RecurrenceFrequency.yearly => alarm.month,
        _ => null,
      },
    );
  }

  static RecurrenceRule? fromJson(Object? value, {DateTime? fallbackAlarm}) {
    if (value == null) return null;

    if (value is String) {
      final frequency = recurrenceFrequencyFromKey(value);
      if (frequency == null) return null;
      final rule = RecurrenceRule(frequency: frequency);
      return fallbackAlarm != null ? rule.retargetToAlarm(fallbackAlarm) : rule;
    }

    if (value is! Map) return null;

    final frequency = recurrenceFrequencyFromKey(
      value['frequency']?.toString(),
    );
    if (frequency == null) return null;

    final rule = RecurrenceRule(
      frequency: frequency,
      interval: _parsePositiveInt(value['interval']) ?? 1,
      anchorDay: _parsePositiveInt(value['anchorDay']),
      anchorMonth: _parsePositiveInt(value['anchorMonth']),
    );

    return fallbackAlarm != null ? rule.retargetToAlarm(fallbackAlarm) : rule;
  }

  static int? _parsePositiveInt(Object? value) {
    final parsed = switch (value) {
      int number => number,
      String text => int.tryParse(text),
      _ => null,
    };

    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  bool get usesAnchorDay =>
      frequency == RecurrenceFrequency.monthly ||
      frequency == RecurrenceFrequency.yearly;

  bool get usesAnchorMonth => frequency == RecurrenceFrequency.yearly;

  String get label {
    if (interval == 1) {
      return 'Every ${frequency.singularUnit}';
    }
    return 'Every $interval ${frequency.pluralUnit}';
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'frequency': frequency.key};
    if (interval != 1) map['interval'] = interval;
    if (usesAnchorDay && anchorDay != null) map['anchorDay'] = anchorDay;
    if (usesAnchorMonth && anchorMonth != null) {
      map['anchorMonth'] = anchorMonth;
    }
    return map;
  }

  RecurrenceRule retargetToAlarm(DateTime alarm) {
    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      anchorDay: usesAnchorDay ? (anchorDay ?? alarm.day) : null,
      anchorMonth: usesAnchorMonth ? (anchorMonth ?? alarm.month) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRule &&
          runtimeType == other.runtimeType &&
          frequency == other.frequency &&
          interval == other.interval &&
          anchorDay == other.anchorDay &&
          anchorMonth == other.anchorMonth;

  @override
  int get hashCode => Object.hash(frequency, interval, anchorDay, anchorMonth);
}

/// Represents a single sub-todo (checkbox item) within a master project.
///
/// In the `.md` file, a sub-todo looks like:
/// ```
/// - [ ] Buy groceries <!-- {"id":"todo-1","alarm":"2026-03-10T09:00:00","calendarId":"abc123","reminder":"30m","recurrence":{"frequency":"weekly"}} -->
/// - [x] Clean kitchen <!-- {"id":"todo-2","alarm":"2026-03-05T08:00:00"} -->
/// ```
@immutable
class SubTodo {
  static final Uuid _uuid = Uuid();

  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? alarm;
  final bool syncToCalendar;
  final String? calendarEventId;
  final Duration? reminderBefore;
  final RecurrenceRule? recurrence;
  final int lineIndex;
  final int? sortOrder;

  const SubTodo({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.alarm,
    this.syncToCalendar = true,
    this.calendarEventId,
    this.reminderBefore,
    this.recurrence,
    required this.lineIndex,
    this.sortOrder,
  });

  static String generateId() => _uuid.v4();

  static String generateFallbackId({
    required String filePath,
    required int lineIndex,
    required String title,
  }) {
    return _uuid.v5(Namespace.url.value, '$filePath::$lineIndex::$title');
  }

  SubTodo copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? alarm,
    bool? syncToCalendar,
    String? calendarEventId,
    Duration? reminderBefore,
    RecurrenceRule? recurrence,
    int? lineIndex,
    int? sortOrder,
    bool clearAlarm = false,
    bool clearCalendarEventId = false,
    bool clearReminder = false,
    bool clearRecurrence = false,
    bool clearSortOrder = false,
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
      recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
      lineIndex: lineIndex ?? this.lineIndex,
      sortOrder: clearSortOrder ? null : (sortOrder ?? this.sortOrder),
    );
  }

  bool get isRecurring => recurrence != null;

  SubTodo normalizedSchedule() {
    if (alarm == null) {
      if (recurrence == null && reminderBefore == null) return this;
      return copyWith(clearReminder: true, clearRecurrence: true);
    }

    if (recurrence == null) return this;

    final normalizedRule = recurrence!.retargetToAlarm(alarm!);
    if (normalizedRule == recurrence) return this;
    return copyWith(recurrence: normalizedRule);
  }

  /// Converts reminder duration to a short string like "30m", "1h", "1d".
  String? get reminderString {
    return ReminderConfig.fromDuration(reminderBefore)?.compact;
  }

  String? get reminderLabel =>
      ReminderConfig.fromDuration(reminderBefore)?.label;

  /// Parses a reminder string like "30m", "1h", "1d" into a Duration.
  static Duration? parseReminderString(String? value) {
    return ReminderConfig.fromString(value)?.duration;
  }

  /// Builds the hidden HTML comment metadata JSON string.
  Map<String, dynamic> toMetadataMap() {
    final map = <String, dynamic>{'id': id};
    if (alarm != null) map['alarm'] = alarm!.toIso8601String();
    if (!syncToCalendar) map['syncCalendar'] = false;
    if (calendarEventId != null) map['calendarId'] = calendarEventId;
    if (reminderBefore != null) map['reminder'] = reminderString;
    if (recurrence != null) map['recurrence'] = recurrence!.toJson();
    if (sortOrder != null) map['sortOrder'] = sortOrder;
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
          recurrence == other.recurrence &&
          lineIndex == other.lineIndex &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    isCompleted,
    alarm,
    syncToCalendar,
    calendarEventId,
    reminderBefore,
    recurrence,
    lineIndex,
    sortOrder,
  );

  @override
  String toString() =>
      'SubTodo(title: $title, done: $isCompleted, alarm: $alarm, recurrence: $recurrence)';
}
