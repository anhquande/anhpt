import 'dart:collection';

import 'body_pose.dart';
import 'pose_frame.dart';

/// Static capabilities advertised by a concrete pose-estimation adapter.
///
/// Consumers should branch on capabilities rather than on a concrete engine
/// type or engine name.
class PoseEstimatorCapabilities {
  PoseEstimatorCapabilities({
    required Set<BodyJoint> supportedJoints,
    this.supports3D = false,
    this.supportsSegmentation = false,
    this.maxPoseCount = 1,
  })  : assert(maxPoseCount > 0),
        supportedJoints = UnmodifiableSetView(
          Set<BodyJoint>.from(supportedJoints),
        );

  final Set<BodyJoint> supportedJoints;
  final bool supports3D;
  final bool supportsSegmentation;
  final int maxPoseCount;

  bool get supportsMultiplePoses => maxPoseCount > 1;

  bool supportsJoint(BodyJoint joint) => supportedJoints.contains(joint);
}

/// Engine-agnostic lifecycle and inference contract for pose estimation.
///
/// Implementations receive only [PoseFrame], never camera-plugin frame types.
/// A frame's borrowed byte buffers must not be retained after [estimate]
/// completes.
abstract interface class PoseEstimator {
  PoseEstimatorCapabilities get capabilities;

  bool get isInitialized;

  Future<void> initialize();

  /// Estimates zero or more body poses from [frame].
  ///
  /// An empty list means that no pose was detected. Implementations supporting
  /// more than one pose may return multiple results up to the advertised
  /// [PoseEstimatorCapabilities.maxPoseCount].
  Future<List<BodyPose>> estimate(PoseFrame frame);

  Future<void> dispose();
}
