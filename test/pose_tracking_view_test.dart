import 'dart:async';

import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_rendering/pose_rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _capabilities = PoseEstimatorCapabilities(
  supportedJoints: BodyJoint.values.toSet(),
);

BodyPose _fullBodyPose(DateTime timestamp) => BodyPose(
      joints: {
        for (final joint in PoseTrackingRequirements.fullBody().requiredJoints)
          joint: const PosePoint(x: 0.5, y: 0.5, confidence: 0.9),
      },
      timestamp: timestamp,
      confidence: 0.9,
    );

BodyPose _partialBodyPose(DateTime timestamp) => BodyPose(
      joints: const {
        BodyJoint.leftShoulder:
            PosePoint(x: 0.4, y: 0.25, confidence: 0.9),
        BodyJoint.rightShoulder:
            PosePoint(x: 0.6, y: 0.25, confidence: 0.9),
        BodyJoint.leftHip: PosePoint(x: 0.45, y: 0.55, confidence: 0.9),
        BodyJoint.rightHip: PosePoint(x: 0.55, y: 0.55, confidence: 0.9),
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
  Stream<PosePipelineError>? errors,
  PoseTrackingConfig? config,
  Duration statusDebounce = const Duration(milliseconds: 600),
}) =>
    MaterialApp(
      home: SizedBox(
        width: 320,
        height: 480,
        child: RealtimePoseView(
          camera: const SizedBox(key: ValueKey('fake-camera')),
          results: results,
          errors: errors,
          capabilities: _capabilities,
          trackingConfig: config,
          trackingStatusDebounce: statusDebounce,
          mode: PoseViewMode.cameraWithSkeleton,
          renderer: SkeletonPoseRenderer(),
        ),
      ),
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12);

  testWidgets('shows stable no-person and ready guidance after debounce',
      (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    addTearDown(results.close);

    await tester.pumpWidget(
      _app(
        results: results.stream,
        config: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: const Duration(seconds: 1),
        ),
      ),
    );

    results.add(_result(t0, const []));
    await tester.pump();
    expect(find.text('Move into camera view'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Move into camera view'), findsOneWidget);
    expect(find.byKey(const ValueKey('pose-tracking-status')), findsOneWidget);

    results.add(_result(t0.add(const Duration(milliseconds: 10)), [
      _fullBodyPose(t0.add(const Duration(milliseconds: 10))),
    ]));
    await tester.pump();
    expect(find.text('Move into camera view'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(find.byKey(const ValueKey('pose-skeleton-layer')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Move into camera view'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('brief pose-state chatter does not flash status messages',
      (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    addTearDown(results.close);

    await tester.pumpWidget(
      _app(
        results: results.stream,
        config: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: Duration.zero,
          lostTrackingDelay: Duration.zero,
          noPersonDelay: const Duration(seconds: 1),
          recoveryDuration: Duration.zero,
        ),
      ),
    );

    results.add(_result(t0, [_partialBodyPose(t0)]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('pose-tracking-status')), findsNothing);

    results.add(_result(t0.add(const Duration(milliseconds: 300)), [
      _fullBodyPose(t0.add(const Duration(milliseconds: 300))),
    ]));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('pose-tracking-status')), findsNothing);

    results.add(_result(t0.add(const Duration(seconds: 1)), [
      _partialBodyPose(t0.add(const Duration(seconds: 1))),
    ]));
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.text('Make sure your full body is visible'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Make sure your full body is visible'), findsOneWidget);

    results.add(_result(t0.add(const Duration(milliseconds: 1600)), [
      _fullBodyPose(t0.add(const Duration(milliseconds: 1600))),
    ]));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Make sure your full body is visible'), findsOneWidget);

    results.add(_result(t0.add(const Duration(milliseconds: 1900)), [
      _partialBodyPose(t0.add(const Duration(milliseconds: 1900))),
    ]));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Make sure your full body is visible'), findsOneWidget);

    results.add(_result(t0.add(const Duration(milliseconds: 2300)), [
      _fullBodyPose(t0.add(const Duration(milliseconds: 2300))),
    ]));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('pose-tracking-status')), findsNothing);
  });

  testWidgets('inference errors use tracking hysteresis', (tester) async {
    final results = StreamController<PosePipelineResult>.broadcast(sync: true);
    final errors = StreamController<PosePipelineError>.broadcast(sync: true);
    addTearDown(results.close);
    addTearDown(errors.close);

    await tester.pumpWidget(
      _app(
        results: results.stream,
        errors: errors.stream,
        config: PoseTrackingConfig(
          readyHoldDuration: Duration.zero,
          trackingStartDuration: Duration.zero,
          lostTrackingDelay: const Duration(milliseconds: 250),
          noPersonDelay: const Duration(seconds: 1),
        ),
      ),
    );

    results.add(_result(t0, [_fullBodyPose(t0)]));
    await tester.pump();
    expect(find.byKey(const ValueKey('pose-tracking-status')), findsNothing);

    errors.add(
      PosePipelineError(
        stage: PosePipelineErrorStage.inference,
        error: StateError('temporary'),
        stackTrace: StackTrace.empty,
        frameTimestamp: t0.add(const Duration(milliseconds: 100)),
      ),
    );
    await tester.pump();
    expect(find.text('Tracking lost'), findsNothing);
    expect(find.byKey(const ValueKey('pose-skeleton-layer')), findsOneWidget);

    errors.add(
      PosePipelineError(
        stage: PosePipelineErrorStage.inference,
        error: StateError('still failing'),
        stackTrace: StackTrace.empty,
        frameTimestamp: t0.add(const Duration(milliseconds: 350)),
      ),
    );
    await tester.pump();
    expect(find.text('Tracking lost'), findsNothing);
    expect(find.byKey(const ValueKey('pose-skeleton-layer')), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Tracking lost'), findsOneWidget);
  });
}
