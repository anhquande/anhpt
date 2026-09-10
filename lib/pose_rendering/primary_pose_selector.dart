import '../core/pose/body_pose.dart';

typedef PrimaryPoseSelector = BodyPose? Function(Iterable<BodyPose> poses);

/// Selects one pose deterministically without depending on estimator identity.
///
/// The highest aggregate canonical [BodyPose.confidence] wins. Ties preserve
/// estimator order so the policy remains stable and easy to replace later.
BodyPose? selectPrimaryPose(Iterable<BodyPose> poses) {
  BodyPose? selected;
  for (final pose in poses) {
    if (selected == null || pose.confidence > selected.confidence) {
      selected = pose;
    }
  }
  return selected;
}
