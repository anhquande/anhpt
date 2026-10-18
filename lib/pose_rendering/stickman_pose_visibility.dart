import '../core/pose/body_pose.dart';

/// Short, per-joint dropout tolerance for the avatar only. Held landmarks never
/// feed tracking quality, exercise analysis, or the canonical EMA smoother.
class StickmanPoseVisibility {
  StickmanPoseVisibility({
    this.holdDuration = const Duration(milliseconds: 300),
    this.minConfidence = .4,
  }) : assert(holdDuration > Duration.zero),
       assert(minConfidence >= 0 && minConfidence <= 1);

  final Duration holdDuration;
  final double minConfidence;
  final Map<BodyJoint, PosePoint> _joints = {};
  final Map<BodyJoint, DateTime> _seenAt = {};
  final Set<BodyJoint> _uncertain = {};
  DateTime? _timestamp;
  double _confidence = 0;

  BodyPose? update(BodyPose? pose, {required DateTime timestamp}) {
    if (_timestamp != null && timestamp.isBefore(_timestamp!)) reset();
    _uncertain.addAll(_joints.keys);
    if (pose != null) {
      _confidence = pose.confidence;
      for (final entry in pose.joints.entries) {
        final point = entry.value;
        if (point.confidence >= minConfidence &&
            point.x.isFinite &&
            point.y.isFinite) {
          _joints[entry.key] = point;
          _seenAt[entry.key] = timestamp;
          _uncertain.remove(entry.key);
        }
      }
    }
    return expire(timestamp);
  }

  BodyPose? expire(DateTime timestamp) {
    _timestamp = timestamp;
    final expired = _seenAt.entries
        .where(
          (entry) =>
              _uncertain.contains(entry.key) &&
              !timestamp.isBefore(entry.value.add(holdDuration)),
        )
        .map((entry) => entry.key)
        .toList();
    for (final joint in expired) {
      _joints.remove(joint);
      _seenAt.remove(joint);
      _uncertain.remove(joint);
    }
    return _joints.isEmpty
        ? null
        : BodyPose(
            joints: _joints,
            timestamp: timestamp,
            confidence: _confidence,
          );
  }

  DateTime? get nextExpiry {
    // A confident joint must not expire just because the next inference takes
    // longer than holdDuration. Stream silence is handled separately by the view.
    if (_uncertain.isEmpty) return null;
    final first = _uncertain
        .map((joint) => _seenAt[joint]!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return first.add(holdDuration);
  }

  void reset() {
    _joints.clear();
    _seenAt.clear();
    _uncertain.clear();
    _timestamp = null;
    _confidence = 0;
  }
}
