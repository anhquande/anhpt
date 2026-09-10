import 'dart:async';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_rendering/pose_rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _capabilities = PoseEstimatorCapabilities(
  supportedJoints: BodyJoint.values.toSet(),
);

BodyPose _fullBodyPose(DateTime timestamp, {double leftShoulderX = 0.2}) =>
    BodyPose(
      joints: {
        for (final joint in PoseTrackingRequirements.fullBody().requiredJoints)
          joint: PosePoint(
            x: joint == BodyJoint.leftShoulder ? leftShoulderX : 0.5,
            y: 0.5,
            confidence: 0.9,
          ),
      },
      timestamp: timestamp,
      confidence: 0.9,
    );

PosePipelineResult _result(DateTime timestamp, List<BodyPose> poses) =>
    PosePipelineResult(
      frame: PoseFrameMetadata(
        width: 640,
        height: 480,
        rotationDegrees: 0,
        format: PoseFrameFormat.nv21,
        timestamp: timestamp,
        isMirrored: false,
        cameraFacing: PoseCameraFacing.back,
      ),
      poses: poses,
      inferenceDuration: const Duration(milliseconds: 10),
      capabilities: _capabilities,
    );

Widget _app({
  required Stream<PosePipelineResult> results,
  required PoseSmoother smoother,
  required PoseTrackingConfig trackingConfig,
}) =>
    MaterialApp(
      home: SizedBox(
        width: 320,
        height: 480,
        child: RealtimePoseView(
          camera: const SizedBox(key: ValueKey('fake-camera')),
          results: results,
          capabilities: _capabilities,
          trackingConfig: trackingConfig,
          smoother: smoother,
          mode: PoseViewMode.cameraWithSkeleton,
          renderer: SkeletonPoseRenderer(),
        ),
      ),
    );

class _RecordingSmoother implements PoseSmoother {
  _RecordingSmoother({this.leftShoulderOutputX});

  final double? leftShoulderOutputX;
  BodyPose? lastInput;
  int updateCount = 0;
  int resetCount = 0;

  @override
  BodyPose update(BodyPose pose) {
    lastInput = pose;
    updateCount++;

    final replacementX = leftShoulderOutputX;
    if (replacementX == null || !pose.hasJoint(BodyJoint.leftShoulder)) {
      return pose;
    }

    final joints = Map<BodyJoint, PosePoint>.from(pose.joints);
    final point = joints[BodyJoint.leftShoulder]!;
    joints[BodyJoint.leftShoulder] = PosePoint(
      x: replacementX,
      y: point.y,
      z: point.z,
      confidence: point.confidence,
    );
    return BodyPose(
      joints: joints,
      timestamp: pose.timestamp,
      confidence: pose.confidence,
    );
  }

  @override
  void reset() {
    resetCount++;
  }
}

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12);

  testWidgets('tracking evaluates raw pose and renderer receives smoothed pose',
      (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    final smoother = _RecordingSmoother(leftShoulderOutputX: 0.75);
    addTearDown(results.close);

    await tester.pumpWidget(
      _app(
        results: results.stream,
        smoother: smoother,
        trackingConfig: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: Duration.zero,
        ),
      ),
    );

    results.add(_result(t0, [_fullBodyPose(t0, leftShoulderX: 0.2)]));
    await tester.pump();

    expect(smoother.lastInput![BodyJoint.leftShoulder]!.x, 0.2);
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('pose-skeleton-layer')),
    );
    final painter = paint.painter! as PosePainter;
    expect(painter.pose![BodyJoint.leftShoulder]!.x, 0.75);
  });

  testWidgets('short lostTracking retains smoother history for recovery',
      (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    final smoother = _RecordingSmoother();
    addTearDown(results.close);

    await tester.pumpWidget(
      _app(
        results: results.stream,
        smoother: smoother,
        trackingConfig: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: Duration.zero,
          lostTrackingDelay: Duration.zero,
          noPersonDelay: const Duration(seconds: 1),
          recoveryDuration: Duration.zero,
        ),
      ),
    );

    results.add(_result(t0, [_fullBodyPose(t0)]));
    await tester.pump();
    final resetCountWhileTracking = smoother.resetCount;
    expect(smoother.updateCount, 1);

    results.add(_result(t0.add(const Duration(milliseconds: 100)), const []));
    await tester.pump();
    expect(find.text('Tracking lost'), findsOneWidget);
    expect(smoother.resetCount, resetCountWhileTracking);

    final recoveredAt = t0.add(const Duration(milliseconds: 200));
    results.add(_result(recoveredAt, [_fullBodyPose(recoveredAt)]));
    await tester.pump();
    expect(smoother.updateCount, 2);
    expect(smoother.resetCount, resetCountWhileTracking);
  });

  testWidgets('noPerson resets smoother before a new person is accepted',
      (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    final smoother = _RecordingSmoother();
    addTearDown(results.close);

    await tester.pumpWidget(
      _app(
        results: results.stream,
        smoother: smoother,
        trackingConfig: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: Duration.zero,
          lostTrackingDelay: Duration.zero,
          noPersonDelay: const Duration(milliseconds: 200),
          recoveryDuration: Duration.zero,
        ),
      ),
    );

    results.add(_result(t0, [_fullBodyPose(t0)]));
    await tester.pump();
    final resetCountWhileTracking = smoother.resetCount;

    results.add(_result(t0.add(const Duration(milliseconds: 50)), const []));
    await tester.pump();
    expect(smoother.resetCount, resetCountWhileTracking);

    results.add(_result(t0.add(const Duration(milliseconds: 250)), const []));
    await tester.pump();
    expect(find.text('Move into camera view'), findsOneWidget);
    expect(smoother.resetCount, resetCountWhileTracking + 1);

    final newPersonAt = t0.add(const Duration(milliseconds: 300));
    results.add(_result(newPersonAt, [_fullBodyPose(newPersonAt)]));
    await tester.pump();
    expect(smoother.updateCount, 2);
  });
}
