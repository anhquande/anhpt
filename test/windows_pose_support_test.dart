import 'dart:typed_data';

import 'package:anhpt/camera/windows_pose_frame_adapter.dart';
import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_estimators/default_pose_estimator.dart';
import 'package:anhpt/pose_estimators/movenet/movenet_pose_estimator.dart';
import 'package:anhpt/pose_estimators/movenet/movenet_pose_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _moveNetOutput({
  double y = 0.5,
  double x = 0.5,
  double confidence = 0.9,
}) =>
    [
      for (var index = 0; index < 17; index++) ...[y, x, confidence],
    ];

PoseFrame _rgbaFrame({
  required int width,
  required int height,
  required Uint8List bytes,
  DateTime? timestamp,
}) =>
    PoseFrame(
      width: width,
      height: height,
      rotationDegrees: 0,
      format: PoseFrameFormat.rgba8888,
      planes: [
        PoseFramePlane(
          bytes: bytes,
          bytesPerRow: width * 4,
          bytesPerPixel: 4,
        ),
      ],
      timestamp: timestamp ?? DateTime.utc(2026, 9, 10, 20),
      cameraFacing: PoseCameraFacing.front,
    );

void main() {
  group('WindowsPoseFrameAdapter', () {
    test('converts UVC RGBA frames to canonical PoseFrame', () {
      final bytes = Uint8List.fromList([
        1,
        2,
        3,
        255,
        4,
        5,
        6,
        255,
      ]);
      final timestamp = DateTime.utc(2026, 9, 10, 20, 1);
      final frame = WindowsPoseFrameAdapter.fromPreviewFrame(
        frame: UvcPreviewFrame(
          width: 2,
          height: 1,
          rgbaBytes: bytes,
          sequence: 7,
        ),
        cameraFacing: PoseCameraFacing.front,
        timestamp: timestamp,
      );

      expect(frame.width, 2);
      expect(frame.height, 1);
      expect(frame.format, PoseFrameFormat.rgba8888);
      expect(frame.rotationDegrees, 0);
      expect(frame.timestamp, timestamp);
      expect(frame.cameraFacing, PoseCameraFacing.front);
      expect(frame.planes, hasLength(1));
      expect(frame.planes.single.bytesPerRow, 8);
      expect(frame.planes.single.bytesPerPixel, 4);
      expect(frame.planes.single.bytes, same(bytes));
    });
  });

  group('MoveNetPoseMapper', () {
    test('maps all 17 keypoints into AnhPT canonical joints', () {
      final timestamp = DateTime.utc(2026, 9, 10, 20, 2);
      final values = <double>[];
      for (var index = 0; index < 17; index++) {
        values.addAll([index / 20, index / 25, 0.8]);
      }

      final pose = MoveNetPoseMapper.fromFlatOutput(
        values,
        timestamp: timestamp,
      );

      expect(pose.timestamp, timestamp);
      expect(pose.joints, hasLength(17));
      expect(pose[BodyJoint.nose]!.y, closeTo(0, 1e-9));
      expect(pose[BodyJoint.leftShoulder]!.x, closeTo(5 / 25, 1e-9));
      expect(pose[BodyJoint.rightAnkle]!.y, closeTo(16 / 20, 1e-9));
      expect(pose[BodyJoint.leftWrist]!.z, isNull);
      expect(pose.confidence, closeTo(0.8, 1e-9));
    });

    test('supports coordinate remapping after letterbox preprocessing', () {
      final pose = MoveNetPoseMapper.fromFlatOutput(
        _moveNetOutput(y: 0.25, x: 0.75),
        timestamp: DateTime.utc(2026, 9, 10, 20, 3),
        mapX: (value) => value * 2,
        mapY: (value) => value - 0.1,
      );

      expect(pose[BodyJoint.nose]!.x, closeTo(1.5, 1e-9));
      expect(pose[BodyJoint.nose]!.y, closeTo(0.15, 1e-9));
    });
  });

  group('MoveNetPoseEstimator', () {
    test('letterboxes RGBA input and preserves canonical source coordinates',
        () async {
      final backend = _FakeMoveNetBackend(
        output: _moveNetOutput(y: 0.5, x: 0.5),
      );
      final estimator = MoveNetPoseEstimator(backend: backend);
      addTearDown(estimator.dispose);
      await estimator.initialize();

      final pixels = Uint8List(4 * 2 * 4);
      for (var index = 0; index < 8; index++) {
        final offset = index * 4;
        pixels[offset] = 10 + index;
        pixels[offset + 1] = 20 + index;
        pixels[offset + 2] = 30 + index;
        pixels[offset + 3] = 255;
      }
      final timestamp = DateTime.utc(2026, 9, 10, 20, 4);
      final poses = await estimator.estimate(
        _rgbaFrame(
          width: 4,
          height: 2,
          bytes: pixels,
          timestamp: timestamp,
        ),
      );

      expect(poses, hasLength(1));
      final pose = poses.single;
      expect(pose.timestamp, timestamp);
      expect(pose[BodyJoint.nose]!.x, closeTo(0.5, 1e-9));
      expect(pose[BodyJoint.nose]!.y, closeTo(0.5, 1e-9));
      expect(backend.lastInput, isNotNull);
      expect(
        backend.lastInput,
        hasLength(MoveNetPoseEstimator.inputSize *
            MoveNetPoseEstimator.inputSize *
            3),
      );

      // 4x2 is letterboxed into 192x96 with 48 black rows above/below.
      expect(backend.lastInput![0], 0);
      final firstImagePixel = 48 * MoveNetPoseEstimator.inputSize * 3;
      expect(backend.lastInput![firstImagePixel], 10);
      expect(backend.lastInput![firstImagePixel + 1], 20);
      expect(backend.lastInput![firstImagePixel + 2], 30);
    });

    test('advertises the canonical MoveNet capabilities', () {
      final estimator = MoveNetPoseEstimator(backend: _FakeMoveNetBackend());
      expect(estimator.capabilities.supports3D, isFalse);
      expect(estimator.capabilities.maxPoseCount, 1);
      expect(
        estimator.capabilities.supportedJoints,
        containsAll([
          BodyJoint.nose,
          BodyJoint.leftShoulder,
          BodyJoint.rightHip,
          BodyJoint.leftAnkle,
        ]),
      );
    });

    test('rejects non-RGBA and rotated Windows input safely', () async {
      final backend = _FakeMoveNetBackend();
      final estimator = MoveNetPoseEstimator(backend: backend);
      addTearDown(estimator.dispose);
      await estimator.initialize();

      final wrongFormat = PoseFrame(
        width: 1,
        height: 1,
        rotationDegrees: 0,
        format: PoseFrameFormat.nv21,
        planes: [PoseFramePlane(bytes: Uint8List(4))],
        timestamp: DateTime.utc(2026, 9, 10),
      );
      await expectLater(
        estimator.estimate(wrongFormat),
        throwsA(isA<UnsupportedError>()),
      );

      final rotated = PoseFrame(
        width: 1,
        height: 1,
        rotationDegrees: 90,
        format: PoseFrameFormat.rgba8888,
        planes: [
          PoseFramePlane(
            bytes: Uint8List(4),
            bytesPerRow: 4,
            bytesPerPixel: 4,
          ),
        ],
        timestamp: DateTime.utc(2026, 9, 10),
      );
      await expectLater(
        estimator.estimate(rotated),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  test('default estimator selects MoveNet on Windows', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(createDefaultPoseEstimator(), isA<MoveNetPoseEstimator>());
  });
}

class _FakeMoveNetBackend implements MoveNetInferenceBackend {
  _FakeMoveNetBackend({List<double>? output})
      : output = output ?? _moveNetOutput();

  final List<double> output;
  bool _initialized = false;
  Int32List? lastInput;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<List<double>> run(Int32List rgbInput) async {
    lastInput = Int32List.fromList(rgbInput);
    return output;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }
}
