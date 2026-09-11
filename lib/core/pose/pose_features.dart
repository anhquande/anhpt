import 'dart:math' as math;

import 'body_pose.dart';
import 'pose_geometry.dart' as geometry;

/// Generic vertical movement derived from canonical pose geometry.
///
/// Image-space Y normally grows downward, so a positive hip-center velocity is
/// represented as [down] and a negative velocity as [up].
enum PoseMovementDirection { up, down, stable, unknown }

/// Configuration for engine-agnostic pose feature extraction.
class PoseFeatureConfig {
  const PoseFeatureConfig({
    this.minJointConfidence = 0.4,
    this.verticalVelocityEpsilon = 0.05,
    this.minimumBodyScale = 1e-6,
  })  : assert(minJointConfidence >= 0 && minJointConfidence <= 1),
        assert(verticalVelocityEpsilon >= 0),
        assert(minimumBodyScale > 0);

  /// Required confidence for every landmark used by a derived feature.
  final double minJointConfidence;

  /// Dead zone for [PoseFeatures.verticalVelocity], in normalized Y units per
  /// second. Values within +/- this threshold are classified as stable.
  final double verticalVelocityEpsilon;

  /// Smallest scale that is considered reliable for normalized body geometry.
  final double minimumBodyScale;
}

/// Converts a canonical, usually smoothed [BodyPose] into reusable geometry and
/// motion features.
///
/// The extractor accepts only AnhPT pose-domain types. It has no dependency on
/// camera plugins, concrete estimators, view transforms, mirroring, renderers,
/// Flutter widgets, or exercise-specific state machines.
abstract interface class PoseFeatureExtractor {
  PoseFeatures extract(
    BodyPose pose, {
    BodyPose? previousPose,
  });
}

/// Default engine-agnostic feature extractor for canonical AnhPT poses.
class CanonicalPoseFeatureExtractor implements PoseFeatureExtractor {
  const CanonicalPoseFeatureExtractor({
    this.config = const PoseFeatureConfig(),
  });

  final PoseFeatureConfig config;

  @override
  PoseFeatures extract(
    BodyPose pose, {
    BodyPose? previousPose,
  }) {
    final inputs = _FeatureInputs(pose, config);
    final shoulderCenter = inputs.midpoint(
      BodyJoint.leftShoulder,
      BodyJoint.rightShoulder,
    );
    final hipCenter = inputs.midpoint(BodyJoint.leftHip, BodyJoint.rightHip);
    final verticalMotion = _verticalMotion(pose, previousPose);

    return PoseFeatures(
      timestamp: pose.timestamp,
      leftKneeAngle: _angle(
        inputs,
        BodyJoint.leftHip,
        BodyJoint.leftKnee,
        BodyJoint.leftAnkle,
      ),
      rightKneeAngle: _angle(
        inputs,
        BodyJoint.rightHip,
        BodyJoint.rightKnee,
        BodyJoint.rightAnkle,
      ),
      leftHipAngle: _angle(
        inputs,
        BodyJoint.leftShoulder,
        BodyJoint.leftHip,
        BodyJoint.leftKnee,
      ),
      rightHipAngle: _angle(
        inputs,
        BodyJoint.rightShoulder,
        BodyJoint.rightHip,
        BodyJoint.rightKnee,
      ),
      leftElbowAngle: _angle(
        inputs,
        BodyJoint.leftShoulder,
        BodyJoint.leftElbow,
        BodyJoint.leftWrist,
      ),
      rightElbowAngle: _angle(
        inputs,
        BodyJoint.rightShoulder,
        BodyJoint.rightElbow,
        BodyJoint.rightWrist,
      ),
      leftShoulderAngle: _angle(
        inputs,
        BodyJoint.leftHip,
        BodyJoint.leftShoulder,
        BodyJoint.leftElbow,
      ),
      rightShoulderAngle: _angle(
        inputs,
        BodyJoint.rightHip,
        BodyJoint.rightShoulder,
        BodyJoint.rightElbow,
      ),
      torsoInclinationAngle: _torsoInclination(shoulderCenter, hipCenter),
      shoulderWidth: _distance(
        inputs,
        BodyJoint.leftShoulder,
        BodyJoint.rightShoulder,
      ),
      hipWidth: _distance(inputs, BodyJoint.leftHip, BodyJoint.rightHip),
      torsoLength: _torsoLength(shoulderCenter, hipCenter),
      bodyScale: _bodyScale(inputs),
      normalizedShoulderY: shoulderCenter?.y,
      normalizedHipY: hipCenter?.y,
      verticalVelocity: verticalMotion.velocity,
      verticalMovement: verticalMotion.direction,
    );
  }

  double? _angle(
    _FeatureInputs inputs,
    BodyJoint a,
    BodyJoint b,
    BodyJoint c,
  ) {
    final pointA = inputs.joint(a);
    final pointB = inputs.joint(b);
    final pointC = inputs.joint(c);
    if (pointA == null || pointB == null || pointC == null) return null;
    return geometry.angleBetween(pointA, pointB, pointC);
  }

  double? _distance(_FeatureInputs inputs, BodyJoint a, BodyJoint b) {
    final pointA = inputs.joint(a);
    final pointB = inputs.joint(b);
    if (pointA == null || pointB == null) return null;
    final value = geometry.distance(pointA, pointB);
    return value.isFinite ? value : null;
  }

  double? _torsoLength(PosePoint? shoulderCenter, PosePoint? hipCenter) {
    if (shoulderCenter == null || hipCenter == null) return null;
    final value = geometry.distance(shoulderCenter, hipCenter);
    if (!value.isFinite || value <= config.minimumBodyScale) return null;
    return value;
  }

  double? _bodyScale(_FeatureInputs inputs) {
    final value = geometry.bodyScale(
      leftShoulder: inputs.joint(BodyJoint.leftShoulder),
      rightShoulder: inputs.joint(BodyJoint.rightShoulder),
      leftHip: inputs.joint(BodyJoint.leftHip),
      rightHip: inputs.joint(BodyJoint.rightHip),
    );
    if (value == null || !value.isFinite || value <= config.minimumBodyScale) {
      return null;
    }
    return value;
  }

  /// Torso inclination in degrees.
  ///
  /// Convention: `0` means the shoulder center is vertically above the hip
  /// center in canonical normalized pose space. A positive value means the
  /// shoulder center has a larger X coordinate than the hip center. A negative
  /// value means the shoulder center has a smaller X coordinate. Because this
  /// runs before view transforms, preview mirroring must not affect the sign.
  double? _torsoInclination(PosePoint? shoulderCenter, PosePoint? hipCenter) {
    if (shoulderCenter == null || hipCenter == null) return null;
    final torsoLength = _torsoLength(shoulderCenter, hipCenter);
    if (torsoLength == null) return null;

    final angle = math.atan2(
          shoulderCenter.x - hipCenter.x,
          hipCenter.y - shoulderCenter.y,
        ) *
        180 /
        math.pi;
    return angle.isFinite ? angle : null;
  }

  _VerticalMotion _verticalMotion(BodyPose pose, BodyPose? previousPose) {
    if (previousPose == null) return const _VerticalMotion.unknown();

    final currentInputs = _FeatureInputs(pose, config);
    final previousInputs = _FeatureInputs(previousPose, config);
    final currentHip = currentInputs.midpoint(BodyJoint.leftHip, BodyJoint.rightHip);
    final previousHip = previousInputs.midpoint(BodyJoint.leftHip, BodyJoint.rightHip);
    if (currentHip == null || previousHip == null) {
      return const _VerticalMotion.unknown();
    }

    final elapsedMicros = pose.timestamp.difference(previousPose.timestamp).inMicroseconds;
    if (elapsedMicros <= 0) return const _VerticalMotion.unknown();

    final elapsedSeconds = elapsedMicros / Duration.microsecondsPerSecond;
    final velocity = (currentHip.y - previousHip.y) / elapsedSeconds;
    if (!velocity.isFinite) return const _VerticalMotion.unknown();

    final magnitude = velocity.abs();
    if (magnitude <= config.verticalVelocityEpsilon) {
      return _VerticalMotion(
        velocity: velocity,
        direction: PoseMovementDirection.stable,
      );
    }

    return _VerticalMotion(
      velocity: velocity,
      direction: velocity > 0
          ? PoseMovementDirection.down
          : PoseMovementDirection.up,
    );
  }
}

/// Derived presentation-independent geometry for a canonical body pose.
class PoseFeatures {
  const PoseFeatures({
    required this.timestamp,
    this.leftKneeAngle,
    this.rightKneeAngle,
    this.leftHipAngle,
    this.rightHipAngle,
    this.leftElbowAngle,
    this.rightElbowAngle,
    this.leftShoulderAngle,
    this.rightShoulderAngle,
    this.torsoInclinationAngle,
    this.shoulderWidth,
    this.hipWidth,
    this.torsoLength,
    this.bodyScale,
    this.normalizedShoulderY,
    this.normalizedHipY,
    this.verticalVelocity,
    this.verticalMovement = PoseMovementDirection.unknown,
  });

  /// Source pose timestamp for temporal consumers.
  final DateTime timestamp;

  /// Side-specific joint angles in degrees. `180` means straight extension for
  /// knee/elbow synthetic geometry; smaller values indicate more flexion.
  final double? leftKneeAngle;
  final double? rightKneeAngle;
  final double? leftHipAngle;
  final double? rightHipAngle;
  final double? leftElbowAngle;
  final double? rightElbowAngle;

  /// Angle at the shoulder using hip -> shoulder -> elbow geometry.
  final double? leftShoulderAngle;
  final double? rightShoulderAngle;

  /// Torso inclination in degrees, using the convention documented by
  /// [CanonicalPoseFeatureExtractor].
  final double? torsoInclinationAngle;

  /// Normalized distances in canonical pose coordinates, not pixels or cm.
  final double? shoulderWidth;
  final double? hipWidth;
  final double? torsoLength;

  /// Centralized robust body scale for future normalized distance features.
  final double? bodyScale;

  /// Normalized image-space Y positions. Larger values mean lower in the image.
  final double? normalizedShoulderY;
  final double? normalizedHipY;

  /// Hip-center vertical velocity in normalized Y units per second.
  /// Positive is downward because image-space Y grows downward.
  final double? verticalVelocity;

  /// Generic body movement direction derived from [verticalVelocity].
  final PoseMovementDirection verticalMovement;
}

class _FeatureInputs {
  const _FeatureInputs(this.pose, this.config);

  final BodyPose pose;
  final PoseFeatureConfig config;

  PosePoint? joint(BodyJoint joint) {
    final point = pose[joint];
    if (point == null) return null;
    if (point.confidence < config.minJointConfidence) return null;
    if (!point.x.isFinite || !point.y.isFinite) return null;
    final z = point.z;
    if (z != null && !z.isFinite) return null;
    return point;
  }

  PosePoint? midpoint(BodyJoint a, BodyJoint b) =>
      geometry.midpoint(joint(a), joint(b));
}

class _VerticalMotion {
  const _VerticalMotion({
    required this.direction,
    this.velocity,
  });

  const _VerticalMotion.unknown()
      : direction = PoseMovementDirection.unknown,
        velocity = null;

  final PoseMovementDirection direction;
  final double? velocity;
}
