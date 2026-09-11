import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _baseTime = DateTime.utc(2026, 1, 1);

PosePoint _point(
  double x,
  double y, {
  double confidence = 0.9,
}) =>
    PosePoint(
      x: x,
      y: y,
      confidence: confidence,
    );

BodyPose _pose(
  Map<BodyJoint, PosePoint> joints, {
  DateTime? timestamp,
}) =>
    BodyPose(
      joints: joints,
      timestamp: timestamp ?? _baseTime,
      confidence: 0.9,
    );

Map<BodyJoint, PosePoint> _fullBodyJoints({
  double shoulderCenterX = 0.5,
  double hipCenterX = 0.5,
  double hipY = 0.5,
  double confidence = 0.9,
}) {
  final leftShoulderX = shoulderCenterX - 0.1;
  final rightShoulderX = shoulderCenterX + 0.1;
  final leftHipX = hipCenterX - 0.1;
  final rightHipX = hipCenterX + 0.1;

  return {
    BodyJoint.leftShoulder: _point(leftShoulderX, 0.2, confidence: confidence),
    BodyJoint.rightShoulder: _point(rightShoulderX, 0.2, confidence: confidence),
    BodyJoint.leftElbow: _point(leftShoulderX, 0.4, confidence: confidence),
    BodyJoint.rightElbow: _point(rightShoulderX, 0.4, confidence: confidence),
    BodyJoint.leftWrist: _point(leftShoulderX, 0.6, confidence: confidence),
    BodyJoint.rightWrist: _point(rightShoulderX, 0.6, confidence: confidence),
    BodyJoint.leftHip: _point(leftHipX, hipY, confidence: confidence),
    BodyJoint.rightHip: _point(rightHipX, hipY, confidence: confidence),
    BodyJoint.leftKnee: _point(leftHipX, hipY + 0.25, confidence: confidence),
    BodyJoint.rightKnee: _point(rightHipX, hipY + 0.25, confidence: confidence),
    BodyJoint.leftAnkle: _point(leftHipX, hipY + 0.5, confidence: confidence),
    BodyJoint.rightAnkle: _point(rightHipX, hipY + 0.5, confidence: confidence),
  };
}

void main() {
  const extractor = CanonicalPoseFeatureExtractor();

  group('CanonicalPoseFeatureExtractor angles', () {
    test('extracts independent straight knee angles', () {
      final features = extractor.extract(_pose(_fullBodyJoints()));

      expect(features.leftKneeAngle, closeTo(180, 1e-12));
      expect(features.rightKneeAngle, closeTo(180, 1e-12));
    });

    test('missing joint only makes dependent feature unavailable', () {
      final joints = _fullBodyJoints()..remove(BodyJoint.leftAnkle);
      final features = extractor.extract(_pose(joints));

      expect(features.leftKneeAngle, isNull);
      expect(features.rightKneeAngle, closeTo(180, 1e-12));
    });

    test('extracts straight and bent elbow angles', () {
      final straight = extractor.extract(_pose(_fullBodyJoints()));
      final bentJoints = _fullBodyJoints()
        ..[BodyJoint.leftWrist] = _point(0.6, 0.4);
      final bent = extractor.extract(_pose(bentJoints));

      expect(straight.leftElbowAngle, closeTo(180, 1e-12));
      expect(straight.rightElbowAngle, closeTo(180, 1e-12));
      expect(bent.leftElbowAngle, closeTo(90, 1e-12));
      expect(bent.rightElbowAngle, closeTo(180, 1e-12));
    });

    test('rejects low-confidence landmarks per dependent feature', () {
      final joints = _fullBodyJoints()
        ..[BodyJoint.leftKnee] = _point(0.4, 0.75, confidence: 0.2);
      final features = extractor.extract(_pose(joints));

      expect(features.leftKneeAngle, isNull);
      expect(features.rightKneeAngle, closeTo(180, 1e-12));
      expect(features.shoulderWidth, closeTo(0.2, 1e-12));
    });

    test('degenerate joint geometry stays unavailable instead of NaN', () {
      final joints = _fullBodyJoints()
        ..[BodyJoint.leftKnee] = _point(0.4, 0.5);
      final features = extractor.extract(_pose(joints));

      expect(features.leftKneeAngle, isNull);
      expect(features.rightKneeAngle, closeTo(180, 1e-12));
    });
  });

  group('CanonicalPoseFeatureExtractor torso and scale', () {
    test('uses documented torso inclination sign convention', () {
      final vertical = extractor.extract(_pose(_fullBodyJoints()));
      final leanRight = extractor.extract(
        _pose(_fullBodyJoints(shoulderCenterX: 0.55)),
      );
      final leanLeft = extractor.extract(
        _pose(_fullBodyJoints(shoulderCenterX: 0.45)),
      );

      expect(vertical.torsoInclinationAngle, closeTo(0, 1e-12));
      expect(leanRight.torsoInclinationAngle, greaterThan(0));
      expect(leanLeft.torsoInclinationAngle, lessThan(0));
    });

    test('keeps body geometry in canonical normalized units', () {
      final features = extractor.extract(_pose(_fullBodyJoints()));

      expect(features.shoulderWidth, closeTo(0.2, 1e-12));
      expect(features.hipWidth, closeTo(0.2, 1e-12));
      expect(features.torsoLength, closeTo(0.3, 1e-12));
      expect(features.bodyScale, closeTo(0.3, 1e-12));
      expect(features.normalizedShoulderY, closeTo(0.2, 1e-12));
      expect(features.normalizedHipY, closeTo(0.5, 1e-12));
    });

    test('does not require or accept viewport or mirror metadata', () {
      final features = extractor.extract(_pose(_fullBodyJoints()));

      expect(features.leftKneeAngle, closeTo(180, 1e-12));
      expect(features.torsoInclinationAngle, closeTo(0, 1e-12));
    });
  });

  group('CanonicalPoseFeatureExtractor movement', () {
    test('classifies downward and upward hip-center motion', () {
      final previous = _pose(
        _fullBodyJoints(hipY: 0.4),
        timestamp: _baseTime,
      );
      final down = _pose(
        _fullBodyJoints(hipY: 0.5),
        timestamp: _baseTime.add(const Duration(seconds: 1)),
      );
      final up = _pose(
        _fullBodyJoints(hipY: 0.3),
        timestamp: _baseTime.add(const Duration(seconds: 1)),
      );

      final downFeatures = extractor.extract(down, previousPose: previous);
      final upFeatures = extractor.extract(up, previousPose: previous);

      expect(downFeatures.verticalMovement, PoseMovementDirection.down);
      expect(downFeatures.verticalVelocity, closeTo(0.1, 1e-12));
      expect(upFeatures.verticalMovement, PoseMovementDirection.up);
      expect(upFeatures.verticalVelocity, closeTo(-0.1, 1e-12));
    });

    test('uses a dead zone for tiny hip-center jitter', () {
      final previous = _pose(
        _fullBodyJoints(hipY: 0.4),
        timestamp: _baseTime,
      );
      final current = _pose(
        _fullBodyJoints(hipY: 0.42),
        timestamp: _baseTime.add(const Duration(seconds: 1)),
      );
      final features = extractor.extract(current, previousPose: previous);

      expect(features.verticalMovement, PoseMovementDirection.stable);
      expect(features.verticalVelocity, closeTo(0.02, 1e-12));
    });

    test('derives velocity from timestamps, not frame count', () {
      final previous = _pose(
        _fullBodyJoints(hipY: 0.4),
        timestamp: _baseTime,
      );
      final fast = extractor.extract(
        _pose(
          _fullBodyJoints(hipY: 0.5),
          timestamp: _baseTime.add(const Duration(seconds: 1)),
        ),
        previousPose: previous,
      );
      final slow = extractor.extract(
        _pose(
          _fullBodyJoints(hipY: 0.5),
          timestamp: _baseTime.add(const Duration(seconds: 2)),
        ),
        previousPose: previous,
      );

      expect(slow.verticalVelocity!.abs(), lessThan(fast.verticalVelocity!.abs()));
    });

    test('returns unknown movement for invalid delta time', () {
      final previous = _pose(
        _fullBodyJoints(hipY: 0.4),
        timestamp: _baseTime,
      );
      final current = _pose(
        _fullBodyJoints(hipY: 0.5),
        timestamp: _baseTime,
      );
      final features = extractor.extract(current, previousPose: previous);

      expect(features.verticalMovement, PoseMovementDirection.unknown);
      expect(features.verticalVelocity, isNull);
    });
  });
}
