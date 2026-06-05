import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/habit.dart';
import '../../../providers/habit_providers.dart';
import 'habit_constants.dart';

Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

bool _isLightColor(Color c) => c.computeLuminance() > 0.5;

class MiniHeatmap extends ConsumerWidget {
  final Habit habit;

  const MiniHeatmap({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _parseColor(habit.color);
    final checkColor = _isLightColor(color) ? Colors.black : Colors.white;

    final today = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final days = List.generate(4, (i) => today.subtract(Duration(days: 3 - i)));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: days.map((date) {
        final isDone = habit.isCompletedOn(date);
        final isFuture = date.isAfter(today);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: heatmapCellGap),
          child: GestureDetector(
            onTap: isFuture
                ? null
                : () {
                    ref
                        .read(habitListProvider.notifier)
                        .toggleDate(habit.id, date);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: heatmapCellSize,
              height: heatmapCellSize,
              decoration: BoxDecoration(
                color: isDone ? color.withValues(alpha: 0.9) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone
                      ? color
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.35)),
                  width: isDone ? 1 : 1.5,
                ),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isDone ? 1.0 : 0.0,
                child: Icon(Icons.check_rounded, color: checkColor, size: 16),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
