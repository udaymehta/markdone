import 'package:intl/intl.dart';

/// The three supported date display styles.
enum DateFormatStyle {
  /// 03/16/2026
  mmddyyyy,

  /// 16/03/2026
  ddmmyyyy,

  /// Mar 16th, 2026  (named month with ordinal day)
  named,
}

class MarkdoneDateFormatter {
  const MarkdoneDateFormatter._();

  /// The current display style. Set once from `app.dart` on each build.
  static DateFormatStyle style = DateFormatStyle.mmddyyyy;

  // ── Named-style helpers ──
  static final DateFormat _shortMonth = DateFormat('MMM');
  static final DateFormat _longWeekday = DateFormat('EEEE');
  static final DateFormat _time = DateFormat('h:mm a');

  // ── Public API ──

  /// Compact date: "03/16/2026" | "16/03/2026" | "Mar 16th, 2026"
  static String formatDate(DateTime date) {
    return switch (style) {
      DateFormatStyle.mmddyyyy => _pad(date.month, date.day, date.year),
      DateFormatStyle.ddmmyyyy => _pad2(date.day, date.month, date.year),
      DateFormatStyle.named =>
        '${_shortMonth.format(date)} ${_ordinalDay(date.day)}, ${date.year}',
    };
  }

  /// Full date + time: "03/16/2026, 9:00 AM" | "Mar 16th, 2026 at 9:00 AM"
  static String formatDateTime(DateTime date) {
    final t = _time.format(date);
    return switch (style) {
      DateFormatStyle.mmddyyyy => '${formatDate(date)}, $t',
      DateFormatStyle.ddmmyyyy => '${formatDate(date)}, $t',
      DateFormatStyle.named => '${formatDate(date)} at $t',
    };
  }

  /// Short date + time (omits year if current year):
  /// "03/16, 9:00 AM" | "Mar 16, 9:00 AM"
  static String formatDateTimeShort(DateTime date) {
    final now = DateTime.now();
    final t = _time.format(date);
    final sameYear = date.year == now.year;

    return switch (style) {
      DateFormatStyle.mmddyyyy =>
        sameYear
            ? '${_z(date.month)}/${_z(date.day)}, $t'
            : '${_pad(date.month, date.day, date.year)}, $t',
      DateFormatStyle.ddmmyyyy =>
        sameYear
            ? '${_z(date.day)}/${_z(date.month)}, $t'
            : '${_pad2(date.day, date.month, date.year)}, $t',
      DateFormatStyle.named =>
        sameYear
            ? '${_shortMonth.format(date)} ${date.day}, $t'
            : '${_shortMonth.format(date)} ${date.day}, ${date.year}, $t',
    };
  }

  /// Long date with weekday: "Monday, 03/16/2026" | "Monday, Mar 16th, 2026"
  static String formatLongDate(DateTime date) {
    final weekday = _longWeekday.format(date);
    return '$weekday, ${formatDate(date)}';
  }

  // ── Private helpers ──

  /// Zero-pad to 2 digits.
  static String _z(int n) => n.toString().padLeft(2, '0');

  /// MM/DD/YYYY
  static String _pad(int month, int day, int year) =>
      '${_z(month)}/${_z(day)}/$year';

  /// DD/MM/YYYY
  static String _pad2(int day, int month, int year) =>
      '${_z(day)}/${_z(month)}/$year';

  static String _ordinalDay(int day) {
    final mod100 = day % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${day}th';
    }

    final suffix = switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };

    return '$day$suffix';
  }
}
