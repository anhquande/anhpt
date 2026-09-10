import 'package:flutter/material.dart';

import '../services/workout_consistency_analytics.dart';

class WorkoutConsistencyCard extends StatelessWidget {
  final WorkoutConsistencySummary summary;

  const WorkoutConsistencyCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('workout-consistency-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                'Consistency',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                key: const Key('workout-consistency-current-streak'),
                label: 'Current streak',
                value: '${summary.currentStreakDays} d',
              ),
              _Metric(
                key: const Key('workout-consistency-longest-streak'),
                label: 'Best streak',
                value: '${summary.longestStreakDays} d',
              ),
              _Metric(
                key: const Key('workout-consistency-week-days'),
                label: 'This week',
                value: '${summary.workoutDaysThisWeek} d',
              ),
              _Metric(
                key: const Key('workout-consistency-month-days'),
                label: 'This month',
                value: '${summary.workoutDaysThisMonth} d',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
