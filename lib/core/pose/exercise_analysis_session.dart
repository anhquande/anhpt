import 'exercise_analysis.dart';
import 'exercise_analyzer_registry.dart';
import 'pose_features.dart';

/// Owns exercise routing and sequential analyzer history for one workout camera
/// session.
///
/// UI widgets feed canonical [PoseFeatures] and the active exercise id into this
/// class. Analyzer selection, route changes, history resets, and unsupported
/// exercise handling stay outside Flutter presentation code.
class ExerciseAnalysisSession {
  ExerciseAnalysisSession({
    ExerciseAnalyzerRegistry? registry,
  }) : _registry = registry ?? ExerciseAnalyzerRegistry();

  final ExerciseAnalyzerRegistry _registry;
  String? _exerciseId;
  ExerciseAnalysisController? _controller;
  ExerciseAnalysis? _analysis;

  String? get exerciseId => _exerciseId;
  ExerciseAnalysis? get analysis => _analysis;
  bool get isSupported => _controller != null;

  /// Selects the analyzer for [exerciseId].
  ///
  /// Changing routes always discards analysis history so repetitions and motion
  /// state cannot leak between workout steps. Blank and unknown ids disable
  /// analysis.
  void route(String? exerciseId) {
    final normalizedId = exerciseId?.trim();
    final nextId =
        normalizedId == null || normalizedId.isEmpty ? null : normalizedId;
    if (_exerciseId == nextId) return;

    _controller?.reset();
    _exerciseId = nextId;
    final analyzer = _registry.create(nextId);
    _controller =
        analyzer == null ? null : ExerciseAnalysisController(analyzer: analyzer);
    _analysis = null;
  }

  /// Analyzes one feature sample for the currently routed exercise.
  ///
  /// Returns null when the active exercise has no registered analyzer.
  ExerciseAnalysis? analyze(PoseFeatures features) {
    final controller = _controller;
    if (controller == null) {
      _analysis = null;
      return null;
    }
    return _analysis = controller.analyze(features);
  }

  /// Clears analyzer history while preserving the active exercise route.
  void reset() {
    _controller?.reset();
    _analysis = null;
  }
}
