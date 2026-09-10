import 'dart:io';
import 'dart:typed_data';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_estimators/ml_kit/ml_kit_joint_mapper.dart';
import 'package:anhpt/pose_estimators/ml_kit/ml_kit_pose_estimator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class _FakeMlKitPoseBackend implements MlKitPoseBackend {
  _FakeMlKitPoseBackend(this.poses);

  List<Pose> poses;
  InputImage? lastImage;
  bool isClosed = false;

  @override
  Future<List<Pose>> processImage(InputImage image) async {
    lastImage = image;
    return poses;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

PoseLandmark _landmark(
  PoseLandmarkType type, {
  required double x,
  required double y,
  required double z,
  required double likelihood,
}) =>
    PoseLandmark(
      type: type,
      x: x,
      y: y,
      z: z,
      likelihood: likelihood,
    );

PoseFrame _frame({
  PoseFrameFormat format = PoseFrameFormat.nv21,
  int width = 200,
  int height = 100,
  int rotationDegrees = 90,
  DateTime? timestamp,
}) {
  final bytesPerRow = switch (format) {
    PoseFrameFormat.bgra8888 => width * 4,
    _ => width,
  };

  return PoseFrame(
    width: width,
    height: height,
    rotationDegrees: rotationDegrees,
    format: format,
    planes: [
      PoseFramePlane(
        bytes: Uint8List(16),
        bytesPerRow: bytesPerRow,
      ),
    ],
    timestamp: timestamp ?? DateTime.utc(2026, 9, 10, 19, 30),
  );
}

void main() {
  group('MlKitJointMapper', () {
    test('maps native landmarks to canonical BodyJoint values', () {
      expect(
        MlKitJointMapper.toBodyJoint(PoseLandmarkType.leftShoulder),
        BodyJoint.leftShoulder,
      );
      expect(
        MlKitJointMapper.toBodyJoint(PoseLandmarkType.rightFootIndex),
        BodyJoint.rightFootIndex,
      );
      expect(
        MlKitJointMapper.supportedJoints,
        containsAll({
          BodyJoint.nose,
          BodyJoint.leftHip,
          BodyJoint.rightHeel,
        }),
      );
    });

    test('ignores engine-only landmarks and unsupported canonical joints', () {
      expect(
        MlKitJointMapper.toBodyJoint(PoseLandmarkType.leftPinky),
        isNull,
      );
      expect(MlKitJointMapper.supportedJoints, isNot(contains(BodyJoint.neck)));
    });
  });

  group('MlKitPoseEstimator', () {
    test('advertises canonical capabilities without requiring the detector', () {
      final backend = _FakeMlKitPoseBackend([]);
      final estimator = MlKitPoseEstimator(backendFactory: () => backend);

      expect(estimator.capabilities.supports3D, isTrue);
      expect(estimator.capabilities.supportsSegmentation, isFalse);
      expect(estimator.capabilities.maxPoseCount, 1);
      expect(estimator.capabilities.supportsMultiplePoses, isFalse);
      expect(
        estimator.capabilities.supportsJoint(BodyJoint.leftShoulder),
        isTrue,
      );
      expect(estimator.capabilities.supportsJoint(BodyJoint.neck), isFalse);
    });

    test('converts native pose results and preserves frame timestamp', () async {
      final timestamp = DateTime.utc(2026, 9, 10, 20, 5, 12, 345);
      final nativePose = Pose(
        landmarks: {
          PoseLandmarkType.leftShoulder: _landmark(
            PoseLandmarkType.leftShoulder,
            x: 50,
            y: 25,
            z: -20,
            likelihood: 0.8,
          ),
          PoseLandmarkType.rightShoulder: _landmark(
            PoseLandmarkType.rightShoulder,
            x: 150,
            y: 25,
            z: 10,
            likelihood: 0.6,
          ),
          PoseLandmarkType.nose: _landmark(
            PoseLandmarkType.nose,
            x: 100,
            y: 10,
            z: -99,
            likelihood: 0.9,
          ),
          PoseLandmarkType.leftPinky: _landmark(
            PoseLandmarkType.leftPinky,
            x: 20,
            y: 30,
            z: 5,
            likelihood: 0.99,
          ),
        },
      );
      final backend = _FakeMlKitPoseBackend([nativePose]);
      final estimator = MlKitPoseEstimator(backendFactory: () => backend);
      final frame = _frame(timestamp: timestamp);

      await estimator.initialize();
      final poses = await estimator.estimate(frame);

      expect(poses, hasLength(1));
      final pose = poses.single;
      expect(pose.timestamp, timestamp);
      expect(pose.joints, hasLength(3));
      expect(pose.hasJoint(BodyJoint.leftShoulder), isTrue);
      expect(pose.hasJoint(BodyJoint.rightShoulder), isTrue);
      expect(pose.hasJoint(BodyJoint.neck), isFalse);

      final leftShoulder = pose[BodyJoint.leftShoulder]!;
      expect(leftShoulder.x, closeTo(0.25, 0.000001));
      expect(leftShoulder.y, closeTo(0.25, 0.000001));
      expect(leftShoulder.z, closeTo(-0.1, 0.000001));
      expect(leftShoulder.confidence, 0.8);
      expect(leftShoulder.hasDepth, isTrue);

      final nose = pose[BodyJoint.nose]!;
      expect(nose.x, closeTo(0.5, 0.000001));
      expect(nose.y, closeTo(0.1, 0.000001));
      expect(nose.confidence, 0.9);
      expect(nose.z, isNull);
      expect(nose.hasDepth, isFalse);

      expect(pose.confidence, closeTo((0.8 + 0.6 + 0.9) / 3, 0.000001));
    });

    test('returns an empty list when the engine detects no person', () async {
      final backend = _FakeMlKitPoseBackend([]);
      final estimator = MlKitPoseEstimator(backendFactory: () => backend);

      await estimator.initialize();
      final poses = await estimator.estimate(_frame());

      expect(poses, isEmpty);
    });

    test('converts supported PoseFrame metadata into engine input', () async {
      final backend = _FakeMlKitPoseBackend([]);
      final estimator = MlKitPoseEstimator(backendFactory: () => backend);
      final frame = _frame(
        format: PoseFrameFormat.bgra8888,
        width: 320,
        height: 240,
        rotationDegrees: 270,
      );

      await estimator.initialize();
      await estimator.estimate(frame);

      final metadata = backend.lastImage!.metadata!;
      expect(metadata.size.width, 320);
      expect(metadata.size.height, 240);
      expect(metadata.rotation, InputImageRotation.rotation270deg);
      expect(metadata.format, InputImageFormat.bgra8888);
      expect(metadata.bytesPerRow, 1280);
    });

    test('rejects frame formats that the adapter cannot safely convert', () async {
      final backend = _FakeMlKitPoseBackend([]);
      final estimator = MlKitPoseEstimator(backendFactory: () => backend);

      await estimator.initialize();

      expect(
        () => estimator.estimate(_frame(format: PoseFrameFormat.yuv420)),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('requires initialization and closes the injected backend', () async {
      final backend = _FakeMlKitPoseBackend([]);
      final estimator = MlKitPoseEstimator(backendFactory: () => backend);

      expect(
        () => estimator.estimate(_frame()),
        throwsA(isA<StateError>()),
      );

      await estimator.initialize();
      expect(estimator.isInitialized, isTrue);

      await estimator.dispose();
      expect(estimator.isInitialized, isFalse);
      expect(backend.isClosed, isTrue);
    });
  });

  test('public core pose API contains no ML Kit engine-specific references', () {
    const corePoseFiles = [
      'lib/core/pose/body_pose.dart',
      'lib/core/pose/pose_estimator.dart',
      'lib/core/pose/pose_frame.dart',
      'lib/core/pose/pose.dart',
    ];

    for (final path in corePoseFiles) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('google_mlkit')),
          reason: '$path must remain engine agnostic');
      expect(source, isNot(contains('MlKit')),
          reason: '$path must not name the concrete adapter');
    }
  });
}
