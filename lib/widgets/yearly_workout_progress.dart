import 'package:flutter/material.dart';

import '../services/workout_session_analytics.dart';
import 'weekly_workout_feedback.dart';

class YearlyWorkoutProgressCard extends StatelessWidget {
  final YearlyWorkoutSummary summary;

  const YearlyWorkoutProgressCard({
    super.key,
    required this.summary,
  });

  static const _monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = summary.completedWorkouts;
    final workouts = count == 1 ? 'workout' : 'workouts';

    return Container(
      key: const Key('yearly-workout-progress-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insights_outlined,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.yearStart.year} overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.hasActivity
                          ? '$count $workouts • ${formatWorkoutMinutes(summary.activeDuration)}'
                          : 'No completed workouts this year',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (summary.hasPreviousActivity) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Previous year: ${summary.previousCompletedWorkouts} ${summary.previousCompletedWorkouts == 1 ? 'workout' : 'workouts'} • ${formatWorkoutMinutes(summary.previousActiveDuration)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: 14),
          Text(
            'By month',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 4 : 3;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: columns == 4 ? 1.8 : 1.55,
                children: [
                  for (final bucket in summary.months)
                    _MonthBucket(
                      label: _monthLabels[bucket.month - 1],
                      bucket: bucket,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthBucket extends StatelessWidget {
  final String label;
  final MonthlyWorkoutBucket bucket;

  const _MonthBucket({
    required this.label,
    required this.bucket,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('yearly-month-${bucket.month}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: bucket.hasActivity
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            bucket.hasActivity
                ? '${bucket.completedWorkouts} • ${formatWorkoutMinutes(bucket.activeDuration)}'
                : 'No activity',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
