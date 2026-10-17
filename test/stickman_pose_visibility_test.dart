import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/pose_rendering/stickman_pose_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime.utc(2026, 10, 17);
BodyPose pose(int ms, {double confidence = .9, bool wrist = true}) => BodyPose(
  joints: {
    BodyJoint.leftElbow: PosePoint(x: .5, y: .5, confidence: confidence),
    if (wrist)
      BodyJoint.leftWrist: PosePoint(x: .6, y: .6, confidence: confidence),
  },
  timestamp: t0.add(Duration(milliseconds: ms)),
  confidence: confidence,
);
void main() {
  test(
    'brief confidence dips hold visible joints without changing raw data',
    () {
      final visibility = StickmanPoseVisibility();
      final high = pose(0);
      visibility.update(high, timestamp: t0);
      for (final ms in [67, 134, 201, 299]) {
        final low = pose(ms, confidence: .39);
        final shown = visibility.update(low, timestamp: low.timestamp)!;
        expect(shown[BodyJoint.leftWrist], same(high[BodyJoint.leftWrist]));
        expect(low[BodyJoint.leftWrist]!.confidence, .39);
      }
      expect(
        visibility.expire(t0.add(const Duration(milliseconds: 300))),
        isNull,
      );
    },
  );
  test(
    'alternating confidence does not blink and recovery follows current pose',
    () {
      final visibility = StickmanPoseVisibility();
      for (var frame = 0; frame < 20; frame++) {
        final raw = pose(frame * 67, confidence: frame.isEven ? .41 : .39);
        final shown = visibility.update(raw, timestamp: raw.timestamp);
        expect(shown![BodyJoint.leftWrist], isNotNull);
        expect(shown[BodyJoint.leftWrist]!.confidence, .41);
      }
    },
  );
  test(
    'missing wrist expires independently while elbow continues updating',
    () {
      final visibility = StickmanPoseVisibility();
      visibility.update(pose(0), timestamp: t0);
      final raw = pose(300, wrist: false);
      final shown = visibility.update(raw, timestamp: raw.timestamp)!;
      expect(shown[BodyJoint.leftWrist], isNull);
      expect(shown[BodyJoint.leftElbow], isNotNull);
    },
  );
  test('low confidence never creates a new visible joint', () {
    final visibility = StickmanPoseVisibility();
    expect(visibility.update(pose(0, confidence: .39), timestamp: t0), isNull);
  });
  test('reset and backwards timestamps discard old-person joints', () {
    final visibility = StickmanPoseVisibility();
    visibility.update(
      pose(100),
      timestamp: t0.add(const Duration(milliseconds: 100)),
    );
    expect(visibility.update(pose(0, confidence: .1), timestamp: t0), isNull);
    visibility.update(
      pose(100),
      timestamp: t0.add(const Duration(milliseconds: 100)),
    );
    visibility.reset();
    expect(visibility.nextExpiry, isNull);
  });
}
