import 'dart:math' as math;

import 'body_pose.dart';

/// Engine-agnostic temporal filter for canonical AnhPT poses.
///
/// Implementations operate only on [BodyPose], [PosePoint], and [BodyJoint].
/// Camera/plugin/model-specific types must stay outside this boundary.
abstract interface class PoseSmoother {
  /// Updates smoothing state with the current canonical pose observation.
  BodyPose update(BodyPose pose);

  /// Clears all temporal history.
  void reset();
}

/// Centralized configuration for canonical pose smoothing.
class PoseSmoothingConfig {
  PoseSmoothingConfig({
    this.timeConstant = const Duration(milliseconds: 120),
  }) {
    if (timeConstant.inMicroseconds <= 0) {
      throw ArgumentError.value(
        timeConstant,
        'timeConstant',
        'Must be greater than zero.',
      );
    }
  }

  /// EMA time constant used to derive an effective alpha from elapsed time.
  ///
  /// At the default pose pipeline target of 15 FPS, 120 ms corresponds to an
  /// effective alpha of about 0.43: enough damping for small landmark jitter
  /// while remaining responsive to deliberate motion.
  final Duration timeConstant;
}

/// Time-aware exponential moving average over canonical pose coordinates.
///
/// For positive elapsed time:
///
/// `alpha = 1 - exp(-dt / timeConstant)`
///
/// This keeps smoothing behavior stable when pose FPS varies because of
/// throttling, dropped frames, or inference latency.
///
/// Confidence is intentionally not averaged. Joint confidence and aggregate
/// pose confidence always represent the current observation. Missing joints
/// are omitted immediately and therefore never become long-lived ghost joints.
class EmaPoseSmoother implements PoseSmoother {
  EmaPoseSmoother({PoseSmoothingConfig? config})
      : config = config ?? PoseSmoothingConfig();

  final PoseSmoothingConfig config;

  Map<BodyJoint, PosePoint> _previousJoints = const {};
  DateTime? _previousTimestamp;

  @override
  BodyPose update(BodyPose pose) {
    final previousTimestamp = _previousTimestamp;

    if (previousTimestamp == null) {
      return _setBaseline(pose);
    }

    // An older observation starts a fresh timeline instead of applying an
    // invalid negative time delta to the EMA.
    if (pose.timestamp.isBefore(previousTimestamp)) {
      return _setBaseline(pose);
    }

    final delta = pose.timestamp.difference(previousTimestamp);
    final alpha = _effectiveAlpha(delta);
    final joints = <BodyJoint, PosePoint>{};

    for (final entry in pose.joints.entries) {
      final current = entry.value;
      final previous = _previousJoints[entry.key];
      if (previous == null) {
        // Newly visible joints establish their own baseline. Never interpolate
        // from zero or from history that disappeared in an earlier frame.
        joints[entry.key] = current;
        continue;
      }

      joints[entry.key] = PosePoint(
        x: _lerp(previous.x, current.x, alpha),
        y: _lerp(previous.y, current.y, alpha),
        z: _smoothDepth(previous.z, current.z, alpha),
        confidence: current.confidence,
      );
    }

    _previousJoints = joints;
    _previousTimestamp = pose.timestamp;
    return BodyPose(
      joints: joints,
      timestamp: pose.timestamp,
      confidence: pose.confidence,
    );
  }

  double _effectiveAlpha(Duration delta) {
    final micros = delta.inMicroseconds;
    if (micros <= 0) {
      // No elapsed observation time means no coordinate movement. This avoids
      // NaN/division-by-zero behavior while still preserving the current
      // timestamp and confidence values in the returned pose.
      return 0;
    }

    final ratio = micros / config.timeConstant.inMicroseconds;
    return 1 - math.exp(-ratio);
  }

  static double _lerp(double previous, double current, double alpha) =>
      previous + (current - previous) * alpha;

  static double? _smoothDepth(
    double? previous,
    double? current,
    double alpha,
  ) {
    if (current == null) return null;
    if (previous == null) return current;
    return _lerp(previous, current, alpha);
  }

  BodyPose _setBaseline(BodyPose pose) {
    _previousJoints = pose.joints;
    _previousTimestamp = pose.timestamp;
    return pose;
  }

  @override
  void reset() {
    _previousJoints = const {};
    _previousTimestamp = null;
  }
}
