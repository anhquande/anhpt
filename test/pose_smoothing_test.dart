import 'dart:math' as math;

import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

BodyPose _pose({
  required DateTime timestamp,
  required Map<BodyJoint, PosePoint> joints,
  double confidence = 0.9,
}) =>
    BodyPose(
      joints: joints,
      timestamp: timestamp,
      confidence: confidence,
    );

PosePoint _point(
  double x, {
  double y = 0.4,
  double? z,
  double confidence = 0.8,
}) =>
    PosePoint(
      x: x,
      y: y,
      z: z,
      confidence: confidence,
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12);

  test('default config uses a 120 ms time constant', () {
    expect(PoseSmoothingConfig().timeConstant, const Duration(milliseconds: 120));
  });

  test('config rejects non-positive time constants', () {
    expect(
      () => PoseSmoothingConfig(timeConstant: Duration.zero),
      throwsArgumentError,
    );
  });

  test('first observation establishes the baseline', () {
    final smoother = EmaPoseSmoother();
    final input = _pose(
      timestamp: t0,
      joints: {BodyJoint.leftWrist: _point(0.2)},
    );

    final output = smoother.update(input);

    expect(output[BodyJoint.leftWrist]!.x, 0.2);
    expect(output.timestamp, t0);
  });

  test('time-aware EMA smooths coordinates using elapsed time', () {
    final smoother = EmaPoseSmoother(
      config: PoseSmoothingConfig(
        timeConstant: const Duration(milliseconds: 100),
      ),
    );
    smoother.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftWrist: _point(0.2)},
      ),
    );

    final output = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {BodyJoint.leftWrist: _point(0.8)},
      ),
    );

    final alpha = 1 - math.exp(-1);
    final expected = 0.2 + (0.8 - 0.2) * alpha;
    expect(output[BodyJoint.leftWrist]!.x, closeTo(expected, 1e-12));
  });

  test('multiple updates carry smoothing history forward', () {
    final smoother = EmaPoseSmoother(
      config: PoseSmoothingConfig(
        timeConstant: const Duration(milliseconds: 100),
      ),
    );
    smoother.update(
      _pose(timestamp: t0, joints: {BodyJoint.leftWrist: _point(0)}),
    );
    smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {BodyJoint.leftWrist: _point(1)},
      ),
    );
    final output = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 200)),
        joints: {BodyJoint.leftWrist: _point(1)},
      ),
    );

    expect(
      output[BodyJoint.leftWrist]!.x,
      closeTo(1 - math.exp(-2), 1e-12),
    );
  });

  test('joints are smoothed independently', () {
    final smoother = EmaPoseSmoother(
      config: PoseSmoothingConfig(
        timeConstant: const Duration(milliseconds: 100),
      ),
    );
    smoother.update(
      _pose(
        timestamp: t0,
        joints: {
          BodyJoint.leftWrist: _point(0.2),
          BodyJoint.rightWrist: _point(0.7),
        },
      ),
    );

    final output = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {
          BodyJoint.leftWrist: _point(0.8),
          BodyJoint.rightWrist: _point(0.7),
        },
      ),
    );

    expect(output[BodyJoint.leftWrist]!.x, greaterThan(0.2));
    expect(output[BodyJoint.leftWrist]!.x, lessThan(0.8));
    expect(output[BodyJoint.rightWrist]!.x, 0.7);
  });

  test('missing joints are omitted immediately and do not become ghosts', () {
    final smoother = EmaPoseSmoother();
    smoother.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftWrist: _point(0.2)},
      ),
    );

    final missing = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 60)),
        joints: const {},
      ),
    );
    expect(missing.hasJoint(BodyJoint.leftWrist), isFalse);

    final reappeared = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 120)),
        joints: {BodyJoint.leftWrist: _point(0.9)},
      ),
    );
    expect(reappeared[BodyJoint.leftWrist]!.x, 0.9);
  });

  test('a newly appearing joint uses the current point directly', () {
    final smoother = EmaPoseSmoother();
    smoother.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftShoulder: _point(0.3)},
      ),
    );

    final output = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 60)),
        joints: {
          BodyJoint.leftShoulder: _point(0.4),
          BodyJoint.leftWrist: _point(0.85),
        },
      ),
    );

    expect(output[BodyJoint.leftWrist]!.x, 0.85);
  });

  test('depth handling supports 2D and 3D transitions', () {
    final config = PoseSmoothingConfig(
      timeConstant: const Duration(milliseconds: 100),
    );

    final twoDimensional = EmaPoseSmoother(config: config);
    twoDimensional.update(
      _pose(timestamp: t0, joints: {BodyJoint.leftHip: _point(0.2)}),
    );
    final twoToTwo = twoDimensional.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {BodyJoint.leftHip: _point(0.8)},
      ),
    );
    expect(twoToTwo[BodyJoint.leftHip]!.z, isNull);

    final threeDimensional = EmaPoseSmoother(config: config);
    threeDimensional.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftHip: _point(0.2, z: 0.1)},
      ),
    );
    final threeToThree = threeDimensional.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {BodyJoint.leftHip: _point(0.8, z: 0.7)},
      ),
    );
    expect(threeToThree[BodyJoint.leftHip]!.z, greaterThan(0.1));
    expect(threeToThree[BodyJoint.leftHip]!.z, lessThan(0.7));

    final twoToThreeSmoother = EmaPoseSmoother(config: config);
    twoToThreeSmoother.update(
      _pose(timestamp: t0, joints: {BodyJoint.leftHip: _point(0.2)}),
    );
    final twoToThree = twoToThreeSmoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {BodyJoint.leftHip: _point(0.8, z: 0.7)},
      ),
    );
    expect(twoToThree[BodyJoint.leftHip]!.z, 0.7);

    final threeToTwoSmoother = EmaPoseSmoother(config: config);
    threeToTwoSmoother.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftHip: _point(0.2, z: 0.1)},
      ),
    );
    final threeToTwo = threeToTwoSmoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        joints: {BodyJoint.leftHip: _point(0.8)},
      ),
    );
    expect(threeToTwo[BodyJoint.leftHip]!.z, isNull);
  });

  test('current joint and pose confidence are preserved', () {
    final smoother = EmaPoseSmoother();
    smoother.update(
      _pose(
        timestamp: t0,
        confidence: 0.9,
        joints: {
          BodyJoint.leftWrist: _point(0.2, confidence: 0.95),
        },
      ),
    );

    final output = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 60)),
        confidence: 0.55,
        joints: {
          BodyJoint.leftWrist: _point(0.8, confidence: 0.42),
        },
      ),
    );

    expect(output.confidence, 0.55);
    expect(output[BodyJoint.leftWrist]!.confidence, 0.42);
  });

  test('output timestamp always matches the current observation', () {
    final smoother = EmaPoseSmoother();
    smoother.update(
      _pose(timestamp: t0, joints: {BodyJoint.leftWrist: _point(0.2)}),
    );
    final currentTimestamp = t0.add(const Duration(milliseconds: 55));

    final output = smoother.update(
      _pose(
        timestamp: currentTimestamp,
        joints: {BodyJoint.leftWrist: _point(0.8)},
      ),
    );

    expect(output.timestamp, currentTimestamp);
  });

  test('reset makes the next observation a fresh baseline', () {
    final smoother = EmaPoseSmoother();
    smoother.update(
      _pose(timestamp: t0, joints: {BodyJoint.leftWrist: _point(0.2)}),
    );
    smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 60)),
        joints: {BodyJoint.leftWrist: _point(0.8)},
      ),
    );

    smoother.reset();
    final output = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 120)),
        joints: {BodyJoint.leftWrist: _point(0.95)},
      ),
    );

    expect(output[BodyJoint.leftWrist]!.x, 0.95);
  });

  test('irregular intervals give larger dt more weight on current data', () {
    final config = PoseSmoothingConfig(
      timeConstant: const Duration(milliseconds: 120),
    );
    final shortInterval = EmaPoseSmoother(config: config);
    final longInterval = EmaPoseSmoother(config: config);
    final baseline = _pose(
      timestamp: t0,
      joints: {BodyJoint.leftWrist: _point(0.2)},
    );
    shortInterval.update(baseline);
    longInterval.update(baseline);

    final shortOutput = shortInterval.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 55)),
        joints: {BodyJoint.leftWrist: _point(0.8)},
      ),
    );
    final longOutput = longInterval.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 185)),
        joints: {BodyJoint.leftWrist: _point(0.8)},
      ),
    );

    expect(
      shortOutput[BodyJoint.leftWrist]!.x,
      lessThan(longOutput[BodyJoint.leftWrist]!.x),
    );
  });

  test('duplicate timestamps are deterministic and never produce NaN', () {
    final smoother = EmaPoseSmoother();
    smoother.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftWrist: _point(0.2, confidence: 0.9)},
      ),
    );

    final output = smoother.update(
      _pose(
        timestamp: t0,
        joints: {BodyJoint.leftWrist: _point(0.8, confidence: 0.4)},
      ),
    );

    expect(output[BodyJoint.leftWrist]!.x, 0.2);
    expect(output[BodyJoint.leftWrist]!.x.isNaN, isFalse);
    expect(output[BodyJoint.leftWrist]!.confidence, 0.4);
  });

  test('backwards timestamps reset to the current observation', () {
    final smoother = EmaPoseSmoother();
    final later = t0.add(const Duration(milliseconds: 100));
    smoother.update(
      _pose(timestamp: later, joints: {BodyJoint.leftWrist: _point(0.2)}),
    );

    final backwards = smoother.update(
      _pose(timestamp: t0, joints: {BodyJoint.leftWrist: _point(0.9)}),
    );
    expect(backwards[BodyJoint.leftWrist]!.x, 0.9);

    final next = smoother.update(
      _pose(
        timestamp: t0.add(const Duration(milliseconds: 60)),
        joints: {BodyJoint.leftWrist: _point(0.3)},
      ),
    );
    expect(next[BodyJoint.leftWrist]!.x, lessThan(0.9));
    expect(next[BodyJoint.leftWrist]!.x, greaterThan(0.3));
  });
}
