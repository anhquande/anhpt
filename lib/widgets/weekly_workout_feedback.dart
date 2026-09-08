import 'package:flutter/material.dart';

import '../services/workout_session_analytics.dart';

String formatWorkoutMinutes(Duration duration) {
  if (duration <= Duration.zero) return '0 min';
  final minutes = duration.inMinutes;
  if (minutes == 0) return '<1 min';
  return '$minutes min';
}

String weeklyCompletionContext(WeeklyWorkoutSummary summary) {
  final count = summary.completedWorkouts;
  if (count <= 0) return 'No completed workouts yet this week.';
  final workouts = count == 1 ? 'workout' : 'workouts';
  return '$count $workouts this week — ${formatWorkoutMinutes(summary.activeDuration)} total.';
}

class WeeklyWorkoutFeedbackCard extends StatelessWidget {
  final WeeklyWorkoutSummary summary;

  const WeeklyWorkoutFeedbackCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = summary.completedWorkouts;
    final countLabel = count == 1 ? '1 workout' : '$count workouts';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_view_week_outlined,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This week',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.hasActivity
                      ? '$countLabel • ${formatWorkoutMinutes(summary.activeDuration)}'
                      : 'No completed workouts yet',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (summary.hasPreviousActivity) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last week: ${summary.previousCompletedWorkouts} ${summary.previousCompletedWorkouts == 1 ? 'workout' : 'workouts'} • ${formatWorkoutMinutes(summary.previousActiveDuration)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ] else if (!summary.hasActivity) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Complete a workout to start your weekly activity summary.',
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
    );
  }
}
