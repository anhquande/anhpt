import '../core/pose/pose_pipeline.dart';

/// Diagnostic sampling of frames handed to the pose pipeline (not webcam FPS).
/// Kept separate from the rendering/tracking path.
class PosePerformanceMetrics {
  int _sampleCount = 0;
  DateTime? _windowStart;
  DateTime? _lastPoseFrame;
  double sampledFps = 0;

  void sampledFrame(DateTime now) {
    _windowStart ??= now;
    _sampleCount++;
  }

  void receivedPose(PosePipelineResult result) {
    _lastPoseFrame = result.frame.timestamp;
  }

  /// Updates the FPS window even when no more frames are delivered.
  void tick(DateTime now) {
    final start = _windowStart;
    if (start == null) return;
    final elapsed = now.difference(start);
    if (elapsed < const Duration(seconds: 1)) return;
    sampledFps = elapsed.inMicroseconds > 0
        ? _sampleCount * Duration.microsecondsPerSecond / elapsed.inMicroseconds
        : 0;
    _sampleCount = 0;
    _windowStart = now;
  }

  /// Age of the most recently received pose frame, not render/compositor lag.
  Duration? frameAge(DateTime now) {
    final timestamp = _lastPoseFrame;
    if (timestamp == null) return null;
    final age = now.difference(timestamp);
    return age.isNegative ? Duration.zero : age;
  }

  void reset() {
    _sampleCount = 0;
    _windowStart = null;
    _lastPoseFrame = null;
    sampledFps = 0;
  }
}
