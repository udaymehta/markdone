import 'package:intl/intl.dart';

enum DateFormatStyle { mmddyyyy, ddmmyyyy, named }

class MarkdoneDateFormatter {
  const MarkdoneDateFormatter._();

  @Deprecated('Use formatDate with explicit style parameter')
  static DateFormatStyle style = DateFormatStyle.ddmmyyyy;

  static final DateFormat _shortMonth = DateFormat('MMM');
  static final DateFormat _longWeekday = DateFormat('EEEE');
  static final DateFormat _time = DateFormat('h:mm a');

  static String formatDate(DateTime date, [DateFormatStyle? style]) {
    final s = style ?? MarkdoneDateFormatter.style;
    return switch (s) {
      DateFormatStyle.mmddyyyy => _pad(date.month, date.day, date.year),
      DateFormatStyle.ddmmyyyy => _pad2(date.day, date.month, date.year),
      DateFormatStyle.named =>
        '${_shortMonth.format(date)} ${_ordinalDay(date.day)}, ${date.year}',
    };
  }

  static String formatDateTime(DateTime date, [DateFormatStyle? style]) {
    final s = style ?? MarkdoneDateFormatter.style;
    final t = _time.format(date);
    return switch (s) {
      DateFormatStyle.mmddyyyy => '${formatDate(date, s)}, $t',
      DateFormatStyle.ddmmyyyy => '${formatDate(date, s)}, $t',
      DateFormatStyle.named => '${formatDate(date, s)} at $t',
    };
  }

  static String formatDateTimeShort(DateTime date, [DateFormatStyle? style]) {
    final s = style ?? MarkdoneDateFormatter.style;
    final now = DateTime.now();
    final t = _time.format(date);
    final sameYear = date.year == now.year;

    return switch (s) {
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

  static String formatLongDate(DateTime date, [DateFormatStyle? style]) {
    final s = style ?? MarkdoneDateFormatter.style;
    final weekday = _longWeekday.format(date);
    return '$weekday, ${formatDate(date, s)}';
  }

  static String _z(int n) => n.toString().padLeft(2, '0');

  static String _pad(int month, int day, int year) =>
      '${_z(month)}/${_z(day)}/$year';

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
