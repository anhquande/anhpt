import 'dart:async';
import 'dart:ui';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_rendering/pose_rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PoseViewTransform', () {
    test('identity transform maps normalized source directly into view', () {
      final transform = _transform(
        sourceSize: const Size(1000, 1000),
        viewportSize: const Size(1000, 1000),
      );

      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .25, y: .75, confidence: 1),
        ),
        const Offset(250, 750),
      );
    });

    test('front presentation mirror flips x without changing canonical point', () {
      const point = PosePoint(x: .2, y: .4, confidence: 1);
      final transform = _transform(
        sourceSize: const Size(1000, 1000),
        viewportSize: const Size(1000, 1000),
        mirrored: true,
      );

      _expectOffset(transform.transformPoint(point), const Offset(800, 400));
      expect(point.x, .2);
      expect(point.y, .4);
    });

    test('90 degree rotation maps non-symmetric points', () {
      final transform = _transform(
        sourceSize: const Size(1000, 1000),
        viewportSize: const Size(1000, 1000),
        rotationDegrees: 90,
      );

      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .2, y: .7, confidence: 1),
        ),
        const Offset(300, 200),
      );
      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .8, y: .1, confidence: 1),
        ),
        const Offset(900, 800),
      );
    });

    test('180 degree rotation inverts both axes', () {
      final transform = _transform(
        sourceSize: const Size(1000, 1000),
        viewportSize: const Size(1000, 1000),
        rotationDegrees: 180,
      );

      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .2, y: .7, confidence: 1),
        ),
        const Offset(800, 300),
      );
    });

    test('270 degree rotation maps non-symmetric points', () {
      final transform = _transform(
        sourceSize: const Size(1000, 1000),
        viewportSize: const Size(1000, 1000),
        rotationDegrees: 270,
      );

      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .2, y: .7, confidence: 1),
        ),
        const Offset(700, 800),
      );
    });

    test('portrait quarter-turn swaps oriented source dimensions', () {
      final transform = _transform(
        sourceSize: const Size(640, 480),
        viewportSize: const Size(480, 640),
        rotationDegrees: 90,
      );

      expect(transform.orientedSourceSize, const Size(480, 640));
      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .25, y: .75, confidence: 1),
        ),
        const Offset(120, 160),
      );
    });

    test('rotation then mirror composition has explicit order', () {
      final transform = _transform(
        sourceSize: const Size(1000, 1000),
        viewportSize: const Size(1000, 1000),
        rotationDegrees: 90,
        mirrored: true,
      );

      _expectOffset(
        transform.transformPoint(
          const PosePoint(x: .2, y: .3, confidence: 1),
        ),
        const Offset(300, 200),
      );
    });

    test('invalid source metadata and rotation fail clearly', () {
      expect(
        () => CameraPreviewGeometry(
          previewSourceSize: Size.zero,
          viewportSize: const Size(100, 100),
          fit: BoxFit.contain,
          mirrored: false,
        ),
        throwsArgumentError,
      );

      expect(
        () => PoseViewTransform(
          sourceSize: const Size(640, 480),
          rotationDegrees: 45,
          previewGeometry: CameraPreviewGeometry(
            previewSourceSize: const Size(640, 480),
            viewportSize: const Size(640, 480),
            fit: BoxFit.fill,
            mirrored: false,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('CameraPreviewGeometry', () {
    test('contain fit reproduces centered aspect-ratio letterboxing', () {
      final geometry = CameraPreviewGeometry(
        previewSourceSize: const Size(640, 480),
        viewportSize: const Size(1000, 1000),
        fit: BoxFit.contain,
        mirrored: false,
      );

      _expectRect(
        geometry.destinationRect,
        const Rect.fromLTWH(0, 125, 1000, 750),
      );
      _expectOffset(
        geometry.transformNormalizedPoint(const Offset(.5, .5)),
        const Offset(500, 500),
      );
      _expectOffset(
        geometry.transformNormalizedPoint(const Offset(0, .5)),
        const Offset(0, 500),
      );
      _expectOffset(
        geometry.transformNormalizedPoint(const Offset(1, .5)),
        const Offset(1000, 500),
      );
      _expectOffset(
        geometry.transformNormalizedPoint(const Offset(.5, 0)),
        const Offset(500, 125),
      );
      _expectOffset(
        geometry.transformNormalizedPoint(const Offset(.5, 1)),
        const Offset(500, 875),
      );
    });

    test('cover fit exposes the same centered source crop used for mapping', () {
      final geometry = CameraPreviewGeometry(
        previewSourceSize: const Size(640, 480),
        viewportSize: const Size(1000, 1000),
        fit: BoxFit.cover,
        mirrored: false,
      );

      _expectRect(
        geometry.sourceRect,
        const Rect.fromLTWH(80, 0, 480, 480),
      );
      _expectRect(
        geometry.destinationRect,
        const Rect.fromLTWH(0, 0, 1000, 1000),
      );
      _expectOffset(
        geometry.transformNormalizedPoint(const Offset(.5, .5)),
        const Offset(500, 500),
      );
      expect(
        geometry.transformNormalizedPoint(const Offset(0, .5)).dx,
        closeTo(-166.6666667, .0001),
      );
      expect(
        geometry.transformNormalizedPoint(const Offset(1, .5)).dx,
        closeTo(1166.6666667, .0001),
      );
    });
  });

  testWidgets(
    'camera and skeleton share geometry and recalculate after resize',
    (tester) async {
      final results = StreamController<PosePipelineResult>.broadcast(sync: true);
      addTearDown(results.close);
      final renderer = _RecordingRenderer();
      final pose = BodyPose(
        joints: const {
          BodyJoint.nose: PosePoint(x: .5, y: .5, confidence: 1),
        },
        timestamp: DateTime.utc(2026, 9, 10),
        confidence: 1,
      );
      final result = PosePipelineResult(
        frame: PoseFrameMetadata(
          width: 640,
          height: 480,
          rotationDegrees: 0,
          format: PoseFrameFormat.nv21,
          timestamp: pose.timestamp,
          isMirrored: false,
          cameraFacing: PoseCameraFacing.back,
        ),
        poses: [pose],
        inferenceDuration: const Duration(milliseconds: 4),
      );

      Future<void> pumpAt(Size size) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(
                key: const ValueKey('pose-host'),
                size: size,
                child: RealtimePoseView(
                  camera: const SizedBox(key: ValueKey('fake-camera')),
                  results: results.stream,
                  mode: PoseViewMode.cameraWithSkeleton,
                  renderer: renderer,
                  previewFit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
        results.add(result);
        await tester.pump();
      }

      await pumpAt(const Size(300, 300));
      final hostRect = tester.getRect(find.byKey(const ValueKey('pose-host')));
      final cameraRect =
          tester.getRect(find.byKey(const ValueKey('pose-camera-layer')));
      expect(cameraRect.width, closeTo(300, .001));
      expect(cameraRect.height, closeTo(225, .001));
      expect(cameraRect.top - hostRect.top, closeTo(37.5, .001));

      var paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('pose-skeleton-layer')),
      );
      var painter = paint.painter! as PosePainter;
      _expectRect(
        painter.viewTransform.previewGeometry.destinationRect,
        const Rect.fromLTWH(0, 37.5, 300, 225),
      );
      expect(renderer.lastPose, same(pose));

      await pumpAt(const Size(400, 200));
      paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('pose-skeleton-layer')),
      );
      painter = paint.painter! as PosePainter;
      final resizedGeometry = painter.viewTransform.previewGeometry;
      expect(resizedGeometry.viewportSize, const Size(400, 200));
      expect(resizedGeometry.destinationRect.left, closeTo(66.6666667, .001));
      expect(resizedGeometry.destinationRect.width, closeTo(266.6666667, .001));
      expect(resizedGeometry.destinationRect.height, closeTo(200, .001));
    },
  );
}

PoseViewTransform _transform({
  required Size sourceSize,
  required Size viewportSize,
  int rotationDegrees = 0,
  bool mirrored = false,
  BoxFit fit = BoxFit.fill,
}) {
  final orientedSize = PoseViewTransform.orientedSourceSizeFor(
    sourceSize,
    rotationDegrees,
  );
  return PoseViewTransform(
    sourceSize: sourceSize,
    rotationDegrees: rotationDegrees,
    previewGeometry: CameraPreviewGeometry(
      previewSourceSize: orientedSize,
      viewportSize: viewportSize,
      fit: fit,
      mirrored: mirrored,
    ),
  );
}

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, .000001));
  expect(actual.dy, closeTo(expected.dy, .000001));
}

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, .000001));
  expect(actual.top, closeTo(expected.top, .000001));
  expect(actual.width, closeTo(expected.width, .000001));
  expect(actual.height, closeTo(expected.height, .000001));
}

class _RecordingRenderer implements PoseRenderer {
  BodyPose? lastPose;

  @override
  void render({
    required Canvas canvas,
    required Size size,
    required BodyPose pose,
    required PosePointProjector transformPoint,
  }) {
    lastPose = pose;
  }
}
