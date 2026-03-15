import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date_formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/project_providers.dart';

/// Full-screen page displaying all D-Day events sorted by urgency.
class DdayScreen extends ConsumerWidget {
  const DdayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ddayProjects = ref.watch(ddayProjectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('D-Day Events', style: theme.textTheme.headlineMedium),
      ),
      body: ddayProjects.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 56,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('No D-Day events', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Set a D-Day on a project to track it here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: ddayProjects.length,
              itemBuilder: (context, index) {
                final project = ddayProjects[index];
                final days = project.daysUntilDday!;

                Color urgencyColor;
                if (days < 0) {
                  urgencyColor = AppColors.ddayUrgent;
                } else if (days <= 3) {
                  urgencyColor = AppColors.ddayUrgent;
                } else if (days <= 14) {
                  urgencyColor = AppColors.ddaySoon;
                } else {
                  urgencyColor = AppColors.ddayRelaxed;
                }

                String ddayLabel;
                if (days == 0) {
                  ddayLabel = 'D-DAY';
                } else if (days > 0) {
                  ddayLabel = 'D-$days';
                } else {
                  ddayLabel = 'D+${days.abs()}';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // D-Day badge
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          ddayLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              style: theme.textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              MarkdoneDateFormatter.formatLongDate(
                                project.dday!,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (project.todos.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${project.completedCount}/${project.todos.length}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'tasks done',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
