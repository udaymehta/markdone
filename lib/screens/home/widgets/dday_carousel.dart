import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/master_project.dart';
import '../../../providers/project_providers.dart';

/// A horizontal carousel showing upcoming D-Day events.
class DdayCarousel extends ConsumerWidget {
  const DdayCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ddayProjects = ref.watch(ddayProjectsProvider);

    if (ddayProjects.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: ddayProjects.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _DdayChip(project: ddayProjects[index]);
        },
      ),
    );
  }
}

class _DdayChip extends StatelessWidget {
  final MasterProject project;
  const _DdayChip({required this.project});

  Color get _urgencyColor {
    final days = project.daysUntilDday;
    if (days == null) return AppColors.darkTextSecondary;
    if (days < 0) return AppColors.ddayUrgent;
    if (days <= 3) return AppColors.ddayUrgent;
    if (days <= 14) return AppColors.ddaySoon;
    return AppColors.ddayRelaxed;
  }

  String get _ddayLabel {
    final days = project.daysUntilDday;
    if (days == null) return '';
    if (days == 0) return 'D-DAY';
    if (days > 0) return 'D-$days';
    return 'D+${days.abs()}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _urgencyColor;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _ddayLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            project.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
