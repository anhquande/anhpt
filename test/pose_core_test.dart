import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoseEstimator implements PoseEstimator {
  _FakePoseEstimator(this.capabilities);

  @override
  final PoseEstimatorCapabilities capabilities;

  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<List<BodyPose>> estimate(PoseFrame frame) async => const [];

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }
}

void main() {
  group('PosePoint', () {
    test('supports both 2D and optional 3D coordinates', () {
      const point2D = PosePoint(x: 0.2, y: 0.4, confidence: 0.9);
      const point3D = PosePoint(
        x: 0.2,
        y: 0.4,
        z: -0.1,
        confidence: 0.9,
      );

      expect(point2D.hasDepth, isFalse);
      expect(point3D.hasDepth, isTrue);
      expect(point3D.z, -0.1);
    });
  });

  group('BodyPose', () {
    test('exposes canonical joints without leaking a mutable map', () {
      final sourceJoints = <BodyJoint, PosePoint>{
        BodyJoint.leftShoulder: const PosePoint(
          x: 0.3,
          y: 0.4,
          confidence: 0.95,
        ),
      };

      final pose = BodyPose(
        joints: sourceJoints,
        timestamp: DateTime.utc(2026, 9, 10),
        confidence: 0.9,
      );

      sourceJoints.clear();

      expect(pose.hasJoint(BodyJoint.leftShoulder), isTrue);
      expect(pose[BodyJoint.leftShoulder]?.confidence, 0.95);
      expect(
        () => pose.joints[BodyJoint.rightShoulder] = const PosePoint(
          x: 0.7,
          y: 0.4,
          confidence: 0.95,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('PoseEstimatorCapabilities', () {
    test('describes features without depending on a concrete engine', () {
      final capabilities = PoseEstimatorCapabilities(
        supportedJoints: {
          BodyJoint.leftShoulder,
          BodyJoint.rightShoulder,
          BodyJoint.leftHip,
          BodyJoint.rightHip,
        },
        supports3D: true,
        maxPoseCount: 2,
      );

      expect(capabilities.supports3D, isTrue);
      expect(capabilities.supportsSegmentation, isFalse);
      expect(capabilities.supportsMultiplePoses, isTrue);
      expect(capabilities.supportsJoint(BodyJoint.leftHip), isTrue);
      expect(capabilities.supportsJoint(BodyJoint.leftWrist), isFalse);
    });
  });

  test('PoseEstimator lifecycle can be implemented without an engine', () async {
    final estimator = _FakePoseEstimator(
      PoseEstimatorCapabilities(
        supportedJoints: {BodyJoint.leftHip, BodyJoint.rightHip},
      ),
    );

    expect(estimator.isInitialized, isFalse);

    await estimator.initialize();
    expect(estimator.isInitialized, isTrue);

    await estimator.dispose();
    expect(estimator.isInitialized, isFalse);
  });
}
