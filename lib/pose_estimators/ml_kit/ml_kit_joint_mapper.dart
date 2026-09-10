import 'package:anhpt/core/pose/body_pose.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Maps Google ML Kit landmarks into AnhPT's canonical pose vocabulary.
///
/// Keeping this mapping inside the adapter prevents engine-specific landmark
/// types from leaking into the core pose API.
abstract final class MlKitJointMapper {
  static const Map<PoseLandmarkType, BodyJoint> _canonicalJoints = {
    PoseLandmarkType.nose: BodyJoint.nose,
    PoseLandmarkType.leftEye: BodyJoint.leftEye,
    PoseLandmarkType.rightEye: BodyJoint.rightEye,
    PoseLandmarkType.leftEar: BodyJoint.leftEar,
    PoseLandmarkType.rightEar: BodyJoint.rightEar,
    PoseLandmarkType.leftShoulder: BodyJoint.leftShoulder,
    PoseLandmarkType.rightShoulder: BodyJoint.rightShoulder,
    PoseLandmarkType.leftElbow: BodyJoint.leftElbow,
    PoseLandmarkType.rightElbow: BodyJoint.rightElbow,
    PoseLandmarkType.leftWrist: BodyJoint.leftWrist,
    PoseLandmarkType.rightWrist: BodyJoint.rightWrist,
    PoseLandmarkType.leftHip: BodyJoint.leftHip,
    PoseLandmarkType.rightHip: BodyJoint.rightHip,
    PoseLandmarkType.leftKnee: BodyJoint.leftKnee,
    PoseLandmarkType.rightKnee: BodyJoint.rightKnee,
    PoseLandmarkType.leftAnkle: BodyJoint.leftAnkle,
    PoseLandmarkType.rightAnkle: BodyJoint.rightAnkle,
    PoseLandmarkType.leftHeel: BodyJoint.leftHeel,
    PoseLandmarkType.rightHeel: BodyJoint.rightHeel,
    PoseLandmarkType.leftFootIndex: BodyJoint.leftFootIndex,
    PoseLandmarkType.rightFootIndex: BodyJoint.rightFootIndex,
  };

  static const Set<PoseLandmarkType> _facialLandmarksWithoutReliableDepth = {
    PoseLandmarkType.nose,
    PoseLandmarkType.leftEye,
    PoseLandmarkType.rightEye,
    PoseLandmarkType.leftEar,
    PoseLandmarkType.rightEar,
  };

  static BodyJoint? toBodyJoint(PoseLandmarkType landmarkType) =>
      _canonicalJoints[landmarkType];

  static Set<BodyJoint> get supportedJoints =>
      Set<BodyJoint>.unmodifiable(_canonicalJoints.values);

  /// ML Kit exposes Z for its pose landmarks, but facial Z values are not
  /// considered reliable by the native API and are intentionally omitted.
  static bool supportsReliableDepth(PoseLandmarkType landmarkType) =>
      _canonicalJoints.containsKey(landmarkType) &&
      !_facialLandmarksWithoutReliableDepth.contains(landmarkType);
}
