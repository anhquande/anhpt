import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

final _capabilities = PoseEstimatorCapabilities(
  supportedJoints: BodyJoint.values.toSet(),
);

BodyPose _upperBodyPose(
  DateTime timestamp, {
  Set<BodyJoint>? joints,
  Set<BodyJoint> lowConfidenceJoints = const {},
  double poseConfidence = 0.2,
}) {
  final included =
      joints ?? PoseTrackingRequirements.upperBody().requiredJoints;
  return BodyPose(
    joints: {
      for (final joint in included)
        joint: PosePoint(
          x: 0.5,
          y: 0.5,
          confidence: lowConfidenceJoints.contains(joint) ? 0.2 : 0.9,
        ),
    },
    timestamp: timestamp,
    confidence: poseConfidence,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 22);

  group('PoseTrackingRequirements.upperBody', () {
    test('requires shoulders, elbows and wrists only', () {
      final requirements = PoseTrackingRequirements.upperBody();

      expect(
        requirements.requiredJoints,
        {
          BodyJoint.leftShoulder,
          BodyJoint.rightShoulder,
          BodyJoint.leftElbow,
          BodyJoint.rightElbow,
          BodyJoint.leftWrist,
          BodyJoint.rightWrist,
        },
      );
      expect(requirements.requiredJoints, isNot(contains(BodyJoint.leftHip)));
      expect(requirements.requiredJoints, isNot(contains(BodyJoint.leftKnee)));
      expect(requirements.requiredJoints, isNot(contains(BodyJoint.leftAnkle)));
    });

    test('does not reject a clear upper body because lower body lowers pose score',
        () {
      final evaluator = PoseTrackingEvaluator(
        requirements: PoseTrackingRequirements.upperBody(),
        config: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: Duration.zero,
        ),
      );

      final result = evaluator.evaluate(
        poses: [_upperBodyPose(t0, poseConfidence: 0.2)],
        capabilities: _capabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.tracking);
      expect(result.requiredJointCount, 6);
      expect(result.visibleRequiredJointCount, 6);
      expect(result.missingRequiredJoints, isEmpty);
      expect(result.lowConfidenceJoints, isEmpty);
      expect(result.poseConfidence, 0.2);
    });

    test('still rejects a missing required upper-body joint', () {
      final requirements = PoseTrackingRequirements.upperBody();
      final visible = requirements.requiredJoints
          .where((joint) => joint != BodyJoint.rightWrist)
          .toSet();
      final evaluator = PoseTrackingEvaluator(requirements: requirements);

      final result = evaluator.evaluate(
        poses: [_upperBodyPose(t0, joints: visible)],
        capabilities: _capabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.partialBody);
      expect(result.missingRequiredJoints, {BodyJoint.rightWrist});
      expect(result.visibleRequiredJointCount, 5);
      expect(result.requiredJointCount, 6);
    });

    test('still rejects a low-confidence required upper-body joint', () {
      final evaluator = PoseTrackingEvaluator(
        requirements: PoseTrackingRequirements.upperBody(),
      );

      final result = evaluator.evaluate(
        poses: [
          _upperBodyPose(
            t0,
            lowConfidenceJoints: const {BodyJoint.leftElbow},
          ),
        ],
        capabilities: _capabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.partialBody);
      expect(result.lowConfidenceJoints, {BodyJoint.leftElbow});
    });
  });
}
