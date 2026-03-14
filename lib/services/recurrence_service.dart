import '../models/sub_todo.dart';

class RecurrenceService {
  const RecurrenceService._();

  static DateTime? nextOccurrence({
    required DateTime alarm,
    required RecurrenceRule rule,
    DateTime? after,
  }) {
    final target = after ?? alarm;
    var candidate = alarm;
    var safety = 0;

    while (!candidate.isAfter(target)) {
      candidate = _advance(candidate, rule);
      safety++;
      if (safety > 1000) {
        throw StateError('Could not compute next recurrence');
      }
    }

    return candidate;
  }

  static DateTime _advance(DateTime current, RecurrenceRule rule) {
    return switch (rule.frequency) {
      RecurrenceFrequency.minutely => current.add(
        Duration(minutes: rule.interval),
      ),
      RecurrenceFrequency.hourly => current.add(Duration(hours: rule.interval)),
      RecurrenceFrequency.daily => current.add(Duration(days: rule.interval)),
      RecurrenceFrequency.weekly => current.add(
        Duration(days: rule.interval * 7),
      ),
      RecurrenceFrequency.monthly => _shiftMonth(
        current,
        monthsToAdd: rule.interval,
        anchorDay: rule.anchorDay ?? current.day,
      ),
      RecurrenceFrequency.yearly => _shiftYear(
        current,
        yearsToAdd: rule.interval,
        anchorMonth: rule.anchorMonth ?? current.month,
        anchorDay: rule.anchorDay ?? current.day,
      ),
    };
  }

  static DateTime _shiftMonth(
    DateTime current, {
    required int monthsToAdd,
    required int anchorDay,
  }) {
    final totalMonths = (current.year * 12) + current.month - 1 + monthsToAdd;
    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;
    final day = _clampDay(year, month, anchorDay);

    return DateTime(
      year,
      month,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  static DateTime _shiftYear(
    DateTime current, {
    required int yearsToAdd,
    required int anchorMonth,
    required int anchorDay,
  }) {
    final year = current.year + yearsToAdd;
    final day = _clampDay(year, anchorMonth, anchorDay);

    return DateTime(
      year,
      anchorMonth,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  static int _clampDay(int year, int month, int desiredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return desiredDay.clamp(1, lastDay);
  }
}
