import 'dart:typed_data';

import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingPoseEstimator implements PoseEstimator {
  _RecordingPoseEstimator()
      : capabilities = PoseEstimatorCapabilities(supportedJoints: {});

  @override
  final PoseEstimatorCapabilities capabilities;

  bool _isInitialized = false;
  PoseFrame? lastFrame;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<List<BodyPose>> estimate(PoseFrame frame) async {
    lastFrame = frame;
    return const [];
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }
}

void main() {
  group('PoseFrame', () {
    test('carries normalized image metadata without camera types', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final sourcePlanes = <PoseFramePlane>[
        PoseFramePlane(
          bytes: bytes,
          bytesPerRow: 4,
          bytesPerPixel: 1,
        ),
      ];
      final timestamp = DateTime.utc(2026, 9, 10, 18, 30);

      final frame = PoseFrame(
        width: 1920,
        height: 1080,
        rotationDegrees: 90,
        format: PoseFrameFormat.yuv420,
        planes: sourcePlanes,
        timestamp: timestamp,
        isMirrored: true,
      );

      sourcePlanes.clear();

      expect(frame.width, 1920);
      expect(frame.height, 1080);
      expect(frame.rotationDegrees, 90);
      expect(frame.format, PoseFrameFormat.yuv420);
      expect(frame.timestamp, timestamp);
      expect(frame.isMirrored, isTrue);
      expect(frame.isPortraitAfterRotation, isTrue);
      expect(frame.planes, hasLength(1));
      expect(identical(frame.planes.single.bytes, bytes), isTrue);
      expect(() => frame.planes.clear(), throwsUnsupportedError);
    });

    test('supports packed image formats as a single plane', () {
      final frame = PoseFrame(
        width: 640,
        height: 480,
        rotationDegrees: 0,
        format: PoseFrameFormat.rgba8888,
        planes: [
          PoseFramePlane(
            bytes: Uint8List(640 * 480 * 4),
            bytesPerRow: 640 * 4,
            bytesPerPixel: 4,
          ),
        ],
        timestamp: DateTime.utc(2026, 9, 10),
      );

      expect(frame.planes, hasLength(1));
      expect(frame.isPortraitAfterRotation, isFalse);
    });

    test('rejects unsupported rotation values', () {
      expect(
        () => PoseFrame(
          width: 640,
          height: 480,
          rotationDegrees: 45,
          format: PoseFrameFormat.unknown,
          planes: [PoseFramePlane(bytes: Uint8List(1))],
          timestamp: DateTime.utc(2026, 9, 10),
        ),
        throwsAssertionError,
      );
    });
  });

  test('PoseEstimator receives the shared PoseFrame contract', () async {
    final estimator = _RecordingPoseEstimator();
    final frame = PoseFrame(
      width: 320,
      height: 240,
      rotationDegrees: 0,
      format: PoseFrameFormat.nv21,
      planes: [PoseFramePlane(bytes: Uint8List(1))],
      timestamp: DateTime.utc(2026, 9, 10),
    );

    await estimator.initialize();
    final poses = await estimator.estimate(frame);

    expect(poses, isEmpty);
    expect(identical(estimator.lastFrame, frame), isTrue);
  });
}
