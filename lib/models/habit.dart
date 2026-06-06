import 'dart:collection';

class Habit {
  final String id;
  final String name;
  final DateTime createdAt;
  final String color;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String notificationMessage;
  final int sortOrder;
  final int goal;
  final SplayTreeSet<DateTime> _completedDates;

  Habit({
    required this.id,
    required this.name,
    required this.createdAt,
    this.color = '#FF6B35',
    this.reminderEnabled = false,
    this.reminderHour = 0,
    this.reminderMinute = 0,
    this.notificationMessage = 'Did you complete this habit today?',
    this.sortOrder = 0,
    this.goal = 0,
    Iterable<DateTime>? completedDates,
  }) : _completedDates = SplayTreeSet<DateTime>((a, b) => a.compareTo(b))
         ..addAll((completedDates ?? []).map(_normalizeDate));

  static DateTime _normalizeDate(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);

  UnmodifiableSetView<DateTime> get completedDates =>
      UnmodifiableSetView(_completedDates);

  bool isCompletedOn(DateTime date) {
    final normalized = _normalizeDate(date);
    return _completedDates.contains(normalized);
  }

  Habit toggleDate(DateTime date) {
    final normalized = _normalizeDate(date);
    final updated = SplayTreeSet<DateTime>((a, b) => a.compareTo(b))
      ..addAll(_completedDates);
    if (updated.contains(normalized)) {
      updated.remove(normalized);
    } else {
      updated.add(normalized);
    }
    return Habit(
      id: id,
      name: name,
      createdAt: createdAt,
      color: color,
      reminderEnabled: reminderEnabled,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      notificationMessage: notificationMessage,
      sortOrder: sortOrder,
      goal: goal,
      completedDates: updated,
    );
  }

  Habit copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? notificationMessage,
    int? sortOrder,
    int? goal,
    Iterable<DateTime>? completedDates,
    bool clearCompleted = false,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      notificationMessage: notificationMessage ?? this.notificationMessage,
      sortOrder: sortOrder ?? this.sortOrder,
      goal: goal ?? this.goal,
      completedDates: clearCompleted ? [] : (completedDates ?? _completedDates),
    );
  }

  int get currentStreak {
    if (_completedDates.isEmpty) return 0;
    final today = _normalizeDate(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    if (!_completedDates.contains(today) &&
        !_completedDates.contains(yesterday)) {
      return 0;
    }

    var streak = 0;
    final checkDate = _completedDates.contains(today) ? today : yesterday;

    var cursor = checkDate;
    while (_completedDates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get longestStreak {
    if (_completedDates.isEmpty) return 0;
    var longest = 1;
    var current = 1;
    final dates = _completedDates.toList();

    for (var i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  int get totalCompletions => _completedDates.length;

  double completionRate(int days) {
    if (days <= 0) return 0;
    final start = _normalizeDate(
      DateTime.now(),
    ).subtract(Duration(days: days - 1));
    final end = _normalizeDate(DateTime.now());
    var count = 0;
    for (final d in _completedDates) {
      if (d.isAfter(start.subtract(const Duration(days: 1))) &&
          !d.isAfter(end)) {
        count++;
      }
    }
    return count / days;
  }

  Map<String, int> get monthlyBreakdown {
    final breakdown = <String, int>{};
    for (final d in _completedDates) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      breakdown[key] = (breakdown[key] ?? 0) + 1;
    }
    return breakdown;
  }

  Map<String, int> get weeklyBreakdown {
    final breakdown = <String, int>{};
    for (final d in _completedDates) {
      final monday = _weekStart(d);
      final key =
          '${monday.year}-W${_isoWeekNumber(monday).toString().padLeft(2, '0')}';
      breakdown[key] = (breakdown[key] ?? 0) + 1;
    }
    return breakdown;
  }

  static DateTime _weekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static int _isoWeekNumber(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return ((days + firstJan.weekday - 1) / 7).floor() + 1;
  }

  String toCsvRow() {
    final datesStr = _completedDates
        .map((d) => d.toIso8601String().split('T').first)
        .join(';');
    final escapedName = name.replaceAll('|', '\\p');
    final escapedMsg = notificationMessage.replaceAll('|', '\\p');
    return '$id|$escapedName|${createdAt.toIso8601String().split('T').first}|$color|$datesStr|${reminderEnabled ? 1 : 0}|$reminderHour|$reminderMinute|$escapedMsg|$sortOrder|$goal';
  }

  static Habit? fromCsvRow(String line) {
    final parts = line.split('|');
    if (parts.length < 4) return null;
    try {
      final dates = parts.length > 4 && parts[4].isNotEmpty
          ? parts[4]
                .split(';')
                .map((s) => DateTime.tryParse(s.trim()))
                .whereType<DateTime>()
                .toList()
          : <DateTime>[];
      final reminderEnabled = parts.length > 5 ? parts[5] == '1' : false;
      final reminderHour = parts.length > 6 ? int.tryParse(parts[6]) ?? 0 : 0;
      final reminderMinute = parts.length > 7 ? int.tryParse(parts[7]) ?? 0 : 0;
      final notifMsg = parts.length > 8
          ? parts[8].replaceAll('\\p', '|')
          : 'Did you complete this habit today?';
      final sortOrder = parts.length > 9 ? int.tryParse(parts[9]) ?? 0 : 0;
      final goal = parts.length > 10 ? int.tryParse(parts[10]) ?? 0 : 0;
      return Habit(
        id: parts[0],
        name: parts[1].replaceAll('\\p', '|'),
        createdAt: DateTime.parse(parts[2]),
        color: parts[3],
        completedDates: dates,
        reminderEnabled: reminderEnabled,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
        notificationMessage: notifMsg,
        sortOrder: sortOrder,
        goal: goal,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Habit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          color == other.color &&
          createdAt == other.createdAt &&
          _completedDates.length == other._completedDates.length &&
          _completedDates.firstOrNull == other._completedDates.firstOrNull &&
          _completedDates.lastOrNull == other._completedDates.lastOrNull;

  @override
  int get hashCode => Object.hash(id, name, createdAt, color);
}
