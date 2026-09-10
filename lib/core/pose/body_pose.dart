import 'dart:collection';

/// Canonical anatomical joints used by AnhPT.
///
/// Concrete pose-estimation engines may expose fewer or additional landmarks.
/// Engine adapters are responsible for mapping their output to the canonical
/// joints they support.
enum BodyJoint {
  nose,
  leftEye,
  rightEye,
  leftEar,
  rightEar,
  neck,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// A single canonical body landmark.
///
/// [x] and [y] are expressed in the normalized coordinate space produced by
/// the pose pipeline. Values are intentionally not clamped because a landmark
/// can temporarily fall outside the visible frame. [z] is optional so 2D-only
/// estimators remain first-class implementations.
class PosePoint {
  const PosePoint({
    required this.x,
    required this.y,
    required this.confidence,
    this.z,
  }) : assert(confidence >= 0 && confidence <= 1);

  final double x;
  final double y;
  final double? z;
  final double confidence;

  bool get hasDepth => z != null;
}

/// Engine-independent representation of one detected body pose.
class BodyPose {
  BodyPose({
    required Map<BodyJoint, PosePoint> joints,
    required this.timestamp,
    required this.confidence,
  })  : assert(confidence >= 0 && confidence <= 1),
        joints = UnmodifiableMapView(
          Map<BodyJoint, PosePoint>.from(joints),
        );

  /// Canonical joints available for this pose.
  final Map<BodyJoint, PosePoint> joints;

  /// Capture or estimation timestamp associated with this pose.
  final DateTime timestamp;

  /// Aggregate confidence for the complete pose.
  final double confidence;

  PosePoint? operator [](BodyJoint joint) => joints[joint];

  bool hasJoint(BodyJoint joint) => joints.containsKey(joint);
}
