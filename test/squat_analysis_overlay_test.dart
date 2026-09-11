import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/widgets/squat_analysis_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows squat repetition count and state', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: SquatExerciseAnalyzer.id,
      state: SquatExerciseStates.ascending,
      timestamp: DateTime(2026, 9, 11, 14),
      repetitionCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SquatAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('squat-analysis-overlay')), findsOneWidget);
    expect(find.text('Squats 3'), findsOneWidget);
    expect(find.text('ASCENDING'), findsOneWidget);
  });

  testWidgets('shows active feedback message', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: SquatExerciseAnalyzer.id,
      state: SquatExerciseStates.bottom,
      timestamp: DateTime(2026, 9, 11, 14),
      feedback: [
        ExerciseFeedback(
          code: 'squat_torso_lean',
          message: 'Keep your torso more upright during the squat.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: DateTime(2026, 9, 11, 14),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SquatAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(
      find.text('Keep your torso more upright during the squat.'),
      findsOneWidget,
    );
  });
}
