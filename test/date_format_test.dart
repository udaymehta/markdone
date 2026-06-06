import 'package:flutter_test/flutter_test.dart';
import 'package:markdone/core/date_formatters.dart';

void main() {
  final fixedDate = DateTime(2026, 6, 15, 14, 30);

  group('DateFormatStyle.mmddyyyy', () {
    final style = DateFormatStyle.mmddyyyy;

    test('formatDate', () {
      expect(
        MarkdoneDateFormatter.formatDate(fixedDate, style),
        '06/15/2026',
      );
    });

    test('formatDateTime', () {
      expect(
        MarkdoneDateFormatter.formatDateTime(fixedDate, style),
        '06/15/2026, 2:30 PM',
      );
    });

    test('formatDateTimeShort same year', () {
      expect(
        MarkdoneDateFormatter.formatDateTimeShort(fixedDate, style),
        '06/15, 2:30 PM',
      );
    });

    test('formatDateTimeShort different year', () {
      final otherYear = DateTime(2025, 6, 15, 14, 30);
      expect(
        MarkdoneDateFormatter.formatDateTimeShort(otherYear, style),
        '06/15/2025, 2:30 PM',
      );
    });

    test('formatLongDate', () {
      expect(
        MarkdoneDateFormatter.formatLongDate(fixedDate, style),
        'Monday, 06/15/2026',
      );
    });
  });

  group('DateFormatStyle.ddmmyyyy', () {
    final style = DateFormatStyle.ddmmyyyy;

    test('formatDate', () {
      expect(
        MarkdoneDateFormatter.formatDate(fixedDate, style),
        '15/06/2026',
      );
    });

    test('formatDateTime', () {
      expect(
        MarkdoneDateFormatter.formatDateTime(fixedDate, style),
        '15/06/2026, 2:30 PM',
      );
    });

    test('formatDateTimeShort same year', () {
      expect(
        MarkdoneDateFormatter.formatDateTimeShort(fixedDate, style),
        '15/06, 2:30 PM',
      );
    });

    test('formatLongDate', () {
      expect(
        MarkdoneDateFormatter.formatLongDate(fixedDate, style),
        'Monday, 15/06/2026',
      );
    });
  });

  group('DateFormatStyle.named', () {
    final style = DateFormatStyle.named;

    test('formatDate', () {
      expect(
        MarkdoneDateFormatter.formatDate(fixedDate, style),
        'Jun 15th, 2026',
      );
    });

    test('formatDateTime', () {
      expect(
        MarkdoneDateFormatter.formatDateTime(fixedDate, style),
        'Jun 15th, 2026 at 2:30 PM',
      );
    });

    test('formatDateTimeShort same year', () {
      expect(
        MarkdoneDateFormatter.formatDateTimeShort(fixedDate, style),
        'Jun 15, 2:30 PM',
      );
    });

    test('formatLongDate', () {
      expect(
        MarkdoneDateFormatter.formatLongDate(fixedDate, style),
        'Monday, Jun 15th, 2026',
      );
    });
  });

  group('Ordinal day formatting', () {
    test('handles teens (11th, 12th, 13th)', () {
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 11), DateFormatStyle.named),
        'Jun 11th, 2026',
      );
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 12), DateFormatStyle.named),
        'Jun 12th, 2026',
      );
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 13), DateFormatStyle.named),
        'Jun 13th, 2026',
      );
    });

    test('handles 1st, 2nd, 3rd', () {
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 1), DateFormatStyle.named),
        'Jun 1st, 2026',
      );
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 2), DateFormatStyle.named),
        'Jun 2nd, 2026',
      );
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 3), DateFormatStyle.named),
        'Jun 3rd, 2026',
      );
    });

    test('handles 21st, 22nd, 23rd', () {
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 21), DateFormatStyle.named),
        'Jun 21st, 2026',
      );
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 22), DateFormatStyle.named),
        'Jun 22nd, 2026',
      );
      expect(
        MarkdoneDateFormatter.formatDate(DateTime(2026, 6, 23), DateFormatStyle.named),
        'Jun 23rd, 2026',
      );
    });
  });
}
