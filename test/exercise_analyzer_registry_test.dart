import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseAnalyzerRegistry', () {
    test('creates the default squat analyzer by exercise id', () {
      const registry = ExerciseAnalyzerRegistry();

      final analyzer = registry.create('squat');

      expect(analyzer, isA<SquatExerciseAnalyzer>());
      expect(analyzer?.exerciseId, SquatExerciseAnalyzer.id);
      expect(registry.supports('squat'), isTrue);
      expect(registry.supportedExerciseIds, contains('squat'));
    });

    test('does not create analyzers for blank or unknown ids', () {
      const registry = ExerciseAnalyzerRegistry();

      expect(registry.create(null), isNull);
      expect(registry.create(''), isNull);
      expect(registry.create('   '), isNull);
      expect(registry.create('plank'), isNull);
      expect(registry.supports('plank'), isFalse);
    });

    test('supports injected analyzer factories', () {
      final registry = ExerciseAnalyzerRegistry(
        factories: {
          'custom': () => const NoopExerciseAnalyzer(exerciseId: 'custom'),
        },
      );

      final analyzer = registry.create('custom');

      expect(analyzer, isA<NoopExerciseAnalyzer>());
      expect(analyzer?.exerciseId, 'custom');
      expect(registry.supports('squat'), isFalse);
      expect(registry.supportedExerciseIds, ['custom']);
    });
  });
}
