import '../../core/pose/pose.dart';

/// Maps MoveNet SinglePose's 17 canonical output keypoints to AnhPT joints.
class MoveNetPoseMapper {
  MoveNetPoseMapper._();

  static const List<BodyJoint> _jointOrder = [
    BodyJoint.nose,
    BodyJoint.leftEye,
    BodyJoint.rightEye,
    BodyJoint.leftEar,
    BodyJoint.rightEar,
    BodyJoint.leftShoulder,
    BodyJoint.rightShoulder,
    BodyJoint.leftElbow,
    BodyJoint.rightElbow,
    BodyJoint.leftWrist,
    BodyJoint.rightWrist,
    BodyJoint.leftHip,
    BodyJoint.rightHip,
    BodyJoint.leftKnee,
    BodyJoint.rightKnee,
    BodyJoint.leftAnkle,
    BodyJoint.rightAnkle,
  ];

  static final Set<BodyJoint> supportedJoints = _jointOrder.toSet();

  /// Converts flattened `[y, x, score]` MoveNet output into [BodyPose].
  ///
  /// [mapX] and [mapY] map model-normalized coordinates back into the
  /// canonical source-frame coordinate system. This lets preprocessing use
  /// letterboxing without leaking that presentation detail into [BodyPose].
  static BodyPose fromFlatOutput(
    List<double> values, {
    required DateTime timestamp,
    double Function(double value)? mapX,
    double Function(double value)? mapY,
  }) {
    final requiredValues = _jointOrder.length * 3;
    if (values.length < requiredValues) {
      throw ArgumentError.value(
        values.length,
        'values',
        'MoveNet output requires at least $requiredValues values.',
      );
    }

    final xMapper = mapX ?? (value) => value;
    final yMapper = mapY ?? (value) => value;
    final joints = <BodyJoint, PosePoint>{};

    for (var index = 0; index < _jointOrder.length; index++) {
      final offset = index * 3;
      final confidence = values[offset + 2].clamp(0.0, 1.0).toDouble();
      joints[_jointOrder[index]] = PosePoint(
        x: xMapper(values[offset + 1]),
        y: yMapper(values[offset]),
        confidence: confidence,
      );
    }

    final poseConfidence = joints.values.fold<double>(
          0,
          (sum, point) => sum + point.confidence,
        ) /
        joints.length;

    return BodyPose(
      joints: joints,
      timestamp: timestamp,
      confidence: poseConfidence,
    );
  }
}
