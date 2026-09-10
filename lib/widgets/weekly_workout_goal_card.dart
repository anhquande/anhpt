import 'package:flutter/material.dart';

class WeeklyWorkoutGoalCard extends StatelessWidget {
  final int completedDays;
  final int goalDays;
  final VoidCallback onEdit;

  const WeeklyWorkoutGoalCard({
    super.key,
    required this.completedDays,
    required this.goalDays,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = goalDays <= 0 ? 0.0 : (completedDays / goalDays).clamp(0.0, 1.0);
    final reached = completedDays >= goalDays;
    return Container(
      key: const Key('weekly-workout-goal-card'),
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
              Icon(Icons.flag_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Weekly goal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(
                key: const Key('weekly-workout-goal-edit'),
                tooltip: 'Edit weekly goal',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$completedDays/$goalDays workout days',
            key: const Key('weekly-workout-goal-progress-text'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            key: const Key('weekly-workout-goal-progress'),
            value: progress,
          ),
          const SizedBox(height: 8),
          Text(
            reached
                ? 'Goal reached for this week.'
                : '${goalDays - completedDays} ${goalDays - completedDays == 1 ? 'day' : 'days'} to go.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
