import 'dart:async';
import 'dart:ui';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_rendering/pose_rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical skeleton contains expected limbs and no wrist bridge', () {
    expect(
      canonicalSkeletonBones,
      contains(const PoseBone(BodyJoint.leftShoulder, BodyJoint.leftElbow)),
    );
    expect(
      canonicalSkeletonBones,
      contains(const PoseBone(BodyJoint.leftElbow, BodyJoint.leftWrist)),
    );
    expect(
      canonicalSkeletonBones,
      contains(const PoseBone(BodyJoint.leftHip, BodyJoint.leftKnee)),
    );
    expect(
      canonicalSkeletonBones,
      contains(const PoseBone(BodyJoint.leftKnee, BodyJoint.leftAnkle)),
    );
    expect(
      canonicalSkeletonBones,
      isNot(contains(const PoseBone(BodyJoint.leftWrist, BodyJoint.rightWrist))),
    );
  });

  test('missing joints safely skip incomplete bones', () {
    final renderer = SkeletonPoseRenderer();
    final pose = _pose(
      confidence: .9,
      joints: const {
        BodyJoint.leftShoulder: _high,
        BodyJoint.leftElbow: _high,
      },
    );

    expect(
      renderer.boneIsRenderable(
        pose,
        const PoseBone(BodyJoint.leftShoulder, BodyJoint.leftElbow),
      ),
      isTrue,
    );
    expect(
      renderer.boneIsRenderable(
        pose,
        const PoseBone(BodyJoint.leftElbow, BodyJoint.leftWrist),
      ),
      isFalse,
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      () => renderer.render(canvas: canvas, size: const Size(200, 200), pose: pose),
      returnsNormally,
    );
    recorder.endRecording();
  });

  test('confidence threshold filters joints and bones', () {
    final renderer = SkeletonPoseRenderer(
      config: const SkeletonRenderConfig(minJointConfidence: .4),
    );
    final pose = _pose(
      confidence: .8,
      joints: const {
        BodyJoint.leftShoulder: PosePoint(
          x: .3,
          y: .3,
          confidence: .9,
        ),
        BodyJoint.leftElbow: PosePoint(
          x: .4,
          y: .5,
          confidence: .2,
        ),
      },
    );

    expect(renderer.jointIsRenderable(pose[BodyJoint.leftShoulder]), isTrue);
    expect(renderer.jointIsRenderable(pose[BodyJoint.leftElbow]), isFalse);
    expect(
      renderer.boneIsRenderable(
        pose,
        const PoseBone(BodyJoint.leftShoulder, BodyJoint.leftElbow),
      ),
      isFalse,
    );
  });

  test('normalized coordinates convert to canvas coordinates', () {
    const point = PosePoint(x: .5, y: .25, confidence: 1);
    expect(
      normalizedPosePointToOffset(point, const Size(1000, 800)),
      const Offset(500, 200),
    );
  });

  test('primary pose selection uses highest aggregate confidence', () {
    final poseA = _pose(confidence: .5, joints: const {});
    final poseB = _pose(confidence: .9, joints: const {});

    expect(selectPrimaryPose([poseA, poseB]), same(poseB));
  });

  testWidgets('PosePainter repaints when BodyPose changes', (tester) async {
    final renderer = _RecordingPoseRenderer();
    final poseA = _pose(
      confidence: .8,
      joints: const {BodyJoint.nose: _high},
    );
    final poseB = _pose(
      confidence: .9,
      joints: const {
        BodyJoint.nose: PosePoint(x: .6, y: .4, confidence: .9),
      },
    );

    await _pumpPainter(tester, poseA, renderer);
    final firstPaintCount = renderer.paintCount;
    expect(firstPaintCount, greaterThan(0));
    expect(renderer.lastPose, same(poseA));

    await _pumpPainter(tester, poseB, renderer);
    expect(renderer.paintCount, greaterThan(firstPaintCount));
    expect(renderer.lastPose, same(poseB));
  });

  testWidgets('view modes compose camera and skeleton layers', (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    addTearDown(results.close);
    final renderer = _RecordingPoseRenderer();
    final pose = _pose(
      confidence: .9,
      joints: const {BodyJoint.nose: _high},
    );
    final result = _result(pose);

    Future<void> pumpMode(PoseViewMode mode) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: RealtimePoseView(
              camera: const SizedBox(key: ValueKey('fake-camera')),
              results: results.stream,
              mode: mode,
              renderer: renderer,
            ),
          ),
        ),
      );
      results.add(result);
      await tester.pump();
    }

    await pumpMode(PoseViewMode.camera);
    expect(find.byKey(const ValueKey('pose-camera-layer')), findsOneWidget);
    expect(find.byKey(const ValueKey('pose-skeleton-layer')), findsNothing);

    await pumpMode(PoseViewMode.skeleton);
    expect(find.byKey(const ValueKey('pose-camera-layer')), findsNothing);
    expect(find.byKey(const ValueKey('pose-skeleton-layer')), findsOneWidget);

    await pumpMode(PoseViewMode.cameraWithSkeleton);
    expect(find.byKey(const ValueKey('pose-camera-layer')), findsOneWidget);
    expect(find.byKey(const ValueKey('pose-skeleton-layer')), findsOneWidget);
  });
}

const _high = PosePoint(x: .5, y: .25, confidence: .9);

BodyPose _pose({
  required double confidence,
  required Map<BodyJoint, PosePoint> joints,
}) =>
    BodyPose(
      joints: joints,
      timestamp: DateTime(2026, 9, 10),
      confidence: confidence,
    );

PosePipelineResult _result(BodyPose pose) => PosePipelineResult(
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
      inferenceDuration: const Duration(milliseconds: 8),
    );

Future<void> _pumpPainter(
  WidgetTester tester,
  BodyPose pose,
  PoseRenderer renderer,
) =>
    tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: PosePainter(pose: pose, renderer: renderer),
            ),
          ),
        ),
      ),
    );

class _RecordingPoseRenderer implements PoseRenderer {
  int paintCount = 0;
  BodyPose? lastPose;

  @override
  void render({
    required Canvas canvas,
    required Size size,
    required BodyPose pose,
  }) {
    paintCount++;
    lastPose = pose;
  }
}
