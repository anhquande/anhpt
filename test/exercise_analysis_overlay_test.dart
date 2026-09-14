import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/widgets/exercise_analysis_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the squat overlay for squat analysis', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: SquatExerciseAnalyzer.id,
      state: SquatExerciseStates.standing,
      timestamp: DateTime(2026, 9, 12, 10),
      repetitionCount: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ExerciseAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('squat-analysis-overlay')), findsOneWidget);
    expect(find.text('Squats 2'), findsOneWidget);
    expect(ExerciseAnalysisOverlay.supports(analysis), isTrue);
  });

  testWidgets('renders the plank overlay for plank analysis', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: PlankExerciseAnalyzer.id,
      state: PlankExerciseStates.holding,
      timestamp: DateTime(2026, 9, 12, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ExerciseAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('plank-analysis-overlay')), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(ExerciseAnalysisOverlay.supports(analysis), isTrue);
  });

  testWidgets('renders the push-up overlay for push-up analysis', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: PushUpExerciseAnalyzer.id,
      state: PushUpExerciseStates.up,
      timestamp: DateTime(2026, 9, 15, 10),
      repetitionCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ExerciseAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('push-up-analysis-overlay')),
      findsOneWidget,
    );
    expect(find.text('Push-ups 3'), findsOneWidget);
    expect(find.text('UP'), findsOneWidget);
    expect(ExerciseAnalysisOverlay.supports(analysis), isTrue);
  });

  testWidgets('renders push-up feedback', (tester) async {
    final timestamp = DateTime(2026, 9, 15, 10);
    final analysis = ExerciseAnalysis(
      exerciseId: PushUpExerciseAnalyzer.id,
      state: PushUpExerciseStates.descending,
      timestamp: timestamp,
      repetitionCount: 1,
      feedback: [
        ExerciseFeedback(
          code: 'push_up_body_not_aligned',
          message: 'Keep shoulders and hips in one straight line.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: timestamp,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ExerciseAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(
      find.text('Keep shoulders and hips in one straight line.'),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing for unsupported analysis', (tester) async {
    final analysis = ExerciseAnalysis(
      exerciseId: 'unknown-exercise',
      state: const ExerciseState(id: 'unknown', label: 'Unknown'),
      timestamp: DateTime(2026, 9, 12, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: ExerciseAnalysisOverlay(analysis: analysis)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('squat-analysis-overlay')), findsNothing);
    expect(find.byKey(const ValueKey('plank-analysis-overlay')), findsNothing);
    expect(
      find.byKey(const ValueKey('push-up-analysis-overlay')),
      findsNothing,
    );
    expect(ExerciseAnalysisOverlay.supports(analysis), isFalse);
    expect(ExerciseAnalysisOverlay.supports(null), isFalse);
  });
}
