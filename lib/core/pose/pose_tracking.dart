import 'dart:collection';

import 'body_pose.dart';
import 'pose_estimator.dart';

/// Engine-agnostic quality state for realtime pose tracking.
enum PoseTrackingState {
  /// No usable person is currently visible.
  noPerson,

  /// A pose is present, but required supported joints are missing or uncertain.
  partialBody,

  /// A valid pose is visible but has not yet satisfied stabilization time.
  initializing,

  /// Pose quality is sufficient to begin tracking an exercise.
  ready,

  /// A valid pose is being tracked continuously.
  tracking,

  /// Tracking was valid previously but has temporarily degraded.
  lostTracking,
}

/// Per-use-case canonical joint requirements for pose tracking.
///
/// Confidence thresholds are optional overrides of [PoseTrackingConfig].
class PoseTrackingRequirements {
  PoseTrackingRequirements({
    required Set<BodyJoint> requiredJoints,
    this.minJointConfidence,
    this.minPoseConfidence,
  }) : requiredJoints = UnmodifiableSetView(
          Set<BodyJoint>.from(requiredJoints),
        ) {
    _validateOptionalConfidence(minJointConfidence, 'minJointConfidence');
    _validateOptionalConfidence(minPoseConfidence, 'minPoseConfidence');
  }

  factory PoseTrackingRequirements.fullBody() => PoseTrackingRequirements(
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

  final Set<BodyJoint> requiredJoints;
  final double? minJointConfidence;
  final double? minPoseConfidence;
}

/// Centralized thresholds and duration-based hysteresis for pose tracking.
class PoseTrackingConfig {
  PoseTrackingConfig({
    this.minPoseConfidence = 0.5,
    this.minJointConfidence = 0.5,
    this.readyHoldDuration = const Duration(milliseconds: 200),
    this.trackingStartDuration = const Duration(milliseconds: 400),
    this.lostTrackingDelay = const Duration(milliseconds: 250),
    this.noPersonDelay = const Duration(milliseconds: 1000),
    this.recoveryDuration = const Duration(milliseconds: 150),
  }) {
    _validateConfidence(minPoseConfidence, 'minPoseConfidence');
    _validateConfidence(minJointConfidence, 'minJointConfidence');
    _validateDuration(readyHoldDuration, 'readyHoldDuration');
    _validateDuration(trackingStartDuration, 'trackingStartDuration');
    _validateDuration(lostTrackingDelay, 'lostTrackingDelay');
    _validateDuration(noPersonDelay, 'noPersonDelay');
    _validateDuration(recoveryDuration, 'recoveryDuration');
    if (trackingStartDuration < readyHoldDuration) {
      throw ArgumentError.value(
        trackingStartDuration,
        'trackingStartDuration',
        'Must be greater than or equal to readyHoldDuration.',
      );
    }
    if (noPersonDelay < lostTrackingDelay) {
      throw ArgumentError.value(
        noPersonDelay,
        'noPersonDelay',
        'Must be greater than or equal to lostTrackingDelay.',
      );
    }
  }

  final double minPoseConfidence;
  final double minJointConfidence;
  final Duration readyHoldDuration;

  /// Total continuously-valid duration before automatically entering tracking.
  final Duration trackingStartDuration;
  final Duration lostTrackingDelay;
  final Duration noPersonDelay;
  final Duration recoveryDuration;
}

/// Derived tracking quality and diagnostics for one observation timestamp.
class PoseTrackingEvaluation {
  PoseTrackingEvaluation({
    required this.state,
    required this.primaryPose,
    required this.poseConfidence,
    required Set<BodyJoint> missingRequiredJoints,
    required Set<BodyJoint> lowConfidenceJoints,
    required Set<BodyJoint> unsupportedRequiredJoints,
    required this.visibleRequiredJointCount,
    required this.requiredJointCount,
    this.inferenceError = false,
  })  : missingRequiredJoints = UnmodifiableSetView(
          Set<BodyJoint>.from(missingRequiredJoints),
        ),
        lowConfidenceJoints = UnmodifiableSetView(
          Set<BodyJoint>.from(lowConfidenceJoints),
        ),
        unsupportedRequiredJoints = UnmodifiableSetView(
          Set<BodyJoint>.from(unsupportedRequiredJoints),
        );

  final PoseTrackingState state;
  final BodyPose? primaryPose;
  final double poseConfidence;
  final Set<BodyJoint> missingRequiredJoints;
  final Set<BodyJoint> lowConfidenceJoints;
  final Set<BodyJoint> unsupportedRequiredJoints;
  final int visibleRequiredJointCount;

  /// Count of required joints that the current estimator can actually produce.
  final int requiredJointCount;

  /// True when this evaluation was triggered by a pipeline inference failure.
  final bool inferenceError;

  bool get hasCapabilityMismatch => unsupportedRequiredJoints.isNotEmpty;
}

/// Stateful, pure-Dart evaluator for canonical realtime pose observations.
///
/// The evaluator never inspects concrete estimator types. It uses canonical
/// [BodyPose] data plus [PoseEstimatorCapabilities], and all transitions are
/// based on elapsed observation time rather than frame counts.
class PoseTrackingEvaluator {
  PoseTrackingEvaluator({
    PoseTrackingRequirements? requirements,
    PoseTrackingConfig? config,
  })  : requirements = requirements ?? PoseTrackingRequirements.fullBody(),
        config = config ?? PoseTrackingConfig();

  final PoseTrackingRequirements requirements;
  final PoseTrackingConfig config;

  PoseTrackingState _state = PoseTrackingState.noPerson;
  bool _hasTracked = false;
  DateTime? _lastTimestamp;
  DateTime? _validSince;
  DateTime? _invalidSince;
  DateTime? _noPersonSince;
  DateTime? _recoverySince;

  PoseTrackingState get state => _state;

  /// Evaluates a successful pipeline observation.
  PoseTrackingEvaluation evaluate({
    required List<BodyPose> poses,
    required PoseEstimatorCapabilities capabilities,
    required DateTime timestamp,
  }) {
    final effectiveTimestamp = _monotonicTimestamp(timestamp);
    final observation = _observe(poses, capabilities);
    _applyObservation(
      observation: observation,
      timestamp: effectiveTimestamp,
    );
    return _buildEvaluation(observation);
  }

  /// Applies a non-fatal inference failure using the same time hysteresis.
  ///
  /// A transient error therefore does not immediately turn active tracking
  /// into [PoseTrackingState.noPerson].
  PoseTrackingEvaluation evaluateInferenceError({
    required PoseEstimatorCapabilities capabilities,
    required DateTime timestamp,
  }) {
    final effectiveTimestamp = _monotonicTimestamp(timestamp);
    final observation = _PoseObservation.noPose(
      unsupportedRequiredJoints: _unsupportedRequiredJoints(capabilities),
      requiredJointCount: _supportedRequiredJoints(capabilities).length,
      inferenceError: true,
    );
    _applyObservation(
      observation: observation,
      timestamp: effectiveTimestamp,
    );
    return _buildEvaluation(observation);
  }

  void reset() {
    _state = PoseTrackingState.noPerson;
    _hasTracked = false;
    _lastTimestamp = null;
    _validSince = null;
    _invalidSince = null;
    _noPersonSince = null;
    _recoverySince = null;
  }

  _PoseObservation _observe(
    List<BodyPose> poses,
    PoseEstimatorCapabilities capabilities,
  ) {
    final unsupported = _unsupportedRequiredJoints(capabilities);
    final supportedRequired = _supportedRequiredJoints(capabilities);
    final primaryPose = _selectPrimaryPose(poses);
    if (primaryPose == null) {
      return _PoseObservation.noPose(
        unsupportedRequiredJoints: unsupported,
        requiredJointCount: supportedRequired.length,
      );
    }

    final minJointConfidence =
        requirements.minJointConfidence ?? config.minJointConfidence;
    final minPoseConfidence =
        requirements.minPoseConfidence ?? config.minPoseConfidence;
    final missing = <BodyJoint>{};
    final lowConfidence = <BodyJoint>{};

    for (final joint in supportedRequired) {
      final point = primaryPose[joint];
      if (point == null) {
        missing.add(joint);
      } else if (point.confidence < minJointConfidence) {
        lowConfidence.add(joint);
      }
    }

    final visibleRequiredCount =
        supportedRequired.length - missing.length - lowConfidence.length;
    final isValid = primaryPose.confidence >= minPoseConfidence &&
        missing.isEmpty &&
        lowConfidence.isEmpty;

    return _PoseObservation(
      primaryPose: primaryPose,
      poseConfidence: primaryPose.confidence,
      missingRequiredJoints: missing,
      lowConfidenceJoints: lowConfidence,
      unsupportedRequiredJoints: unsupported,
      visibleRequiredJointCount: visibleRequiredCount,
      requiredJointCount: supportedRequired.length,
      isValid: isValid,
      hasPose: true,
    );
  }

  void _applyObservation({
    required _PoseObservation observation,
    required DateTime timestamp,
  }) {
    if (observation.isValid) {
      _applyValidObservation(timestamp);
      return;
    }
    if (observation.hasPose) {
      _applyPartialObservation(timestamp);
      return;
    }
    _applyMissingObservation(timestamp);
  }

  void _applyValidObservation(DateTime timestamp) {
    _invalidSince = null;
    _noPersonSince = null;

    if (_state == PoseTrackingState.lostTracking) {
      _validSince = null;
      _recoverySince ??= timestamp;
      if (_elapsed(_recoverySince!, timestamp) >= config.recoveryDuration) {
        _state = PoseTrackingState.tracking;
        _hasTracked = true;
        _recoverySince = null;
      }
      return;
    }

    _recoverySince = null;
    if (_state == PoseTrackingState.tracking) {
      _hasTracked = true;
      return;
    }

    _validSince ??= timestamp;
    final validFor = _elapsed(_validSince!, timestamp);
    if (validFor >= config.trackingStartDuration) {
      _state = PoseTrackingState.tracking;
      _hasTracked = true;
    } else if (validFor >= config.readyHoldDuration) {
      _state = PoseTrackingState.ready;
    } else {
      _state = PoseTrackingState.initializing;
    }
  }

  void _applyPartialObservation(DateTime timestamp) {
    _validSince = null;
    _recoverySince = null;
    _noPersonSince = null;

    if (_state == PoseTrackingState.tracking ||
        _state == PoseTrackingState.lostTracking) {
      _invalidSince ??= timestamp;
      if (_state == PoseTrackingState.tracking &&
          _elapsed(_invalidSince!, timestamp) < config.lostTrackingDelay) {
        return;
      }
      _state = PoseTrackingState.lostTracking;
      return;
    }

    if (_state == PoseTrackingState.ready) {
      _invalidSince ??= timestamp;
      if (_elapsed(_invalidSince!, timestamp) < config.lostTrackingDelay) {
        return;
      }
    }

    _invalidSince = timestamp;
    _state = PoseTrackingState.partialBody;
  }

  void _applyMissingObservation(DateTime timestamp) {
    _validSince = null;
    _recoverySince = null;
    _noPersonSince ??= timestamp;

    if (_state == PoseTrackingState.noPerson) {
      _invalidSince = null;
      return;
    }

    if (_state == PoseTrackingState.tracking ||
        _state == PoseTrackingState.lostTracking) {
      _invalidSince ??= timestamp;
      if (_state == PoseTrackingState.tracking &&
          _elapsed(_invalidSince!, timestamp) < config.lostTrackingDelay) {
        return;
      }
      if (_elapsed(_noPersonSince!, timestamp) >= config.noPersonDelay) {
        _state = PoseTrackingState.noPerson;
        _hasTracked = false;
        _invalidSince = null;
      } else {
        _state = PoseTrackingState.lostTracking;
      }
      return;
    }

    if (_state == PoseTrackingState.ready) {
      _invalidSince ??= timestamp;
      if (_elapsed(_invalidSince!, timestamp) < config.lostTrackingDelay) {
        return;
      }
    }

    if (_elapsed(_noPersonSince!, timestamp) >= config.noPersonDelay ||
        !_hasTracked) {
      _state = PoseTrackingState.noPerson;
      _hasTracked = false;
      _invalidSince = null;
    }
  }

  PoseTrackingEvaluation _buildEvaluation(_PoseObservation observation) =>
      PoseTrackingEvaluation(
        state: _state,
        primaryPose: observation.primaryPose,
        poseConfidence: observation.poseConfidence,
        missingRequiredJoints: observation.missingRequiredJoints,
        lowConfidenceJoints: observation.lowConfidenceJoints,
        unsupportedRequiredJoints: observation.unsupportedRequiredJoints,
        visibleRequiredJointCount: observation.visibleRequiredJointCount,
        requiredJointCount: observation.requiredJointCount,
        inferenceError: observation.inferenceError,
      );

  Set<BodyJoint> _supportedRequiredJoints(
    PoseEstimatorCapabilities capabilities,
  ) =>
      requirements.requiredJoints
          .where(capabilities.supportsJoint)
          .toSet();

  Set<BodyJoint> _unsupportedRequiredJoints(
    PoseEstimatorCapabilities capabilities,
  ) =>
      requirements.requiredJoints
          .where((joint) => !capabilities.supportsJoint(joint))
          .toSet();

  DateTime _monotonicTimestamp(DateTime timestamp) {
    final previous = _lastTimestamp;
    if (previous == null || !timestamp.isBefore(previous)) {
      _lastTimestamp = timestamp;
      return timestamp;
    }
    return previous;
  }

  static Duration _elapsed(DateTime start, DateTime end) =>
      end.difference(start);

  static BodyPose? _selectPrimaryPose(List<BodyPose> poses) {
    BodyPose? selected;
    for (final pose in poses) {
      if (selected == null || pose.confidence > selected.confidence) {
        selected = pose;
      }
    }
    return selected;
  }
}

class _PoseObservation {
  const _PoseObservation({
    required this.primaryPose,
    required this.poseConfidence,
    required this.missingRequiredJoints,
    required this.lowConfidenceJoints,
    required this.unsupportedRequiredJoints,
    required this.visibleRequiredJointCount,
    required this.requiredJointCount,
    required this.isValid,
    required this.hasPose,
    this.inferenceError = false,
  });

  factory _PoseObservation.noPose({
    required Set<BodyJoint> unsupportedRequiredJoints,
    required int requiredJointCount,
    bool inferenceError = false,
  }) =>
      _PoseObservation(
        primaryPose: null,
        poseConfidence: 0,
        missingRequiredJoints: const {},
        lowConfidenceJoints: const {},
        unsupportedRequiredJoints: unsupportedRequiredJoints,
        visibleRequiredJointCount: 0,
        requiredJointCount: requiredJointCount,
        isValid: false,
        hasPose: false,
        inferenceError: inferenceError,
      );

  final BodyPose? primaryPose;
  final double poseConfidence;
  final Set<BodyJoint> missingRequiredJoints;
  final Set<BodyJoint> lowConfidenceJoints;
  final Set<BodyJoint> unsupportedRequiredJoints;
  final int visibleRequiredJointCount;
  final int requiredJointCount;
  final bool isValid;
  final bool hasPose;
  final bool inferenceError;
}

void _validateConfidence(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name, 'Must be finite and between 0 and 1.');
  }
}

void _validateOptionalConfidence(double? value, String name) {
  if (value != null) _validateConfidence(value, name);
}

void _validateDuration(Duration value, String name) {
  if (value.isNegative) {
    throw ArgumentError.value(value, name, 'Must not be negative.');
  }
}
