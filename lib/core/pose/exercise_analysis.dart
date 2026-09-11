import 'dart:collection';

import 'pose_features.dart';

/// Generic exercise-analysis state identifier.
///
/// Concrete exercises should define their own stable state IDs in later PRs
/// without coupling this framework to squat, push-up, plank, or any other
/// specific movement.
class ExerciseState {
  const ExerciseState({
    required this.id,
    this.label,
  }) : assert(id.length > 0);

  static const unknown = ExerciseState(id: 'unknown', label: 'Unknown');

  /// Stable machine-readable state ID.
  final String id;

  /// Optional human-readable label for diagnostics or debug UI.
  final String? label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'ExerciseState(id: $id, label: $label)';
}

/// Type of high-level event emitted by an exercise analyzer.
///
/// Events are facts about analyzer state/progress. They are not voice prompts
/// and should remain independent from TTS/UI delivery.
enum ExerciseEventType {
  stateChanged,
  repetitionCompleted,
  feedbackChanged,
  setCompleted,
  custom,
}

/// Severity of generic exercise feedback.
enum ExerciseFeedbackSeverity { info, cue, warning }

/// A generic event produced by an [ExerciseAnalyzer].
class ExerciseEvent {
  ExerciseEvent({
    required this.type,
    required this.timestamp,
    this.code,
    this.previousState,
    this.currentState,
    this.repetitionCount,
    this.message,
  }) {
    if (repetitionCount != null && repetitionCount! < 0) {
      throw ArgumentError.value(
        repetitionCount,
        'repetitionCount',
        'Must not be negative.',
      );
    }
  }

  /// Broad event category.
  final ExerciseEventType type;

  /// Pose/analysis timestamp associated with this event.
  final DateTime timestamp;

  /// Optional stable event code for downstream consumers.
  final String? code;

  /// Previous analyzer state when [type] is [ExerciseEventType.stateChanged].
  final ExerciseState? previousState;

  /// Current analyzer state when relevant.
  final ExerciseState? currentState;

  /// Optional repetition counter snapshot for generic rep-based exercises.
  final int? repetitionCount;

  /// Optional short diagnostic message. UI/voice wording may still be generated
  /// elsewhere from [code] and app localization.
  final String? message;
}

/// Generic form/coaching feedback produced by an [ExerciseAnalyzer].
class ExerciseFeedback {
  const ExerciseFeedback({
    required this.code,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isActive = true,
  }) : assert(code.length > 0);

  /// Stable machine-readable feedback code.
  final String code;

  /// Human-readable diagnostic message. Later UI/voice layers may localize this.
  final String message;

  /// Generic priority/severity level.
  final ExerciseFeedbackSeverity severity;

  /// Pose/analysis timestamp associated with this feedback.
  final DateTime timestamp;

  /// Whether the feedback condition is currently active.
  final bool isActive;
}

/// Result of analyzing one [PoseFeatures] sample for one exercise.
class ExerciseAnalysis {
  ExerciseAnalysis({
    required this.exerciseId,
    required this.state,
    required this.timestamp,
    this.confidence,
    this.repetitionCount = 0,
    Iterable<ExerciseEvent> events = const [],
    Iterable<ExerciseFeedback> feedback = const [],
  })  : events = UnmodifiableListView<ExerciseEvent>(
          List<ExerciseEvent>.from(events),
        ),
        feedback = UnmodifiableListView<ExerciseFeedback>(
          List<ExerciseFeedback>.from(feedback),
        ) {
    if (exerciseId.trim().isEmpty) {
      throw ArgumentError.value(
        exerciseId,
        'exerciseId',
        'Must not be empty.',
      );
    }
    final confidenceValue = confidence;
    if (confidenceValue != null &&
        (!confidenceValue.isFinite || confidenceValue < 0 || confidenceValue > 1)) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'Must be null or a finite value between 0 and 1.',
      );
    }
    if (repetitionCount < 0) {
      throw ArgumentError.value(
        repetitionCount,
        'repetitionCount',
        'Must not be negative.',
      );
    }
  }

  /// Stable exercise identifier, for example `squat` in a later PR.
  final String exerciseId;

  /// Current generic analyzer state.
  final ExerciseState state;

  /// Timestamp of the [PoseFeatures] sample used for this analysis.
  final DateTime timestamp;

  /// Optional analyzer confidence in the range `[0, 1]`.
  final double? confidence;

  /// Generic repetition count snapshot. Non-rep exercises may keep this at 0.
  final int repetitionCount;

  /// Immutable list of events produced by this analysis step.
  final UnmodifiableListView<ExerciseEvent> events;

  /// Immutable list of currently relevant feedback items.
  final UnmodifiableListView<ExerciseFeedback> feedback;

  bool get hasEvents => events.isNotEmpty;
  bool get hasFeedback => feedback.isNotEmpty;
}

/// Engine-agnostic exercise analyzer.
///
/// Implementations consume only canonical [PoseFeatures]. They must not depend
/// on camera frames, pose estimator engines, renderer coordinates, Flutter
/// widgets, or workout voice/UI code.
abstract interface class ExerciseAnalyzer {
  /// Stable exercise identifier handled by this analyzer.
  String get exerciseId;

  /// Analyze one canonical feature sample.
  ///
  /// [previousFeatures] and [previousAnalysis] are explicit inputs so concrete
  /// analyzers can stay deterministic and testable without hidden frame-count
  /// assumptions.
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  });

  /// Clears analyzer-owned history, if any.
  void reset();
}

/// Small lifecycle helper that feeds sequential [PoseFeatures] into an analyzer.
///
/// It centralizes previous-feature/previous-analysis bookkeeping for future UI
/// or session wiring without adding Flutter dependencies to the core framework.
class ExerciseAnalysisController {
  ExerciseAnalysisController({required this.analyzer});

  final ExerciseAnalyzer analyzer;
  PoseFeatures? _previousFeatures;
  ExerciseAnalysis? _previousAnalysis;

  ExerciseAnalysis? get previousAnalysis => _previousAnalysis;
  PoseFeatures? get previousFeatures => _previousFeatures;

  ExerciseAnalysis analyze(PoseFeatures features) {
    final analysis = analyzer.analyze(
      features,
      previousFeatures: _previousFeatures,
      previousAnalysis: _previousAnalysis,
    );
    _previousFeatures = features;
    _previousAnalysis = analysis;
    return analysis;
  }

  void reset() {
    _previousFeatures = null;
    _previousAnalysis = null;
    analyzer.reset();
  }
}

/// Placeholder analyzer useful for wiring and tests before concrete exercise
/// analyzers are introduced.
class NoopExerciseAnalyzer implements ExerciseAnalyzer {
  const NoopExerciseAnalyzer({required this.exerciseId});

  @override
  final String exerciseId;

  @override
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  }) =>
      ExerciseAnalysis(
        exerciseId: exerciseId,
        state: ExerciseState.unknown,
        timestamp: features.timestamp,
        repetitionCount: previousAnalysis?.repetitionCount ?? 0,
      );

  @override
  void reset() {}
}
