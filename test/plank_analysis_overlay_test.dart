import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/widgets/plank_analysis_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows plank state', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: PlankExerciseAnalyzer.id,
      state: PlankExerciseStates.holding,
      timestamp: DateTime(2026, 9, 12, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: PlankAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('plank-analysis-overlay')), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(find.text('HOLDING'), findsOneWidget);
  });

  testWidgets('shows active feedback message', (tester) async {
    final timestamp = DateTime(2026, 9, 12, 9);
    final analysis = ExerciseAnalysis(
      exerciseId: PlankExerciseAnalyzer.id,
      state: PlankExerciseStates.broken,
      timestamp: timestamp,
      feedback: [
        ExerciseFeedback(
          code: 'plank_body_not_aligned',
          message: 'Keep shoulders and hips in one straight plank line.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: timestamp,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: PlankAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(
      find.text('Keep shoulders and hips in one straight plank line.'),
      findsOneWidget,
    );
  });
}
