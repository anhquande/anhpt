import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseAnalyzerRegistry', () {
    test('creates the default squat analyzer by exercise id', () {
      final registry = ExerciseAnalyzerRegistry();

      final analyzer = registry.create('squat');

      expect(analyzer, isA<SquatExerciseAnalyzer>());
      expect(analyzer?.exerciseId, SquatExerciseAnalyzer.id);
      expect(registry.supports('squat'), isTrue);
      expect(registry.supportedExerciseIds, contains('squat'));
    });

    test('creates the default plank analyzer by exercise id', () {
      final registry = ExerciseAnalyzerRegistry();

      final analyzer = registry.create('plank');

      expect(analyzer, isA<PlankExerciseAnalyzer>());
      expect(analyzer?.exerciseId, PlankExerciseAnalyzer.id);
      expect(registry.supports('plank'), isTrue);
      expect(registry.supportedExerciseIds, contains('plank'));
    });

    test('creates the default push-up analyzer by exercise id', () {
      final registry = ExerciseAnalyzerRegistry();

      final analyzer = registry.create('push-up');

      expect(analyzer, isA<PushUpExerciseAnalyzer>());
      expect(analyzer?.exerciseId, PushUpExerciseAnalyzer.id);
      expect(registry.supports('push-up'), isTrue);
      expect(registry.supportedExerciseIds, contains('push-up'));
    });

    test('does not create analyzers for blank or unknown ids', () {
      final registry = ExerciseAnalyzerRegistry();

      expect(registry.create(null), isNull);
      expect(registry.create(''), isNull);
      expect(registry.create('   '), isNull);
      expect(registry.create('burpee'), isNull);
      expect(registry.supports('burpee'), isFalse);
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
      expect(registry.supports('plank'), isFalse);
      expect(registry.supports('push-up'), isFalse);
      expect(registry.supportedExerciseIds, ['custom']);
    });
  });
}
