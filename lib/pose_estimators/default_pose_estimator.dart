import 'package:flutter/foundation.dart';

import '../core/pose/pose.dart';
import 'ml_kit/ml_kit_pose_estimator.dart';
import 'movenet/movenet_pose_estimator.dart';

/// Application composition point for the currently selected pose adapter.
///
/// Camera, pipeline, workout, and UI code depend only on [PoseEstimator].
/// Windows uses MoveNet/ONNX because Google ML Kit's Flutter pose plugin does
/// not provide a Windows implementation. Mobile keeps the existing ML Kit
/// adapter unchanged.
PoseEstimator createDefaultPoseEstimator() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    return MoveNetPoseEstimator();
  }
  return MlKitPoseEstimator();
}
