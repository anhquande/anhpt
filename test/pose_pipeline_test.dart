import 'dart:async';
import 'dart:typed_data';

import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoseEstimator implements PoseEstimator {
  _FakePoseEstimator({
    this.blockFirstEstimate,
    this.failuresRemaining = 0,
  }) : capabilities = PoseEstimatorCapabilities(
          supportedJoints: {BodyJoint.nose},
        );

  @override
  final PoseEstimatorCapabilities capabilities;

  final Completer<void>? blockFirstEstimate;
  int failuresRemaining;

  bool _initialized = false;
  int initializeCount = 0;
  int disposeCount = 0;
  int estimateCount = 0;
  int activeEstimateCount = 0;
  int maxConcurrentEstimateCount = 0;
  final List<DateTime> estimatedTimestamps = [];
  final Completer<void> firstEstimateStarted = Completer<void>();

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    initializeCount++;
    _initialized = true;
  }

  @override
  Future<List<BodyPose>> estimate(PoseFrame frame) async {
    estimateCount++;
    activeEstimateCount++;
    if (activeEstimateCount > maxConcurrentEstimateCount) {
      maxConcurrentEstimateCount = activeEstimateCount;
    }
    estimatedTimestamps.add(frame.timestamp);
    if (!firstEstimateStarted.isCompleted) {
      firstEstimateStarted.complete();
    }

    try {
      if (estimateCount == 1 && blockFirstEstimate != null) {
        await blockFirstEstimate!.future;
      }
      if (failuresRemaining > 0) {
        failuresRemaining--;
        throw StateError('synthetic inference failure');
      }
      return [
        BodyPose(
          joints: const {
            BodyJoint.nose: PosePoint(
              x: 0.5,
              y: 0.25,
              confidence: 0.9,
            ),
          },
          timestamp: frame.timestamp,
          confidence: 0.9,
        ),
      ];
    } finally {
      activeEstimateCount--;
    }
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _initialized = false;
  }
}

PoseFrame _frame(DateTime timestamp, {int width = 4, int height = 2}) =>
    PoseFrame(
      width: width,
      height: height,
      rotationDegrees: 0,
      format: PoseFrameFormat.nv21,
      planes: [
        PoseFramePlane(
          bytes: Uint8List(width * height),
          bytesPerRow: width,
          bytesPerPixel: 1,
        ),
      ],
      timestamp: timestamp,
      cameraFacing: PoseCameraFacing.front,
    );

void main() {
  group('PosePipeline', () {
    test('processes a frame into a structured result', () async {
      final estimator = _FakePoseEstimator();
      final pipeline = PosePipeline(estimator: estimator);
      final timestamp = DateTime.utc(2026, 9, 10, 20);

      await pipeline.start();
      final resultFuture = pipeline.results.first;
      pipeline.submit(_frame(timestamp));
      final result = await resultFuture;

      expect(estimator.initializeCount, 1);
      expect(estimator.estimateCount, 1);
      expect(result.frame.timestamp, timestamp);
      expect(result.frame.width, 4);
      expect(result.frame.height, 2);
      expect(result.frame.cameraFacing, PoseCameraFacing.front);
      expect(result.poses, hasLength(1));
      expect(result.poses.single[BodyJoint.nose]?.confidence, 0.9);
      expect(result.inferenceDuration, isA<Duration>());
      expect(pipeline.diagnostics.processedFrameCount, 1);
      expect(pipeline.diagnostics.droppedFrameCount, 0);

      await pipeline.dispose();
    });

    test('never runs parallel inference and keeps only the newest pending frame',
        () async {
      final firstGate = Completer<void>();
      final estimator = _FakePoseEstimator(blockFirstEstimate: firstGate);
      final pipeline = PosePipeline(
        estimator: estimator,
        config: PosePipelineConfig(targetFps: 1000),
      );
      final start = DateTime.utc(2026, 9, 10, 20);

      await pipeline.start();
      final resultsFuture = pipeline.results.take(2).toList();
      pipeline.submit(_frame(start));
      await estimator.firstEstimateStarted.future;

      pipeline.submit(_frame(start.add(const Duration(milliseconds: 2))));
      pipeline.submit(_frame(start.add(const Duration(milliseconds: 3))));
      pipeline.submit(_frame(start.add(const Duration(milliseconds: 4))));
      firstGate.complete();

      final results = await resultsFuture;

      expect(results, hasLength(2));
      expect(estimator.maxConcurrentEstimateCount, 1);
      expect(estimator.estimateCount, 2);
      expect(
        estimator.estimatedTimestamps,
        [start, start.add(const Duration(milliseconds: 4))],
      );
      expect(pipeline.diagnostics.droppedFrameCount, 2);

      await pipeline.dispose();
    });

    test('throttles using capture timestamps instead of camera frame count',
        () async {
      final estimator = _FakePoseEstimator();
      final pipeline = PosePipeline(
        estimator: estimator,
        config: PosePipelineConfig(targetFps: 10),
      );
      final start = DateTime.utc(2026, 9, 10, 20);

      await pipeline.start();
      final firstResult = pipeline.results.first;
      pipeline.submit(_frame(start));
      await firstResult;

      pipeline.submit(_frame(start.add(const Duration(milliseconds: 20))));
      final secondResult = pipeline.results.first;
      pipeline.submit(_frame(start.add(const Duration(milliseconds: 120))));
      await secondResult;

      expect(estimator.estimateCount, 2);
      expect(pipeline.diagnostics.processedFrameCount, 2);
      expect(pipeline.diagnostics.droppedFrameCount, 1);
      expect(pipeline.diagnostics.effectivePoseFps, closeTo(8.33, 0.1));

      await pipeline.dispose();
    });

    test('stop suppresses stale results and pipeline can restart', () async {
      final firstGate = Completer<void>();
      final estimator = _FakePoseEstimator(blockFirstEstimate: firstGate);
      final pipeline = PosePipeline(estimator: estimator);
      final emitted = <PosePipelineResult>[];
      final subscription = pipeline.results.listen(emitted.add);
      final start = DateTime.utc(2026, 9, 10, 20);

      await pipeline.start();
      pipeline.submit(_frame(start));
      await estimator.firstEstimateStarted.future;

      final stopFuture = pipeline.stop();
      firstGate.complete();
      await stopFuture;
      await Future<void>.delayed(Duration.zero);

      expect(pipeline.isRunning, isFalse);
      expect(emitted, isEmpty);

      await pipeline.start();
      final restartedResult = pipeline.results.first;
      pipeline.submit(_frame(start.add(const Duration(seconds: 1))));
      await restartedResult;

      expect(estimator.initializeCount, 1);
      expect(pipeline.isRunning, isTrue);

      await subscription.cancel();
      await pipeline.dispose();
      expect(estimator.disposeCount, 1);
      await expectLater(pipeline.start(), throwsStateError);
    });

    test('inference errors are non-fatal and later frames still process',
        () async {
      final estimator = _FakePoseEstimator(failuresRemaining: 1);
      final pipeline = PosePipeline(estimator: estimator);
      final start = DateTime.utc(2026, 9, 10, 20);

      await pipeline.start();
      final errorFuture = pipeline.errors.first;
      pipeline.submit(_frame(start));
      final error = await errorFuture;

      expect(error.stage, PosePipelineErrorStage.inference);
      expect(error.frameTimestamp, start);

      final resultFuture = pipeline.results.first;
      pipeline.submit(_frame(start.add(const Duration(milliseconds: 100))));
      final result = await resultFuture;

      expect(result.frame.timestamp, start.add(const Duration(milliseconds: 100)));
      expect(estimator.maxConcurrentEstimateCount, 1);
      expect(pipeline.diagnostics.processedFrameCount, 2);
      expect(pipeline.diagnostics.failedFrameCount, 1);

      await pipeline.dispose();
    });
  });
}
