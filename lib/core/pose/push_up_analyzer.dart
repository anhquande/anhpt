import 'exercise_analysis.dart';
import 'pose_features.dart';

/// Stable generic state IDs used by [PushUpExerciseAnalyzer].
class PushUpExerciseStates {
  const PushUpExerciseStates._();

  static const unknown = ExerciseState(id: 'unknown', label: 'Unknown');
  static const up = ExerciseState(id: 'up', label: 'Up');
  static const descending = ExerciseState(id: 'descending', label: 'Descending');
  static const bottom = ExerciseState(id: 'bottom', label: 'Bottom');
  static const ascending = ExerciseState(id: 'ascending', label: 'Ascending');
}

/// Tunable thresholds for side-view push-up detection.
class PushUpAnalyzerConfig {
  const PushUpAnalyzerConfig({
    this.upElbowAngle = 155,
    this.bottomElbowAngle = 100,
    this.elbowAngleDeltaEpsilon = 3,
    this.minTorsoInclinationAngle = 55,
    this.maxTorsoInclinationAngle = 125,
    this.maxHipShoulderYOffsetRatio = 0.35,
    this.elbowAsymmetryWarningAngle = 20,
  })  : assert(upElbowAngle > bottomElbowAngle),
        assert(elbowAngleDeltaEpsilon >= 0),
        assert(minTorsoInclinationAngle >= 0),
        assert(maxTorsoInclinationAngle <= 180),
        assert(minTorsoInclinationAngle < maxTorsoInclinationAngle),
        assert(maxHipShoulderYOffsetRatio >= 0),
        assert(elbowAsymmetryWarningAngle >= 0);

  final double upElbowAngle;
  final double bottomElbowAngle;
  final double elbowAngleDeltaEpsilon;
  final double minTorsoInclinationAngle;
  final double maxTorsoInclinationAngle;
  final double maxHipShoulderYOffsetRatio;
  final double elbowAsymmetryWarningAngle;
}

/// Deterministic push-up analyzer using canonical pose features only.
///
/// A repetition is completed when the analyzer observes a bottom phase, then
/// ascends and returns to the extended-arm [PushUpExerciseStates.up] state.
class PushUpExerciseAnalyzer implements ExerciseAnalyzer {
  const PushUpExerciseAnalyzer({this.config = const PushUpAnalyzerConfig()});

  static const id = 'push-up';

  final PushUpAnalyzerConfig config;

  @override
  String get exerciseId => id;

  @override
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  }) {
    final previous = _previousPushUpAnalysis(previousAnalysis);
    final previousState = previous?.state ?? PushUpExerciseStates.unknown;
    final repetitionCount = previous?.repetitionCount ?? 0;
    final elbowAngle = _averageElbowAngle(features);

    if (elbowAngle == null || !_hasAlignmentFeatures(features)) {
      final state = PushUpExerciseStates.unknown;
      return ExerciseAnalysis(
        exerciseId: exerciseId,
        state: state,
        timestamp: features.timestamp,
        confidence: 0.2,
        repetitionCount: repetitionCount,
        events: _events(
          previousState,
          state,
          features.timestamp,
          const ['push_up_features_unavailable'],
          previous,
        ),
        feedback: [
          ExerciseFeedback(
            code: 'push_up_features_unavailable',
            message:
                'Push-up analyzer needs both elbow angles, torso angle, shoulder height, hip height, and body scale.',
            severity: ExerciseFeedbackSeverity.warning,
            timestamp: features.timestamp,
          ),
        ],
      );
    }

    final state = _nextState(
      elbowAngle: elbowAngle,
      previousElbowAngle: previousFeatures == null
          ? null
          : _averageElbowAngle(previousFeatures),
      previousState: previousState,
    );

    var nextRepetitionCount = repetitionCount;
    final feedback = _feedback(features);
    final events = _events(
      previousState,
      state,
      features.timestamp,
      feedback.map((item) => item.code),
      previous,
    );

    if (_isState(previousState, PushUpExerciseStates.ascending) &&
        _isState(state, PushUpExerciseStates.up)) {
      nextRepetitionCount++;
      events.add(
        ExerciseEvent(
          type: ExerciseEventType.repetitionCompleted,
          timestamp: features.timestamp,
          code: 'push_up_repetition_completed',
          currentState: state,
          repetitionCount: nextRepetitionCount,
          message: 'Push-up repetition completed.',
        ),
      );
    }

    return ExerciseAnalysis(
      exerciseId: exerciseId,
      state: state,
      timestamp: features.timestamp,
      confidence: feedback.isEmpty ? 0.9 : 0.7,
      repetitionCount: nextRepetitionCount,
      events: events,
      feedback: feedback,
    );
  }

  @override
  void reset() {}

  ExerciseAnalysis? _previousPushUpAnalysis(ExerciseAnalysis? analysis) {
    if (analysis == null || analysis.exerciseId != exerciseId) return null;
    return analysis;
  }

  bool _hasAlignmentFeatures(PoseFeatures features) =>
      features.torsoInclinationAngle != null &&
      features.normalizedShoulderY != null &&
      features.normalizedHipY != null &&
      features.bodyScale != null &&
      features.bodyScale! > 0;

  ExerciseState _nextState({
    required double elbowAngle,
    required double? previousElbowAngle,
    required ExerciseState previousState,
  }) {
    if (elbowAngle >= config.upElbowAngle) {
      return PushUpExerciseStates.up;
    }
    if (elbowAngle <= config.bottomElbowAngle) {
      return PushUpExerciseStates.bottom;
    }

    final delta = previousElbowAngle == null
        ? 0.0
        : elbowAngle - previousElbowAngle;
    if (_isState(previousState, PushUpExerciseStates.bottom) &&
        delta > config.elbowAngleDeltaEpsilon) {
      return PushUpExerciseStates.ascending;
    }
    if (_isState(previousState, PushUpExerciseStates.ascending)) {
      if (delta < -config.elbowAngleDeltaEpsilon) {
        return PushUpExerciseStates.descending;
      }
      return PushUpExerciseStates.ascending;
    }
    if (_isState(previousState, PushUpExerciseStates.descending)) {
      return PushUpExerciseStates.descending;
    }
    if (_isState(previousState, PushUpExerciseStates.up) &&
        delta < -config.elbowAngleDeltaEpsilon) {
      return PushUpExerciseStates.descending;
    }
    if (delta < -config.elbowAngleDeltaEpsilon) {
      return PushUpExerciseStates.descending;
    }
    if (delta > config.elbowAngleDeltaEpsilon) {
      return PushUpExerciseStates.ascending;
    }
    return PushUpExerciseStates.unknown;
  }

  double? _averageElbowAngle(PoseFeatures features) {
    final left = features.leftElbowAngle;
    final right = features.rightElbowAngle;
    if (left == null || right == null) return null;
    if (!left.isFinite || !right.isFinite) return null;
    return (left + right) / 2;
  }

  List<ExerciseFeedback> _feedback(PoseFeatures features) {
    final feedback = <ExerciseFeedback>[];
    final torsoAngle = features.torsoInclinationAngle?.abs();
    final bodyScale = features.bodyScale;
    final shoulderY = features.normalizedShoulderY;
    final hipY = features.normalizedHipY;

    if (torsoAngle == null ||
        torsoAngle < config.minTorsoInclinationAngle ||
        torsoAngle > config.maxTorsoInclinationAngle ||
        bodyScale == null ||
        shoulderY == null ||
        hipY == null ||
        ((hipY - shoulderY).abs() / bodyScale) >
            config.maxHipShoulderYOffsetRatio) {
      feedback.add(
        ExerciseFeedback(
          code: 'push_up_body_not_aligned',
          message: 'Keep shoulders and hips in one straight line.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: features.timestamp,
        ),
      );
    }

    final asymmetry = _elbowAsymmetry(features);
    if (asymmetry != null &&
        asymmetry > config.elbowAsymmetryWarningAngle) {
      feedback.add(
        ExerciseFeedback(
          code: 'push_up_elbow_asymmetry',
          message: 'Bend and extend both elbows evenly.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: features.timestamp,
        ),
      );
    }
    return feedback;
  }

  double? _elbowAsymmetry(PoseFeatures features) {
    final left = features.leftElbowAngle;
    final right = features.rightElbowAngle;
    if (left == null || right == null) return null;
    if (!left.isFinite || !right.isFinite) return null;
    return (left - right).abs();
  }

  List<ExerciseEvent> _events(
    ExerciseState previousState,
    ExerciseState state,
    DateTime timestamp,
    Iterable<String> feedbackCodes,
    ExerciseAnalysis? previous,
  ) {
    final events = <ExerciseEvent>[];
    if (!_isState(previousState, state)) {
      events.add(
        ExerciseEvent(
          type: ExerciseEventType.stateChanged,
          timestamp: timestamp,
          code: 'push_up_state_changed',
          previousState: previousState,
          currentState: state,
          message: 'Push-up state changed to ${state.label ?? state.id}.',
        ),
      );
    }

    if (!_sameFeedbackCodes(
      previous?.feedback.map((item) => item.code),
      feedbackCodes,
    )) {
      events.add(
        ExerciseEvent(
          type: ExerciseEventType.feedbackChanged,
          timestamp: timestamp,
          code: 'push_up_feedback_changed',
          currentState: state,
        ),
      );
    }
    return events;
  }

  bool _sameFeedbackCodes(Iterable<String>? previous, Iterable<String> current) {
    final previousSet = {...?previous};
    final currentSet = {...current};
    if (previousSet.length != currentSet.length) return false;
    return previousSet.every(currentSet.contains);
  }

  bool _isState(ExerciseState? state, ExerciseState expected) =>
      state?.id == expected.id;
}
