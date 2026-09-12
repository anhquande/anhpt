import 'exercise_analysis.dart';
import 'squat_analyzer.dart';

typedef ExerciseAnalyzerFactory = ExerciseAnalyzer Function();

/// Creates exercise analyzers by canonical exercise id.
///
/// The registry keeps UI and camera code independent from concrete analyzer
/// constructors. New analyzers should be added here rather than directly in
/// player or camera widgets.
class ExerciseAnalyzerRegistry {
  final Map<String, ExerciseAnalyzerFactory> _factories;

  const ExerciseAnalyzerRegistry({
    Map<String, ExerciseAnalyzerFactory> factories =
        defaultExerciseAnalyzerFactories,
  }) : _factories = factories;

  static const defaultExerciseAnalyzerFactories =
      <String, ExerciseAnalyzerFactory>{
    SquatExerciseAnalyzer.id: SquatExerciseAnalyzer.new,
  };

  ExerciseAnalyzer? create(String? exerciseId) {
    final normalizedId = exerciseId?.trim();
    if (normalizedId == null || normalizedId.isEmpty) return null;
    return _factories[normalizedId]?.call();
  }

  bool supports(String? exerciseId) => create(exerciseId) != null;

  Iterable<String> get supportedExerciseIds => _factories.keys;
}
