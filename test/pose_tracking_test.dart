import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

final _allCapabilities = PoseEstimatorCapabilities(
  supportedJoints: BodyJoint.values.toSet(),
  maxPoseCount: 4,
);

final _requirements = PoseTrackingRequirements(
  requiredJoints: const {
    BodyJoint.leftShoulder,
    BodyJoint.rightShoulder,
    BodyJoint.leftHip,
    BodyJoint.rightHip,
    BodyJoint.leftKnee,
    BodyJoint.rightKnee,
    BodyJoint.leftAnkle,
    BodyJoint.rightAnkle,
  },
);

PoseTrackingEvaluator _evaluator() => PoseTrackingEvaluator(
      requirements: _requirements,
      config: PoseTrackingConfig(),
    );

BodyPose _pose({
  required DateTime timestamp,
  Set<BodyJoint>? joints,
  Set<BodyJoint> lowConfidenceJoints = const {},
  double poseConfidence = 0.9,
}) {
  final included = joints ?? _requirements.requiredJoints;
  return BodyPose(
    joints: {
      for (final joint in included)
        joint: PosePoint(
          x: 0.5,
          y: 0.5,
          confidence: lowConfidenceJoints.contains(joint) ? 0.2 : 0.9,
        ),
    },
    timestamp: timestamp,
    confidence: poseConfidence,
  );
}

PoseTrackingEvaluation _validAt(
  PoseTrackingEvaluator evaluator,
  DateTime timestamp,
) =>
    evaluator.evaluate(
      poses: [_pose(timestamp: timestamp)],
      capabilities: _allCapabilities,
      timestamp: timestamp,
    );

void main() {
  final t0 = DateTime.utc(2026, 9, 10, 12);

  group('PoseTrackingEvaluator quality', () {
    test('starts with noPerson when no pose is visible', () {
      final evaluator = _evaluator();

      final result = evaluator.evaluate(
        poses: const [],
        capabilities: _allCapabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.noPerson);
      expect(result.primaryPose, isNull);
      expect(result.visibleRequiredJointCount, 0);
    });

    test('reports partialBody and missing required joints', () {
      final evaluator = _evaluator();
      final pose = _pose(
        timestamp: t0,
        joints: const {
          BodyJoint.leftShoulder,
          BodyJoint.rightShoulder,
          BodyJoint.leftHip,
          BodyJoint.rightHip,
        },
      );

      final result = evaluator.evaluate(
        poses: [pose],
        capabilities: _allCapabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.partialBody);
      expect(result.visibleRequiredJointCount, 4);
      expect(result.requiredJointCount, 8);
      expect(
        result.missingRequiredJoints,
        containsAll({
          BodyJoint.leftKnee,
          BodyJoint.rightKnee,
          BodyJoint.leftAnkle,
          BodyJoint.rightAnkle,
        }),
      );
    });

    test('treats low-confidence required joints as partialBody', () {
      final evaluator = _evaluator();
      final pose = _pose(
        timestamp: t0,
        lowConfidenceJoints: const {BodyJoint.leftKnee},
      );

      final result = evaluator.evaluate(
        poses: [pose],
        capabilities: _allCapabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.partialBody);
      expect(result.lowConfidenceJoints, {BodyJoint.leftKnee});
      expect(result.missingRequiredJoints, isEmpty);
    });

    test('uses pose-level confidence separately from joint confidence', () {
      final evaluator = _evaluator();

      final result = evaluator.evaluate(
        poses: [_pose(timestamp: t0, poseConfidence: 0.3)],
        capabilities: _allCapabilities,
        timestamp: t0,
      );

      expect(result.state, PoseTrackingState.partialBody);
      expect(result.lowConfidenceJoints, isEmpty);
      expect(result.poseConfidence, 0.3);
    });

    test('reports unsupported requirements separately from missing joints', () {
      final requirements = PoseTrackingRequirements(
        requiredJoints: const {
          BodyJoint.leftShoulder,
          BodyJoint.neck,
        },
      );
      final evaluator = PoseTrackingEvaluator(requirements: requirements);
      final capabilities = PoseEstimatorCapabilities(
        supportedJoints: {BodyJoint.leftShoulder},
      );
      final pose = BodyPose(
        joints: {
          BodyJoint.leftShoulder: const PosePoint(
            x: 0.4,
            y: 0.3,
            confidence: 0.9,
          ),
        },
        timestamp: t0,
        confidence: 0.9,
      );

      final result = evaluator.evaluate(
        poses: [pose],
        capabilities: capabilities,
        timestamp: t0,
      );

      expect(result.unsupportedRequiredJoints, {BodyJoint.neck});
      expect(result.hasCapabilityMismatch, isTrue);
      expect(result.missingRequiredJoints, isEmpty);
      expect(result.requiredJointCount, 1);
      expect(result.state, PoseTrackingState.initializing);
    });

    test('selects highest-confidence primary pose deterministically', () {
      final evaluator = _evaluator();
      final low = _pose(timestamp: t0, poseConfidence: 0.7);
      final high = _pose(timestamp: t0, poseConfidence: 0.95);

      final result = evaluator.evaluate(
        poses: [low, high],
        capabilities: _allCapabilities,
        timestamp: t0,
      );

      expect(result.primaryPose, same(high));

      evaluator.reset();
      final firstTie = _pose(timestamp: t0, poseConfidence: 0.9);
      final secondTie = _pose(timestamp: t0, poseConfidence: 0.9);
      final tieResult = evaluator.evaluate(
        poses: [firstTie, secondTie],
        capabilities: _allCapabilities,
        timestamp: t0,
      );
      expect(tieResult.primaryPose, same(firstTie));
    });
  });

  group('PoseTrackingEvaluator hysteresis', () {
    test('enters ready only after the stabilization duration', () {
      final evaluator = _evaluator();

      expect(_validAt(evaluator, t0).state, PoseTrackingState.initializing);
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 199))).state,
        PoseTrackingState.initializing,
      );
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 200))).state,
        PoseTrackingState.ready,
      );
    });

    test('automatically advances from ready to tracking', () {
      final evaluator = _evaluator();

      _validAt(evaluator, t0);
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 200))).state,
        PoseTrackingState.ready,
      );
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 400))).state,
        PoseTrackingState.tracking,
      );
    });

    test('short confidence drop does not leave tracking', () {
      final evaluator = _evaluator();
      _validAt(evaluator, t0);
      _validAt(evaluator, t0.add(const Duration(milliseconds: 400)));

      final badAt500 = evaluator.evaluate(
        poses: [
          _pose(
            timestamp: t0.add(const Duration(milliseconds: 500)),
            lowConfidenceJoints: const {BodyJoint.leftKnee},
          ),
        ],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );
      expect(badAt500.state, PoseTrackingState.tracking);

      final recovered = _validAt(
        evaluator,
        t0.add(const Duration(milliseconds: 700)),
      );
      expect(recovered.state, PoseTrackingState.tracking);
    });

    test('enters lostTracking after invalid pose persists', () {
      final evaluator = _evaluator();
      _validAt(evaluator, t0);
      _validAt(evaluator, t0.add(const Duration(milliseconds: 400)));

      evaluator.evaluate(
        poses: [
          _pose(
            timestamp: t0.add(const Duration(milliseconds: 500)),
            lowConfidenceJoints: const {BodyJoint.leftKnee},
          ),
        ],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );
      final lost = evaluator.evaluate(
        poses: [
          _pose(
            timestamp: t0.add(const Duration(milliseconds: 750)),
            lowConfidenceJoints: const {BodyJoint.leftKnee},
          ),
        ],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 750)),
      );

      expect(lost.state, PoseTrackingState.lostTracking);
    });

    test('recovers from lostTracking only after recovery duration', () {
      final evaluator = _evaluator();
      _validAt(evaluator, t0);
      _validAt(evaluator, t0.add(const Duration(milliseconds: 400)));
      evaluator.evaluate(
        poses: const [],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );
      evaluator.evaluate(
        poses: const [],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 750)),
      );

      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 800))).state,
        PoseTrackingState.lostTracking,
      );
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 949))).state,
        PoseTrackingState.lostTracking,
      );
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 950))).state,
        PoseTrackingState.tracking,
      );
    });

    test('falls from lostTracking to noPerson after extended absence', () {
      final evaluator = _evaluator();
      _validAt(evaluator, t0);
      _validAt(evaluator, t0.add(const Duration(milliseconds: 400)));

      evaluator.evaluate(
        poses: const [],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );
      final lost = evaluator.evaluate(
        poses: const [],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 750)),
      );
      expect(lost.state, PoseTrackingState.lostTracking);

      final absent = evaluator.evaluate(
        poses: const [],
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 1500)),
      );
      expect(absent.state, PoseTrackingState.noPerson);
    });

    test('temporary inference error uses hysteresis instead of failing closed', () {
      final evaluator = _evaluator();
      _validAt(evaluator, t0);
      _validAt(evaluator, t0.add(const Duration(milliseconds: 400)));

      final errorResult = evaluator.evaluateInferenceError(
        capabilities: _allCapabilities,
        timestamp: t0.add(const Duration(milliseconds: 500)),
      );
      expect(errorResult.inferenceError, isTrue);
      expect(errorResult.state, PoseTrackingState.tracking);

      final recovered = _validAt(
        evaluator,
        t0.add(const Duration(milliseconds: 600)),
      );
      expect(recovered.state, PoseTrackingState.tracking);
    });

    test('irregular timestamps drive transitions by duration, not frame count', () {
      final evaluator = _evaluator();

      expect(_validAt(evaluator, t0).state, PoseTrackingState.initializing);
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 137))).state,
        PoseTrackingState.initializing,
      );
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 215))).state,
        PoseTrackingState.ready,
      );
      expect(
        _validAt(evaluator, t0.add(const Duration(milliseconds: 409))).state,
        PoseTrackingState.tracking,
      );
    });
  });
}
