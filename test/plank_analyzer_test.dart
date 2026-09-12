import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlankExerciseAnalyzer', () {
    test('returns unknown when required features are unavailable', () {
      const analyzer = PlankExerciseAnalyzer();
      final analysis = analyzer.analyze(
        PoseFeatures(timestamp: DateTime(2026, 1, 1)),
      );

      expect(analysis.exerciseId, PlankExerciseAnalyzer.id);
      expect(analysis.state, PlankExerciseStates.unknown);
      expect(analysis.repetitionCount, 0);
      expect(
        analysis.feedback.map((item) => item.code),
        contains('plank_features_unavailable'),
      );
      expect(
        analysis.events.map((item) => item.code),
        contains('plank_feedback_changed'),
      );
    });

    test('detects a held side-view high plank', () {
      const analyzer = PlankExerciseAnalyzer();
      final analysis = analyzer.analyze(_features());

      expect(analysis.state, PlankExerciseStates.holding);
      expect(analysis.feedback, isEmpty);
      expect(analysis.confidence, greaterThanOrEqualTo(0.8));
    });

    test('emits body alignment feedback when hips drift too far from shoulders', () {
      const analyzer = PlankExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(normalizedHipY: 0.7),
      );

      expect(analysis.state, PlankExerciseStates.broken);
      expect(
        analysis.feedback.map((item) => item.code),
        contains('plank_body_not_aligned'),
      );
    });

    test('emits arm extension feedback when visible elbows are bent', () {
      const analyzer = PlankExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(leftElbowAngle: 120, rightElbowAngle: 122),
      );

      expect(analysis.state, PlankExerciseStates.holding);
      expect(
        analysis.feedback.map((item) => item.code),
        contains('plank_arms_not_extended'),
      );
    });

    test('emits a state change event when form changes', () {
      const analyzer = PlankExerciseAnalyzer();
      final first = analyzer.analyze(_features());
      final second = analyzer.analyze(
        _features(
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
          normalizedHipY: 0.7,
        ),
        previousAnalysis: first,
      );

      expect(first.state, PlankExerciseStates.holding);
      expect(second.state, PlankExerciseStates.broken);
      expect(
        second.events.map((item) => item.code),
        contains('plank_state_changed'),
      );
    });
  });
}

PoseFeatures _features({
  DateTime? timestamp,
  double torsoInclinationAngle = 88,
  double normalizedShoulderY = 0.5,
  double normalizedHipY = 0.54,
  double bodyScale = 0.5,
  double? leftElbowAngle = 170,
  double? rightElbowAngle = 171,
}) =>
    PoseFeatures(
      timestamp: timestamp ?? DateTime(2026, 1, 1),
      torsoInclinationAngle: torsoInclinationAngle,
      normalizedShoulderY: normalizedShoulderY,
      normalizedHipY: normalizedHipY,
      bodyScale: bodyScale,
      leftElbowAngle: leftElbowAngle,
      rightElbowAngle: rightElbowAngle,
    );
