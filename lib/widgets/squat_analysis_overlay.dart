import 'package:flutter/material.dart';

import '../core/pose/pose.dart';

/// Small live diagnostic overlay for the first squat analyzer integration.
class SquatAnalysisOverlay extends StatelessWidget {
  const SquatAnalysisOverlay({
    super.key,
    required this.analysis,
  });

  final ExerciseAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final stateLabel = analysis.state.label ?? analysis.state.id;
    final feedback = _activeFeedbackMessage(analysis);

    return Semantics(
      label: 'Squat analysis. ${analysis.repetitionCount} repetitions. '
          'State $stateLabel.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          key: const ValueKey('squat-analysis-overlay'),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Squats ${analysis.repetitionCount}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: .86),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          stateLabel.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (feedback != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    feedback,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _activeFeedbackMessage(ExerciseAnalysis analysis) {
    for (final item in analysis.feedback) {
      if (item.isActive) return item.message;
    }
    return null;
  }
}
