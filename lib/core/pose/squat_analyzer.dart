import 'exercise_analysis.dart';
import 'pose_features.dart';

/// Stable generic state IDs used by [SquatExerciseAnalyzer].
class SquatExerciseStates {
  const SquatExerciseStates._();

  static const unknown = ExerciseState(id: 'unknown', label: 'Unknown');
  static const standing = ExerciseState(id: 'standing', label: 'Standing');
  static const descending = ExerciseState(
    id: 'descending',
    label: 'Descending',
  );
  static const bottom = ExerciseState(id: 'bottom', label: 'Bottom');
  static const ascending = ExerciseState(id: 'ascending', label: 'Ascending');
}

/// Tunable thresholds for the first squat-specific state machine.
///
/// Angles are in degrees and come from PR9's canonical [PoseFeatures]. The
/// analyzer deliberately consumes only presentation-independent feature data.
class SquatAnalyzerConfig {
  const SquatAnalyzerConfig({
    this.standingKneeAngle = 160,
    this.bottomKneeAngle = 105,
    this.kneeAngleDeltaEpsilon = 3,
    this.maxTorsoInclinationAngle = 35,
    this.kneeAsymmetryWarningAngle = 20,
  })  : assert(standingKneeAngle > bottomKneeAngle),
        assert(kneeAngleDeltaEpsilon >= 0),
        assert(maxTorsoInclinationAngle >= 0),
        assert(kneeAsymmetryWarningAngle >= 0);

  /// Average knee angle at or above this value is treated as standing.
  final double standingKneeAngle;

  /// Average knee angle at or below this value is treated as squat bottom.
  final double bottomKneeAngle;

  /// Minimum knee-angle change used to infer up/down motion when PR9 movement
  /// direction is stable or unknown.
  final double kneeAngleDeltaEpsilon;

  /// Torso inclination above this absolute value emits a generic form cue.
  final double maxTorsoInclinationAngle;

  /// Left/right knee-angle difference above this value emits a symmetry cue.
  final double kneeAsymmetryWarningAngle;
}

/// First concrete exercise analyzer: a deterministic squat state machine.
///
/// It consumes only canonical [PoseFeatures]. It does not import estimator,
/// camera, renderer, Flutter widget, workout UI, or TTS code.
class SquatExerciseAnalyzer implements ExerciseAnalyzer {
  const SquatExerciseAnalyzer({this.config = const SquatAnalyzerConfig()});

  static const id = 'squat';

  final SquatAnalyzerConfig config;

  @override
  String get exerciseId => id;

  @override
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  }) {
    final previous = _previousSquatAnalysis(previousAnalysis);
    final previousState = previous?.state ?? SquatExerciseStates.unknown;
    final repetitionCount = previous?.repetitionCount ?? 0;
    final kneeAngle = _averageKneeAngle(features);

    if (kneeAngle == null || features.normalizedHipY == null) {
      final state = SquatExerciseStates.unknown;
      return ExerciseAnalysis(
        exerciseId: exerciseId,
        state: state,
        timestamp: features.timestamp,
        confidence: 0.2,
        repetitionCount: repetitionCount,
        events: _stateEvents(previousState, state, features.timestamp),
        feedback: [
          ExerciseFeedback(
            code: 'squat_features_unavailable',
            message: 'Squat analyzer needs both knee angles and hip position.',
            severity: ExerciseFeedbackSeverity.warning,
            timestamp: features.timestamp,
          ),
        ],
      );
    }

    final movement = _effectiveMovement(features, previousFeatures);
    final state = _nextState(
      kneeAngle: kneeAngle,
      movement: movement,
      previousState: previousState,
    );
    var nextRepetitionCount = repetitionCount;
    final events = <ExerciseEvent>[
      ..._stateEvents(previousState, state, features.timestamp),
    ];

    if (_isState(previousState, SquatExerciseStates.ascending) &&
        _isState(state, SquatExerciseStates.standing)) {
      nextRepetitionCount++;
      events.add(
        ExerciseEvent(
          type: ExerciseEventType.repetitionCompleted,
          timestamp: features.timestamp,
          code: 'squat_repetition_completed',
          currentState: state,
          repetitionCount: nextRepetitionCount,
          message: 'Squat repetition completed.',
        ),
      );
    }

    final feedback = _feedback(features);
    if (!_sameFeedbackCodes(previous?.feedback.map((item) => item.code),
        feedback.map((item) => item.code))) {
      events.add(
        ExerciseEvent(
          type: ExerciseEventType.feedbackChanged,
          timestamp: features.timestamp,
          code: 'squat_feedback_changed',
          currentState: state,
        ),
      );
    }

    return ExerciseAnalysis(
      exerciseId: exerciseId,
      state: state,
      timestamp: features.timestamp,
      confidence: feedback.isEmpty ? 0.9 : 0.75,
      repetitionCount: nextRepetitionCount,
      events: events,
      feedback: feedback,
    );
  }

  @override
  void reset() {}

  ExerciseAnalysis? _previousSquatAnalysis(ExerciseAnalysis? analysis) {
    if (analysis == null || analysis.exerciseId != exerciseId) return null;
    return analysis;
  }

  ExerciseState _nextState({
    required double kneeAngle,
    required PoseMovementDirection movement,
    required ExerciseState previousState,
  }) {
    if (kneeAngle >= config.standingKneeAngle) {
      return SquatExerciseStates.standing;
    }
    if (kneeAngle <= config.bottomKneeAngle) {
      return SquatExerciseStates.bottom;
    }

    if (_isState(previousState, SquatExerciseStates.bottom) &&
        movement == PoseMovementDirection.up) {
      return SquatExerciseStates.ascending;
    }
    if (_isState(previousState, SquatExerciseStates.ascending)) {
      if (movement == PoseMovementDirection.down) {
        return SquatExerciseStates.descending;
      }
      return SquatExerciseStates.ascending;
    }
    if (_isState(previousState, SquatExerciseStates.descending)) {
      return SquatExerciseStates.descending;
    }
    if (_isState(previousState, SquatExerciseStates.standing) &&
        movement == PoseMovementDirection.down) {
      return SquatExerciseStates.descending;
    }
    if (movement == PoseMovementDirection.down) {
      return SquatExerciseStates.descending;
    }

    return SquatExerciseStates.unknown;
  }

  PoseMovementDirection _effectiveMovement(
    PoseFeatures features,
    PoseFeatures? previousFeatures,
  ) {
    if (features.verticalMovement == PoseMovementDirection.up ||
        features.verticalMovement == PoseMovementDirection.down) {
      return features.verticalMovement;
    }

    final previousKneeAngle = previousFeatures == null
        ? null
        : _averageKneeAngle(previousFeatures);
    final currentKneeAngle = _averageKneeAngle(features);
    if (previousKneeAngle == null || currentKneeAngle == null) {
      return features.verticalMovement;
    }

    final delta = currentKneeAngle - previousKneeAngle;
    if (delta > config.kneeAngleDeltaEpsilon) {
      return PoseMovementDirection.up;
    }
    if (delta < -config.kneeAngleDeltaEpsilon) {
      return PoseMovementDirection.down;
    }
    return features.verticalMovement;
  }

  double? _averageKneeAngle(PoseFeatures features) {
    final left = features.leftKneeAngle;
    final right = features.rightKneeAngle;
    if (left == null || right == null) return null;
    if (!left.isFinite || !right.isFinite) return null;
    return (left + right) / 2;
  }

  List<ExerciseEvent> _stateEvents(
    ExerciseState previousState,
    ExerciseState state,
    DateTime timestamp,
  ) {
    if (_isState(previousState, state)) return const [];
    return [
      ExerciseEvent(
        type: ExerciseEventType.stateChanged,
        timestamp: timestamp,
        code: 'squat_state_changed',
        previousState: previousState,
        currentState: state,
        message: 'Squat state changed to ${state.label ?? state.id}.',
      ),
    ];
  }

  List<ExerciseFeedback> _feedback(PoseFeatures features) {
    final feedback = <ExerciseFeedback>[];
    final torso = features.torsoInclinationAngle?.abs();
    if (torso != null && torso > config.maxTorsoInclinationAngle) {
      feedback.add(
        ExerciseFeedback(
          code: 'squat_torso_lean',
          message: 'Keep your torso more upright during the squat.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: features.timestamp,
        ),
      );
    }

    final kneeAsymmetry = _kneeAsymmetry(features);
    if (kneeAsymmetry != null &&
        kneeAsymmetry > config.kneeAsymmetryWarningAngle) {
      feedback.add(
        ExerciseFeedback(
          code: 'squat_knee_asymmetry',
          message: 'Keep both knees moving evenly.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: features.timestamp,
        ),
      );
    }
    return feedback;
  }

  double? _kneeAsymmetry(PoseFeatures features) {
    final left = features.leftKneeAngle;
    final right = features.rightKneeAngle;
    if (left == null || right == null) return null;
    if (!left.isFinite || !right.isFinite) return null;
    return (left - right).abs();
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
