import 'package:flutter/material.dart';

import '../services/workout_session_analytics.dart';
import 'weekly_workout_feedback.dart';

class MonthlyWorkoutProgressCard extends StatelessWidget {
  final MonthlyWorkoutSummary summary;

  const MonthlyWorkoutProgressCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthLabel = MaterialLocalizations.of(context)
        .formatMonthYear(summary.monthStart);
    final count = summary.completedWorkouts;
    final workouts = count == 1 ? 'workout' : 'workouts';

    return Container(
      key: const Key('monthly-workout-progress-card'),
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
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.hasActivity
                      ? '$count $workouts • ${formatWorkoutMinutes(summary.activeDuration)}'
                      : 'No completed workouts this month',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (summary.hasPreviousActivity) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Previous month: ${summary.previousCompletedWorkouts} ${summary.previousCompletedWorkouts == 1 ? 'workout' : 'workouts'} • ${formatWorkoutMinutes(summary.previousActiveDuration)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ] else if (!summary.hasActivity) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Completed workouts will build your monthly progress here.',
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
