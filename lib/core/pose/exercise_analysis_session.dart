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
  final List<void Function(ExerciseEvent)> _eventListeners = [];

  String? get exerciseId => _exerciseId;
  ExerciseAnalysis? get analysis => _analysis;
  bool get isSupported => _controller != null;

  /// Registers a downstream consumer for high-level analyzer events.
  ///
  /// The core session only forwards events. UI, TTS, haptics, persistence, and
  /// other side effects remain owned by their respective app layers.
  void addEventListener(void Function(ExerciseEvent) listener) {
    if (!_eventListeners.contains(listener)) _eventListeners.add(listener);
  }

  void removeEventListener(void Function(ExerciseEvent) listener) {
    _eventListeners.remove(listener);
  }

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
    final analysis = controller.analyze(features);
    _analysis = analysis;
    if (analysis.events.isNotEmpty && _eventListeners.isNotEmpty) {
      final listeners = List<void Function(ExerciseEvent)>.from(_eventListeners);
      for (final event in analysis.events) {
        for (final listener in listeners) {
          listener(event);
        }
      }
    }
    return analysis;
  }

  /// Clears analyzer history while preserving the active exercise route.
  void reset() {
    _controller?.reset();
    _analysis = null;
  }
}
