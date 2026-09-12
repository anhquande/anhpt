import 'package:flutter/material.dart';

import '../core/pose/pose.dart';
import 'plank_analysis_overlay.dart';
import 'squat_analysis_overlay.dart';

/// Selects the visual live-analysis overlay for a routed exercise analysis.
///
/// Camera widgets should not need to know every concrete overlay widget. New
/// exercise overlays can be added here while keeping camera layout code stable.
class ExerciseAnalysisOverlay extends StatelessWidget {
  const ExerciseAnalysisOverlay({
    super.key,
    required this.analysis,
  });

  final ExerciseAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final overlay = switch (analysis.exerciseId) {
      SquatExerciseAnalyzer.id => SquatAnalysisOverlay(analysis: analysis),
      PlankExerciseAnalyzer.id => PlankAnalysisOverlay(analysis: analysis),
      _ => null,
    };
    return overlay ?? const SizedBox.shrink();
  }

  static bool supports(ExerciseAnalysis? analysis) => switch (analysis?.exerciseId) {
        SquatExerciseAnalyzer.id || PlankExerciseAnalyzer.id => true,
        _ => false,
      };
}
