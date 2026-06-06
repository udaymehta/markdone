import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit.dart';
import '../../../providers/habit_providers.dart';

Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class FullHeatmap extends ConsumerStatefulWidget {
  final Habit habit;

  const FullHeatmap({super.key, required this.habit});

  @override
  ConsumerState<FullHeatmap> createState() => _FullHeatmapState();
}

class _FullHeatmapState extends ConsumerState<FullHeatmap> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.utc(DateTime.now().year, DateTime.now().month, 1);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime.utc(
        _currentMonth.year,
        _currentMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime.utc(
        _currentMonth.year,
        _currentMonth.month + 1,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the heatmap rebuilds after a day is toggled
    final habitsAsync = ref.watch(habitListProvider);
    final habits = habitsAsync.asData?.value ?? [];
    final liveHabit = habits.firstWhere(
      (h) => h.id == widget.habit.id,
      orElse: () => widget.habit,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _parseColor(liveHabit.color);
    const cellSize = 32.0;
    const gap = 3.0;

    final today = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday; // 1=Mon ... 7=Sun
    final padBefore = firstWeekday - 1;
    final totalCells = padBefore + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevMonth,
              ),
              Text(
                _monthYearString(_currentMonth),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: _dayAbbr
              .map(
                (l) => SizedBox(
                  width: cellSize + gap,
                  child: Text(
                    l,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid (only current month with padding)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (row) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - padBefore + 1;
                final isPadding = day < 1 || day > daysInMonth;
                final otherMonth = isPadding
                    ? DateTime.utc(
                        _currentMonth.year,
                        _currentMonth.month + (day < 1 ? -1 : 1),
                        day < 1
                            ? DateTime(
                                    _currentMonth.year,
                                    _currentMonth.month,
                                    0,
                                  ).day +
                                  day
                            : day - daysInMonth,
                      )
                    : null;
                final date = isPadding
                    ? otherMonth
                    : DateTime.utc(
                        _currentMonth.year,
                        _currentMonth.month,
                        day,
                      );
                final isToday = !isPadding && date == today;
                final isFuture = date != null && date.isAfter(today);
                final isDone =
                    date != null && !isPadding && liveHabit.isCompletedOn(date);

                return GestureDetector(
                  onTap: (date != null && !isFuture && !isPadding)
                      ? () {
                          ref
                              .read(habitListProvider.notifier)
                              .toggleDate(liveHabit.id, date);
                        }
                      : null,
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    margin: EdgeInsets.all(gap / 2),
                    decoration: BoxDecoration(
                      color: isPadding
                          ? Colors.transparent
                          : (isDone
                                ? color.withValues(alpha: 0.7)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.withValues(alpha: 0.1))),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday && !isDone
                          ? Border.all(
                              color: color.withValues(alpha: 0.5),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        isPadding ? '${date?.day ?? ''}' : '$day',
                        style: TextStyle(
                          fontSize: isPadding ? 10 : 11,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isPadding
                              ? (isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.3))
                              : (isDone
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : Colors.black87)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ],
    );
  }

  String _monthYearString(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
