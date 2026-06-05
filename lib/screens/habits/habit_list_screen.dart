import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        child: const Icon(Icons.add),
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
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              _dayAbbr[date.weekday - 1],
              style: TextStyle(
                fontSize: 7,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1.1,
              ),
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
            onReorder: (oldIndex, newIndex) {
              ref
                  .read(habitListProvider.notifier)
                  .reorderHabits(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final habit = widget.habits[index];
              final streak = habit.currentStreak;
              final color = _parseColor(habit.color);

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
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        habit.name,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(
                                        height: 14,
                                        child: streak > 1
                                            ? Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .local_fire_department,
                                                    size: 12,
                                                    color: color.withValues(
                                                        alpha: 0.6),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '$streak',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: color.withValues(
                                                          alpha: 0.6),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : null,
                                      ),
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

Color _parseColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}
