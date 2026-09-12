import 'package:flutter/material.dart';

import '../core/pose/pose.dart';

/// Small live diagnostic overlay for high-plank analysis.
class PlankAnalysisOverlay extends StatelessWidget {
  const PlankAnalysisOverlay({
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
    final isHolding = analysis.state.id == PlankExerciseStates.holding.id;

    return Semantics(
      label: 'Plank analysis. State $stateLabel.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          key: const ValueKey('plank-analysis-overlay'),
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
                      isHolding
                          ? Icons.check_circle_rounded
                          : Icons.self_improvement_rounded,
                      size: 18,
                      color: isHolding ? colors.primary : colors.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Plank',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: (isHolding
                                ? colors.primaryContainer
                                : colors.tertiaryContainer)
                            .withValues(alpha: .86),
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
                            color: isHolding
                                ? colors.onPrimaryContainer
                                : colors.onTertiaryContainer,
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
