import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseAnalysisSession', () {
    test('routes supported exercise and analyzes sequential features', () {
      final analyzer = _RecordingAnalyzer('demo');
      final session = ExerciseAnalysisSession(
        registry: ExerciseAnalyzerRegistry(
          factories: {'demo': () => analyzer},
        ),
      );

      session.route('demo');
      final first = session.analyze(_features(0));
      final second = session.analyze(_features(1));

      expect(session.exerciseId, 'demo');
      expect(session.isSupported, isTrue);
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(analyzer.previousFeaturesSeen.first, isNull);
      expect(analyzer.previousAnalysisSeen.first, isNull);
      expect(analyzer.previousFeaturesSeen.last, isNotNull);
      expect(analyzer.previousAnalysisSeen.last, same(first));
      expect(session.analysis, same(second));
    });

    test('changing route resets previous analyzer and history', () {
      final firstAnalyzer = _RecordingAnalyzer('first');
      final secondAnalyzer = _RecordingAnalyzer('second');
      final session = ExerciseAnalysisSession(
        registry: ExerciseAnalyzerRegistry(
          factories: {
            'first': () => firstAnalyzer,
            'second': () => secondAnalyzer,
          },
        ),
      );

      session.route('first');
      session.analyze(_features(0));
      session.route('second');
      final analysis = session.analyze(_features(1));

      expect(firstAnalyzer.resetCount, 1);
      expect(secondAnalyzer.previousFeaturesSeen.single, isNull);
      expect(secondAnalyzer.previousAnalysisSeen.single, isNull);
      expect(analysis?.exerciseId, 'second');
    });

    test('unknown and blank routes disable analysis', () {
      final session = ExerciseAnalysisSession(
        registry: ExerciseAnalyzerRegistry(factories: const {}),
      );

      session.route('unknown');
      expect(session.isSupported, isFalse);
      expect(session.analyze(_features(0)), isNull);

      session.route('   ');
      expect(session.exerciseId, isNull);
      expect(session.analysis, isNull);
    });

    test('routing the same exercise preserves sequential history', () {
      final analyzer = _RecordingAnalyzer('demo');
      final session = ExerciseAnalysisSession(
        registry: ExerciseAnalyzerRegistry(
          factories: {'demo': () => analyzer},
        ),
      );

      session.route('demo');
      final first = session.analyze(_features(0));
      session.route('demo');
      session.analyze(_features(1));

      expect(analyzer.resetCount, 0);
      expect(analyzer.previousAnalysisSeen.last, same(first));
    });

    test('reset clears history but preserves active route', () {
      final analyzer = _RecordingAnalyzer('demo');
      final session = ExerciseAnalysisSession(
        registry: ExerciseAnalyzerRegistry(
          factories: {'demo': () => analyzer},
        ),
      );

      session.route('demo');
      session.analyze(_features(0));
      session.reset();
      session.analyze(_features(1));

      expect(session.exerciseId, 'demo');
      expect(session.isSupported, isTrue);
      expect(analyzer.resetCount, 1);
      expect(analyzer.previousFeaturesSeen.last, isNull);
      expect(analyzer.previousAnalysisSeen.last, isNull);
    });
  });
}

PoseFeatures _features(int seconds) => PoseFeatures(
      timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: seconds)),
    );

class _RecordingAnalyzer implements ExerciseAnalyzer {
  _RecordingAnalyzer(this.exerciseId);

  @override
  final String exerciseId;

  int resetCount = 0;
  final previousFeaturesSeen = <PoseFeatures?>[];
  final previousAnalysisSeen = <ExerciseAnalysis?>[];

  @override
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  }) {
    previousFeaturesSeen.add(previousFeatures);
    previousAnalysisSeen.add(previousAnalysis);
    return ExerciseAnalysis(
      exerciseId: exerciseId,
      state: const ExerciseState(id: 'sample'),
      timestamp: features.timestamp,
      repetitionCount: previousAnalysis?.repetitionCount ?? 0,
    );
  }

  @override
  void reset() {
    resetCount++;
  }
}
