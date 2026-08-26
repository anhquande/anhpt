import 'package:flutter/material.dart';
import '../models/workout.dart';
import 'common.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onOpen;
  final VoidCallback onStart;
  final VoidCallback onFavorite;

  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onOpen,
    required this.onStart,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: IconButton(
          onPressed: onFavorite,
          icon: Icon(
            workout.favorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: workout.favorite ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
        title: Text(
          workout.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${formatDuration(workout.totalDuration)} · '
          '${workout.effectiveStepCount} steps · '
          '${workout.voice.language.toUpperCase()}',
        ),
        trailing: FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start'),
        ),
        onTap: onOpen,
      ),
    );
  }
}

class WorkoutStructure extends StatelessWidget {
  final List<WorkoutNode> nodes;
  final int depth;

  const WorkoutStructure({
    super.key,
    required this.nodes,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: nodes
          .map(
            (node) => _NodeView(
              node: node,
              depth: depth,
            ),
          )
          .toList(),
    );
  }
}

class _NodeView extends StatelessWidget {
  final WorkoutNode node;
  final int depth;

  const _NodeView({
    required this.node,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final indent = depth * 18.0;

    if (node is WorkoutStep) {
      final step = node as WorkoutStep;

      return Padding(
        padding: EdgeInsets.only(left: indent, bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(formatDuration(step.duration)),
            ],
          ),
        ),
      );
    }

    if (node is RepeatGroup) {
      final group = node as RepeatGroup;

      return Padding(
        padding: EdgeInsets.only(left: indent, bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: cs.primary.withValues(alpha: .35),
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.repeat,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Repeat ×${group.repeat}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              WorkoutStructure(
                nodes: group.steps,
                depth: depth + 1,
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
