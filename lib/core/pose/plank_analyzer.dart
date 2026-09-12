import 'exercise_analysis.dart';
import 'pose_features.dart';

/// Stable generic state IDs used by [PlankExerciseAnalyzer].
class PlankExerciseStates {
  const PlankExerciseStates._();

  static const unknown = ExerciseState(id: 'unknown', label: 'Unknown');
  static const holding = ExerciseState(id: 'holding', label: 'Holding');
  static const broken = ExerciseState(id: 'broken', label: 'Broken');
}

/// Tunable thresholds for high-plank form detection.
///
/// The analyzer uses only canonical [PoseFeatures]. It is deliberately tolerant
/// because live camera framing, side visibility, and model confidence can vary.
class PlankAnalyzerConfig {
  const PlankAnalyzerConfig({
    this.minTorsoInclinationAngle = 55,
    this.maxTorsoInclinationAngle = 125,
    this.maxHipShoulderYOffsetRatio = 0.35,
    this.minStraightElbowAngle = 145,
  })  : assert(minTorsoInclinationAngle >= 0),
        assert(maxTorsoInclinationAngle <= 180),
        assert(minTorsoInclinationAngle < maxTorsoInclinationAngle),
        assert(maxHipShoulderYOffsetRatio >= 0),
        assert(minStraightElbowAngle >= 0 && minStraightElbowAngle <= 180);

  /// A side-view plank should be close to horizontal in torso-inclination space.
  final double minTorsoInclinationAngle;
  final double maxTorsoInclinationAngle;

  /// Maximum shoulder/hip vertical offset normalized by [PoseFeatures.bodyScale].
  final double maxHipShoulderYOffsetRatio;

  /// Elbow angle below this value emits an arm-extension cue when elbows are visible.
  final double minStraightElbowAngle;
}

/// Deterministic high-plank analyzer.
///
/// This first plank analyzer detects whether the user appears to be holding a
/// side-view high plank. It does not count repetitions and does not depend on
/// camera, renderer, Flutter UI, or TTS code.
class PlankExerciseAnalyzer implements ExerciseAnalyzer {
  const PlankExerciseAnalyzer({this.config = const PlankAnalyzerConfig()});

  static const id = 'plank';

  final PlankAnalyzerConfig config;

  @override
  String get exerciseId => id;

  @override
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  }) {
    final previous = _previousPlankAnalysis(previousAnalysis);
    final previousState = previous?.state ?? PlankExerciseStates.unknown;

    if (!_hasRequiredFeatures(features)) {
      final state = PlankExerciseStates.unknown;
      return ExerciseAnalysis(
        exerciseId: exerciseId,
        state: state,
        timestamp: features.timestamp,
        confidence: 0.2,
        repetitionCount: 0,
        events: _events(previousState, state, features.timestamp, const [
          'plank_features_unavailable',
        ], previous),
        feedback: [
          ExerciseFeedback(
            code: 'plank_features_unavailable',
            message: 'Plank analyzer needs torso angle, shoulder height, hip height, and body scale.',
            severity: ExerciseFeedbackSeverity.warning,
            timestamp: features.timestamp,
          ),
        ],
      );
    }

    final feedback = _feedback(features);
    final state = feedback.any((item) => item.code == 'plank_body_not_aligned')
        ? PlankExerciseStates.broken
        : PlankExerciseStates.holding;

    return ExerciseAnalysis(
      exerciseId: exerciseId,
      state: state,
      timestamp: features.timestamp,
      confidence: state == PlankExerciseStates.holding && feedback.isEmpty
          ? 0.85
          : 0.6,
      repetitionCount: 0,
      events: _events(
        previousState,
        state,
        features.timestamp,
        feedback.map((item) => item.code),
        previous,
      ),
      feedback: feedback,
    );
  }

  @override
  void reset() {}

  ExerciseAnalysis? _previousPlankAnalysis(ExerciseAnalysis? analysis) {
    if (analysis == null || analysis.exerciseId != exerciseId) return null;
    return analysis;
  }

  bool _hasRequiredFeatures(PoseFeatures features) =>
      features.torsoInclinationAngle != null &&
      features.normalizedShoulderY != null &&
      features.normalizedHipY != null &&
      features.bodyScale != null &&
      features.bodyScale! > 0;

  List<ExerciseFeedback> _feedback(PoseFeatures features) {
    final feedback = <ExerciseFeedback>[];
    final timestamp = features.timestamp;
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
          code: 'plank_body_not_aligned',
          message: 'Keep shoulders and hips in one straight plank line.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: timestamp,
        ),
      );
    }

    final elbowAngle = _averageVisibleElbowAngle(features);
    if (elbowAngle != null && elbowAngle < config.minStraightElbowAngle) {
      feedback.add(
        ExerciseFeedback(
          code: 'plank_arms_not_extended',
          message: 'Press the floor away and keep your arms straighter.',
          severity: ExerciseFeedbackSeverity.cue,
          timestamp: timestamp,
        ),
      );
    }

    return feedback;
  }

  double? _averageVisibleElbowAngle(PoseFeatures features) {
    final values = <double>[
      if (features.leftElbowAngle case final value? when value.isFinite) value,
      if (features.rightElbowAngle case final value? when value.isFinite) value,
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
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
          code: 'plank_state_changed',
          previousState: previousState,
          currentState: state,
          message: 'Plank state changed to ${state.label ?? state.id}.',
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
          code: 'plank_feedback_changed',
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
