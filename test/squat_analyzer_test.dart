import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

final _baseTime = DateTime.utc(2026, 1, 1, 12);

PoseFeatures _features({
  int milliseconds = 0,
  double? kneeAngle = 170,
  double? leftKneeAngle,
  double? rightKneeAngle,
  double? hipY = 0.4,
  PoseMovementDirection movement = PoseMovementDirection.stable,
  double? torsoInclinationAngle = 0,
}) =>
    PoseFeatures(
      timestamp: _baseTime.add(Duration(milliseconds: milliseconds)),
      leftKneeAngle: leftKneeAngle ?? kneeAngle,
      rightKneeAngle: rightKneeAngle ?? kneeAngle,
      normalizedHipY: hipY,
      verticalMovement: movement,
      torsoInclinationAngle: torsoInclinationAngle,
    );

void main() {
  group('SquatExerciseAnalyzer', () {
    test('starts in standing when knees are extended', () {
      const analyzer = SquatExerciseAnalyzer();
      final analysis = analyzer.analyze(_features(kneeAngle: 172));

      expect(analysis.exerciseId, SquatExerciseAnalyzer.id);
      expect(analysis.state, SquatExerciseStates.standing);
      expect(analysis.repetitionCount, 0);
      expect(
        analysis.events.map((event) => event.type),
        contains(ExerciseEventType.stateChanged),
      );
    });

    test('reports unavailable feedback when required features are missing', () {
      const analyzer = SquatExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(kneeAngle: null, hipY: null),
      );

      expect(analysis.state, SquatExerciseStates.unknown);
      expect(analysis.confidence, 0.2);
      expect(analysis.feedback.single.code, 'squat_features_unavailable');
    });

    test('counts one full squat after bottom and return to standing', () {
      final controller = ExerciseAnalysisController(
        analyzer: const SquatExerciseAnalyzer(),
      );

      final standing = controller.analyze(
        _features(milliseconds: 0, kneeAngle: 170),
      );
      final descending = controller.analyze(
        _features(
          milliseconds: 100,
          kneeAngle: 140,
          hipY: 0.5,
          movement: PoseMovementDirection.down,
        ),
      );
      final bottom = controller.analyze(
        _features(
          milliseconds: 200,
          kneeAngle: 95,
          hipY: 0.65,
          movement: PoseMovementDirection.down,
        ),
      );
      final ascending = controller.analyze(
        _features(
          milliseconds: 300,
          kneeAngle: 130,
          hipY: 0.55,
          movement: PoseMovementDirection.up,
        ),
      );
      final completed = controller.analyze(
        _features(
          milliseconds: 400,
          kneeAngle: 168,
          hipY: 0.4,
          movement: PoseMovementDirection.up,
        ),
      );

      expect(standing.state, SquatExerciseStates.standing);
      expect(descending.state, SquatExerciseStates.descending);
      expect(bottom.state, SquatExerciseStates.bottom);
      expect(ascending.state, SquatExerciseStates.ascending);
      expect(completed.state, SquatExerciseStates.standing);
      expect(completed.repetitionCount, 1);
      expect(
        completed.events.map((event) => event.type),
        contains(ExerciseEventType.repetitionCompleted),
      );
    });

    test('does not count a half squat that never reaches bottom', () {
      final controller = ExerciseAnalysisController(
        analyzer: const SquatExerciseAnalyzer(),
      );

      controller.analyze(_features(milliseconds: 0, kneeAngle: 170));
      controller.analyze(
        _features(
          milliseconds: 100,
          kneeAngle: 140,
          hipY: 0.5,
          movement: PoseMovementDirection.down,
        ),
      );
      final returned = controller.analyze(
        _features(
          milliseconds: 200,
          kneeAngle: 165,
          hipY: 0.4,
          movement: PoseMovementDirection.up,
        ),
      );

      expect(returned.state, SquatExerciseStates.standing);
      expect(returned.repetitionCount, 0);
      expect(
        returned.events.map((event) => event.type),
        isNot(contains(ExerciseEventType.repetitionCompleted)),
      );
    });

    test('uses knee-angle delta when vertical movement is unavailable', () {
      final controller = ExerciseAnalysisController(
        analyzer: const SquatExerciseAnalyzer(),
      );

      controller.analyze(
        _features(
          milliseconds: 0,
          kneeAngle: 170,
          movement: PoseMovementDirection.unknown,
        ),
      );
      final descending = controller.analyze(
        _features(
          milliseconds: 100,
          kneeAngle: 140,
          movement: PoseMovementDirection.unknown,
        ),
      );
      final bottom = controller.analyze(
        _features(
          milliseconds: 200,
          kneeAngle: 100,
          movement: PoseMovementDirection.unknown,
        ),
      );
      final ascending = controller.analyze(
        _features(
          milliseconds: 300,
          kneeAngle: 130,
          movement: PoseMovementDirection.unknown,
        ),
      );

      expect(descending.state, SquatExerciseStates.descending);
      expect(bottom.state, SquatExerciseStates.bottom);
      expect(ascending.state, SquatExerciseStates.ascending);
    });

    test('emits torso and knee symmetry feedback', () {
      const analyzer = SquatExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(
          leftKneeAngle: 170,
          rightKneeAngle: 140,
          torsoInclinationAngle: 45,
        ),
      );

      expect(
        analysis.feedback.map((feedback) => feedback.code),
        containsAll(['squat_torso_lean', 'squat_knee_asymmetry']),
      );
      expect(
        analysis.events.map((event) => event.type),
        contains(ExerciseEventType.feedbackChanged),
      );
    });

    test('ignores previous analysis for a different exercise', () {
      const analyzer = SquatExerciseAnalyzer();
      final analysis = analyzer.analyze(
        _features(kneeAngle: 170),
        previousAnalysis: ExerciseAnalysis(
          exerciseId: 'push_up',
          state: SquatExerciseStates.ascending,
          timestamp: _baseTime,
          repetitionCount: 12,
        ),
      );

      expect(analysis.state, SquatExerciseStates.standing);
      expect(analysis.repetitionCount, 0);
    });
  });
}
