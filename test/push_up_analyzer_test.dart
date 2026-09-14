import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushUpExerciseAnalyzer', () {
    test('returns unknown when required features are unavailable', () {
      const analyzer = PushUpExerciseAnalyzer();
      final analysis = analyzer.analyze(
        PoseFeatures(timestamp: DateTime(2026, 1, 1)),
      );

      expect(analysis.exerciseId, PushUpExerciseAnalyzer.id);
      expect(analysis.state, PushUpExerciseStates.unknown);
      expect(analysis.repetitionCount, 0);
      expect(
        analysis.feedback.map((item) => item.code),
        contains('push_up_features_unavailable'),
      );
    });

    test('detects extended-arm up position', () {
      const analyzer = PushUpExerciseAnalyzer();
      final analysis = analyzer.analyze(_features(elbowAngle: 170));

      expect(analysis.state, PushUpExerciseStates.up);
      expect(analysis.feedback, isEmpty);
    });

    test('counts a repetition after bottom, ascending, and return to up', () {
      const analyzer = PushUpExerciseAnalyzer();

      final up = analyzer.analyze(_features(elbowAngle: 170));
      final descending = analyzer.analyze(
        _features(
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
          elbowAngle: 130,
        ),
        previousFeatures: _features(elbowAngle: 170),
        previousAnalysis: up,
      );
      final bottom = analyzer.analyze(
        _features(
          timestamp: DateTime(2026, 1, 1, 0, 0, 2),
          elbowAngle: 90,
        ),
        previousFeatures: _features(elbowAngle: 130),
        previousAnalysis: descending,
      );
      final ascending = analyzer.analyze(
        _features(
          timestamp: DateTime(2026, 1, 1, 0, 0, 3),
          elbowAngle: 125,
        ),
        previousFeatures: _features(elbowAngle: 90),
        previousAnalysis: bottom,
      );
      final completed = analyzer.analyze(
        _features(
          timestamp: DateTime(2026, 1, 1, 0, 0, 4),
          elbowAngle: 170,
        ),
        previousFeatures: _features(elbowAngle: 125),
        previousAnalysis: ascending,
      );

      expect(descending.state, PushUpExerciseStates.descending);
      expect(bottom.state, PushUpExerciseStates.bottom);
      expect(ascending.state, PushUpExerciseStates.ascending);
      expect(completed.state, PushUpExerciseStates.up);
      expect(completed.repetitionCount, 1);
      expect(
        completed.events.map((item) => item.code),
        contains('push_up_repetition_completed'),
      );
    });

    test('emits body alignment feedback when hips drift', () {
      const analyzer = PushUpExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(elbowAngle: 170, normalizedHipY: 0.75),
      );

      expect(
        analysis.feedback.map((item) => item.code),
        contains('push_up_body_not_aligned'),
      );
    });

    test('emits elbow asymmetry feedback', () {
      const analyzer = PushUpExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(leftElbowAngle: 170, rightElbowAngle: 130),
      );

      expect(
        analysis.feedback.map((item) => item.code),
        contains('push_up_elbow_asymmetry'),
      );
    });
  });
}

PoseFeatures _features({
  DateTime? timestamp,
  double? elbowAngle,
  double? leftElbowAngle,
  double? rightElbowAngle,
  double torsoInclinationAngle = 88,
  double normalizedShoulderY = 0.5,
  double normalizedHipY = 0.54,
  double bodyScale = 0.5,
}) =>
    PoseFeatures(
      timestamp: timestamp ?? DateTime(2026, 1, 1),
      leftElbowAngle: leftElbowAngle ?? elbowAngle ?? 170,
      rightElbowAngle: rightElbowAngle ?? elbowAngle ?? 170,
      torsoInclinationAngle: torsoInclinationAngle,
      normalizedShoulderY: normalizedShoulderY,
      normalizedHipY: normalizedHipY,
      bodyScale: bodyScale,
    );
