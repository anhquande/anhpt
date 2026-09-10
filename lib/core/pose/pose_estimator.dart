import 'dart:collection';

import 'body_pose.dart';

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

/// Engine-agnostic lifecycle contract for pose estimation.
///
/// The frame/input contract is deliberately added in the next integration
/// step, once the shared pose-frame abstraction exists. Keeping it out of this
/// first layer prevents camera or engine-specific frame types from leaking into
/// the core API.
abstract interface class PoseEstimator {
  PoseEstimatorCapabilities get capabilities;

  bool get isInitialized;

  Future<void> initialize();

  Future<void> dispose();
}
