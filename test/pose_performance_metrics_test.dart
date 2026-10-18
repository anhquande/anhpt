import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/widgets/pose_performance_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports sampled frame rate and returns zero for silent windows', () {
    final metrics = PosePerformanceMetrics();
    final start = DateTime.utc(2026, 10, 18);
    for (var i = 0; i < 10; i++) {
      metrics.sampledFrame(start.add(Duration(milliseconds: i * 100)));
    }
    metrics.tick(start.add(const Duration(seconds: 1)));
    expect(metrics.sampledFps, closeTo(10, .01));
    metrics.tick(start.add(const Duration(seconds: 2)));
    expect(metrics.sampledFps, 0);
  });

  test('captures copy, sample cadence and Flutter callback delays', () {
    final metrics = PosePerformanceMetrics();
    final start = DateTime.utc(2026, 10, 18);
    metrics.sampledFrame(start);
    expect(metrics.lastSampleInterval, isNull);
    metrics.sampledFrame(start.add(const Duration(milliseconds: 105)));
    expect(metrics.lastSampleInterval, const Duration(milliseconds: 105));
    metrics.sampledFrame(start.add(const Duration(milliseconds: 90)));
    // Out-of-order timing must never report a negative interval.
    expect(metrics.lastSampleInterval, const Duration(milliseconds: 105));
    metrics.copiedFrame(const Duration(milliseconds: 6));
    metrics.uiFrameScheduled(const Duration(milliseconds: 13));
    expect(metrics.lastCopyDuration, const Duration(milliseconds: 6));
    expect(metrics.lastUiFrameDelay, const Duration(milliseconds: 13));
    metrics.reset();
    expect(metrics.lastSampleInterval, isNull);
    expect(metrics.lastCopyDuration, isNull);
    expect(metrics.lastUiFrameDelay, isNull);
  });

  test('frame age is based on latest pose timestamp and reset clears history', () {
    final metrics = PosePerformanceMetrics();
    final start = DateTime.utc(2026, 10, 18);
    expect(metrics.frameAge(start), isNull);
    metrics.receivedPose(PosePipelineResult(
      frame: PoseFrameMetadata(
        width: 640,
        height: 480,
        rotationDegrees: 0,
        format: PoseFrameFormat.rgba8888,
        timestamp: start,
        isMirrored: false,
        cameraFacing: PoseCameraFacing.front,
      ),
      poses: const [],
      inferenceDuration: const Duration(milliseconds: 100),
    ));
    expect(metrics.frameAge(start.add(const Duration(milliseconds: 350))),
        const Duration(milliseconds: 350));
    expect(metrics.frameAge(start.subtract(const Duration(milliseconds: 1))),
        Duration.zero);
    metrics.reset();
    expect(metrics.frameAge(start), isNull);
    expect(metrics.sampledFps, 0);
  });
}
