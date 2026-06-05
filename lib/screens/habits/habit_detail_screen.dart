import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/habit.dart';
import '../../providers/habit_providers.dart';
import 'habit_form_screen.dart';
import 'widgets/full_heatmap.dart';

class HabitDetailScreen extends ConsumerWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final liveHabit = habitsAsync.asData?.value.firstWhere(
          (h) => h.id == habit.id,
          orElse: () => habit,
        ) ??
        habit;

    final theme = Theme.of(context);
    final color = _parseColor(liveHabit.color);

    return Scaffold(
      appBar: AppBar(
        title: Text(liveHabit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editHabit(context, ref, liveHabit),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteHabit(context, ref, liveHabit),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatCard(
                  label: 'Current Streak',
                  value: '${liveHabit.currentStreak} days',
                  icon: Icons.local_fire_department,
                  color: liveHabit.currentStreak > 0 ? color : color.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Longest Streak',
                  value: '${liveHabit.longestStreak} days',
                  icon: Icons.trending_up,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  label: 'Total Days',
                  value: '${liveHabit.totalCompletions}',
                  icon: Icons.check_circle_outline,
                  color: color,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'This Year',
                  value: '${_thisYearCompletions(liveHabit)}',
                  icon: Icons.calendar_today,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CompletionRate(habit: liveHabit, accentColor: color),
            const SizedBox(height: 24),
            Text(
              'Heatmap',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Center(child: FullHeatmap(habit: liveHabit)),
            const SizedBox(height: 24),
            Text(
              'Weekly Trend',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _TrendChart(habit: liveHabit, color: color),
            const SizedBox(height: 24),
            Text(
              'Monthly Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _MonthlyBreakdown(habit: liveHabit, color: color),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  int _thisYearCompletions(Habit h) {
    final year = DateTime.now().year;
    return h.completedDates.where((d) => d.year == year).length;
  }

  void _editHabit(BuildContext context, WidgetRef ref, Habit liveHabit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HabitFormScreen(habit: liveHabit),
      ),
    );
  }

  Future<void> _deleteHabit(
    BuildContext context,
    WidgetRef ref,
    Habit liveHabit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text('Delete "${liveHabit.name}" and all its data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(habitListProvider.notifier).deleteHabit(liveHabit.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// --- Stat card ---

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary.withValues(alpha: 0.5);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Completion rate bars ---

class _CompletionRate extends StatelessWidget {
  final Habit habit;
  final Color accentColor;
  const _CompletionRate({required this.habit, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periods = [
      ('Last 7 days', 7),
      ('Last 30 days', 30),
      ('Last 90 days', 90),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completion Rate',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ...periods.map((p) {
            final rate = habit.completionRate(p.$2);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(p.$1, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate,
                        minHeight: 8,
                        backgroundColor: accentColor.withValues(alpha: 0.15),
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(rate * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// --- Line chart for habit trend ---

class _TrendChart extends StatelessWidget {
  final Habit habit;
  final Color color;
  const _TrendChart({required this.habit, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breakdown = habit.weeklyBreakdown;
    if (breakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          'No previous data yet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = math.max(
      1,
      sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LineChartPainter(
            data: sorted,
            maxVal: maxVal,
            color: color,
            isDark: theme.brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> data;
  final int maxVal;
  final Color color;
  final bool isDark;

  _LineChartPainter({
    required this.data,
    required this.maxVal,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = 8.0;
    final right = size.width - 8;
    if (right <= left) return;
    final top = 8.0;
    final bottom = size.height - 18;
    final chartW = right - left;
    final chartH = bottom - top;
    if (chartH <= 0 || chartW <= 0) return;

    // Grid lines
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + chartH * i / 3;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    if (data.isEmpty) return;

    // Points
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = left + (data.length > 1 ? chartW * i / (data.length - 1) : chartW / 2);
      final y = bottom - (data[i].value / maxVal) * chartH;
      points.add(Offset(x, y));
    }

    if (data.length > 1) {
      // Fill gradient
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(left, top, chartW, chartH));
      final fillPath = Path()..moveTo(points.first.dx, bottom);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, bottom);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);

      // Line
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = color);
      canvas.drawCircle(p, 2, Paint()..color = Colors.white);
    }

    // Labels
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark
          ? Colors.white.withValues(alpha: 0.4)
          : Colors.black.withValues(alpha: 0.35),
    );
    for (var i = 0; i < data.length; i++) {
      final parts = data[i].key.split('-W');
      final weekNum = parts.length > 1 ? parts[1] : '';
      final year = parts[0];
      final label = 'W$weekNum \'${year.substring(2)}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (points[i].dx - tp.width / 2).clamp(left, right - tp.width);
      tp.paint(canvas, Offset(x, bottom + 4));
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      data != old.data || color != old.color || isDark != old.isDark;
}

// --- Monthly breakdown bars ---

class _MonthlyBreakdown extends StatelessWidget {
  final Habit habit;
  final Color color;
  const _MonthlyBreakdown({required this.habit, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final breakdown = habit.monthlyBreakdown;
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final maxVal = sorted.isEmpty
        ? 1
        : sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    if (sorted.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Text(
          'No data available',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Column(
      children: sorted.take(12).map((entry) {
        final parts = entry.key.split('-');
        final month = int.parse(parts[1]);
        final year = int.parse(parts[0]);
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final fraction = maxVal > 0 ? entry.value / maxVal : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  '${months[month - 1]} $year',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 14,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.15),
                    color: color.withValues(alpha: 0.6 + 0.4 * fraction),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '${entry.value}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
