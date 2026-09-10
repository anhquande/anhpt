import '../core/pose/pose.dart';
import 'ml_kit/ml_kit_pose_estimator.dart';

/// Application composition point for the currently selected pose adapter.
///
/// Camera, pipeline, workout, and UI code depend only on [PoseEstimator].
/// Replacing the concrete engine later should only require changing this file.
PoseEstimator createDefaultPoseEstimator() => MlKitPoseEstimator();
