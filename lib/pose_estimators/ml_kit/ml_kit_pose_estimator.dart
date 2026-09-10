import 'dart:math' as math;
import 'dart:ui';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_estimators/ml_kit/ml_kit_joint_mapper.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Test seam around the engine-specific detector.
///
/// This stays in the ML Kit adapter package; core pose consumers only depend on
/// [PoseEstimator].
abstract interface class MlKitPoseBackend {
  Future<List<Pose>> processImage(InputImage image);

  Future<void> close();
}

typedef MlKitPoseBackendFactory = MlKitPoseBackend Function();

class _GoogleMlKitPoseBackend implements MlKitPoseBackend {
  _GoogleMlKitPoseBackend({
    required PoseDetectionModel model,
    required PoseDetectionMode mode,
  }) : _detector = PoseDetector(
          options: PoseDetectorOptions(model: model, mode: mode),
        );

  final PoseDetector _detector;

  @override
  Future<List<Pose>> processImage(InputImage image) =>
      _detector.processImage(image);

  @override
  Future<void> close() => _detector.close();
}

/// Google ML Kit implementation of AnhPT's engine-independent [PoseEstimator].
///
/// All ML Kit types and conversion rules stay inside this adapter. The rest of
/// the app can replace this estimator with another implementation without
/// changing the core pose domain.
class MlKitPoseEstimator implements PoseEstimator {
  MlKitPoseEstimator({
    PoseDetectionModel model = PoseDetectionModel.base,
    PoseDetectionMode mode = PoseDetectionMode.stream,
    MlKitPoseBackendFactory? backendFactory,
  }) : _backendFactory = backendFactory ??
            (() => _GoogleMlKitPoseBackend(model: model, mode: mode));

  static final PoseEstimatorCapabilities _capabilities =
      PoseEstimatorCapabilities(
    supportedJoints: MlKitJointMapper.supportedJoints,
    supports3D: true,
    supportsSegmentation: false,
    maxPoseCount: 1,
  );

  final MlKitPoseBackendFactory _backendFactory;

  MlKitPoseBackend? _backend;
  bool _isInitialized = false;

  @override
  PoseEstimatorCapabilities get capabilities => _capabilities;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _backend = _backendFactory();
    _isInitialized = true;
  }

  @override
  Future<List<BodyPose>> estimate(PoseFrame frame) async {
    final backend = _backend;
    if (!_isInitialized || backend == null) {
      throw StateError('MlKitPoseEstimator must be initialized before estimate.');
    }

    final inputImage = _toInputImage(frame);
    final nativePoses = await backend.processImage(inputImage);

    return nativePoses
        .take(capabilities.maxPoseCount)
        .map((pose) => _toBodyPose(pose, frame))
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    final backend = _backend;
    _backend = null;
    _isInitialized = false;

    if (backend != null) {
      await backend.close();
    }
  }

  BodyPose _toBodyPose(Pose nativePose, PoseFrame frame) {
    final joints = <BodyJoint, PosePoint>{};

    for (final entry in nativePose.landmarks.entries) {
      final bodyJoint = MlKitJointMapper.toBodyJoint(entry.key);
      if (bodyJoint == null) {
        continue;
      }

      final landmark = entry.value;
      final confidence = landmark.likelihood.clamp(0.0, 1.0).toDouble();
      joints[bodyJoint] = PosePoint(
        x: landmark.x / frame.width,
        y: landmark.y / frame.height,
        z: MlKitJointMapper.supportsReliableDepth(entry.key)
            ? landmark.z / math.max(frame.width, frame.height)
            : null,
        confidence: confidence,
      );
    }

    final confidence = joints.isEmpty
        ? 0.0
        : joints.values
                .fold<double>(0, (sum, point) => sum + point.confidence) /
            joints.length;

    return BodyPose(
      joints: joints,
      timestamp: frame.timestamp,
      confidence: confidence,
    );
  }

  InputImage _toInputImage(PoseFrame frame) {
    if (frame.planes.length != 1) {
      throw UnsupportedError(
        'ML Kit adapter currently requires a single packed image plane.',
      );
    }

    final plane = frame.planes.single;
    final format = switch (frame.format) {
      PoseFrameFormat.nv21 => InputImageFormat.nv21,
      PoseFrameFormat.bgra8888 => InputImageFormat.bgra8888,
      _ => throw UnsupportedError(
          'ML Kit adapter does not support ${frame.format.name} frames.',
        ),
    };

    final bytesPerRow = plane.bytesPerRow ??
        switch (frame.format) {
          PoseFrameFormat.nv21 => frame.width,
          PoseFrameFormat.bgra8888 => frame.width * 4,
          _ => throw StateError('Unsupported frame format passed validation.'),
        };

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: _toInputImageRotation(frame.rotationDegrees),
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  InputImageRotation _toInputImageRotation(int rotationDegrees) =>
      switch (rotationDegrees) {
        0 => InputImageRotation.rotation0deg,
        90 => InputImageRotation.rotation90deg,
        180 => InputImageRotation.rotation180deg,
        270 => InputImageRotation.rotation270deg,
        _ => throw ArgumentError.value(
            rotationDegrees,
            'rotationDegrees',
            'Expected 0, 90, 180 or 270.',
          ),
      };
}
