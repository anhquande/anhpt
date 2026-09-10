import 'package:flutter/material.dart';

import '../services/workout_personal_bests_analytics.dart';

class WorkoutPersonalBestsCard extends StatelessWidget {
  final WorkoutPersonalBestsSummary summary;

  const WorkoutPersonalBestsCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (!summary.hasRecords) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final longest = summary.longestWorkout!;
    final steps = summary.mostStepsWorkout!;
    final calories = summary.highestCaloriesWorkout;

    return Container(
      key: const Key('workout-personal-bests-card'),
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
            children: [
              Icon(Icons.emoji_events_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                'Personal bests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RecordRow(
            icon: Icons.timer_outlined,
            label: 'Longest',
            value: '${_formatDuration(longest.activeDuration)} · ${longest.workoutName}',
          ),
          const SizedBox(height: 8),
          _RecordRow(
            icon: Icons.checklist_outlined,
            label: 'Most steps',
            value: '${steps.completedSteps} · ${steps.workoutName}',
          ),
          if (calories != null) ...[
            const SizedBox(height: 8),
            _RecordRow(
              icon: Icons.local_fire_department_outlined,
              label: 'Most calories',
              value: '${calories.estimatedCalories} kcal · ${calories.workoutName}',
            ),
          ],
          if (summary.mostCompletedWorkoutName != null) ...[
            const SizedBox(height: 8),
            _RecordRow(
              icon: Icons.repeat_rounded,
              label: 'Most completed',
              value:
                  '${summary.mostCompletedCount}× · ${summary.mostCompletedWorkoutName}',
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60);
    if (minutes == 0) return '${value.inSeconds}s';
    if (seconds == 0) return '${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}

class _RecordRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RecordRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
