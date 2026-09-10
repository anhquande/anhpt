import 'package:flutter/material.dart';

import '../services/workout_milestone_analytics.dart';

class WorkoutMilestonesCard extends StatelessWidget {
  final WorkoutMilestoneSummary summary;

  const WorkoutMilestonesCard({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (!summary.hasActivity) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final next = summary.nextMilestone;

    return Container(
      key: const Key('workout-milestones-card'),
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
              Icon(Icons.military_tech_outlined, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '${summary.unlockedCount}/${summary.totalCount}',
                key: const Key('workout-milestones-count'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (summary.unlockedMilestones.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: summary.unlockedMilestones.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final milestone = summary.unlockedMilestones[index];
                  return Container(
                    key: Key('workout-milestone-${milestone.id.name}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      milestone.title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (next != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next: ${next.title}',
                    key: const Key('workout-next-milestone'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Text(
                  next.progressLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              key: const Key('workout-next-milestone-progress'),
              value: next.progress,
              borderRadius: BorderRadius.circular(999),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'All milestones unlocked',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
