import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/color_utils.dart';
import '../../models/habit.dart';
import '../../providers/habit_providers.dart';
import '../../screens/settings/settings_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';
import 'widgets/mini_heatmap.dart';
import 'widgets/habit_constants.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitListProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Habits', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return _EmptyState();
          }
          return _HabitListView(habits: habits);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addHabit(context, ref),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _addHabit(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HabitFormScreen()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No habits yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to create your first habit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Widget _buildDayHeaders(ThemeData theme) {
  final today = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  final days = List.generate(4, (i) => today.subtract(Duration(days: 3 - i)));

  final dayNumStyle = theme.textTheme.labelSmall?.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    height: 1.2,
  );
  final dayAbbrStyle = theme.textTheme.labelSmall?.copyWith(
    fontSize: 7,
    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
    height: 1.1,
  );

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: days.map((date) {
      return SizedBox(
        width: heatmapCellTotal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${date.day}',
              style: dayNumStyle,
              textAlign: TextAlign.center,
            ),
            Text(
              _dayAbbr[date.weekday - 1],
              style: dayAbbrStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }).toList(),
  );
}

class _HabitListView extends ConsumerStatefulWidget {
  final List<Habit> habits;
  const _HabitListView({required this.habits});

  @override
  ConsumerState<_HabitListView> createState() => _HabitListViewState();
}

class _HabitListViewState extends ConsumerState<_HabitListView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Habit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildDayHeaders(theme),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: widget.habits.length,
            onReorderItem: (oldIndex, newIndex) {
              ref
                  .read(habitListProvider.notifier)
                  .reorderHabits(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final habit = widget.habits[index];
              final streak = habit.currentStreak;
              final color = parseHexColor(habit.color);
              final goal = habit.goal;
              final fill = goal > 0 ? (streak / goal).clamp(0.0, 1.0) : 1.0;

              return Material(
                key: ValueKey(habit.id),
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HabitDetailScreen(habit: habit),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 4,
                                  height: 42,
                                  child: CustomPaint(
                                    painter: _ProgressBarPainter(
                                      color: color,
                                      fill: fill,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          habit.name,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (streak > 1) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.local_fire_department,
                                          size: 14,
                                          color: color.withValues(alpha: 0.7),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$streak',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: color.withValues(
                                                  alpha: 0.7,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        MiniHeatmap(habit: habit),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final Color color;
  final double fill;

  _ProgressBarPainter({required this.color, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;

    final r = 2.5;

    final bgRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(r),
    );
    canvas.drawRRect(bgRRect, bgPaint);

    if (fill > 0) {
      final fillHeight = size.height * fill;
      final fillRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight),
        Radius.circular(r),
      );
      canvas.drawRRect(fillRRect, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_ProgressBarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fill != fill;
}
