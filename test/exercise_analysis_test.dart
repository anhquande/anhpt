import 'package:anhpt/core/pose/pose.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _baseTime = DateTime.utc(2026, 1, 1);

PoseFeatures _features(DateTime timestamp) => PoseFeatures(timestamp: timestamp);

void main() {
  group('ExerciseState', () {
    test('uses stable value semantics', () {
      const a = ExerciseState(id: 'top', label: 'Top');
      const b = ExerciseState(id: 'top', label: 'Top');
      const c = ExerciseState(id: 'bottom', label: 'Bottom');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(ExerciseState.unknown.id, 'unknown');
    });
  });

  group('ExerciseAnalysis', () {
    test('keeps events and feedback immutable', () {
      final analysis = ExerciseAnalysis(
        exerciseId: 'demo',
        state: ExerciseState.unknown,
        timestamp: _baseTime,
        events: [
          ExerciseEvent(
            type: ExerciseEventType.stateChanged,
            timestamp: _baseTime,
            previousState: ExerciseState.unknown,
            currentState: const ExerciseState(id: 'ready'),
          ),
        ],
        feedback: [
          ExerciseFeedback(
            code: 'hold_still',
            message: 'Hold still',
            severity: ExerciseFeedbackSeverity.cue,
            timestamp: _baseTime,
          ),
        ],
      );

      expect(analysis.hasEvents, isTrue);
      expect(analysis.hasFeedback, isTrue);
      expect(
        () => analysis.events.add(
          ExerciseEvent(
            type: ExerciseEventType.custom,
            timestamp: _baseTime,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => analysis.feedback.clear(),
        throwsUnsupportedError,
      );
    });

    test('validates exercise id, confidence, and repetition count', () {
      expect(
        () => ExerciseAnalysis(
          exerciseId: ' ',
          state: ExerciseState.unknown,
          timestamp: _baseTime,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExerciseAnalysis(
          exerciseId: 'demo',
          state: ExerciseState.unknown,
          timestamp: _baseTime,
          confidence: 1.2,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExerciseAnalysis(
          exerciseId: 'demo',
          state: ExerciseState.unknown,
          timestamp: _baseTime,
          repetitionCount: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ExerciseAnalysisController', () {
    test('passes previous features and analysis explicitly', () {
      final analyzer = _RecordingAnalyzer();
      final controller = ExerciseAnalysisController(analyzer: analyzer);
      final firstFeatures = _features(_baseTime);
      final secondFeatures = _features(_baseTime.add(const Duration(seconds: 1)));

      final first = controller.analyze(firstFeatures);
      final second = controller.analyze(secondFeatures);

      expect(analyzer.calls, 2);
      expect(analyzer.previousFeaturesSeen.first, isNull);
      expect(analyzer.previousAnalysisSeen.first, isNull);
      expect(analyzer.previousFeaturesSeen.last, same(firstFeatures));
      expect(analyzer.previousAnalysisSeen.last, same(first));
      expect(controller.previousFeatures, same(secondFeatures));
      expect(controller.previousAnalysis, same(second));
    });

    test('reset clears controller history and resets analyzer', () {
      final analyzer = _RecordingAnalyzer();
      final controller = ExerciseAnalysisController(analyzer: analyzer);

      controller.analyze(_features(_baseTime));
      controller.reset();
      controller.analyze(_features(_baseTime.add(const Duration(seconds: 1))));

      expect(analyzer.resetCount, 1);
      expect(analyzer.previousFeaturesSeen.last, isNull);
      expect(analyzer.previousAnalysisSeen.last, isNull);
    });
  });

  group('NoopExerciseAnalyzer', () {
    test('returns unknown analysis without exercise-specific logic', () {
      const analyzer = NoopExerciseAnalyzer(exerciseId: 'demo');
      final analysis = analyzer.analyze(_features(_baseTime));

      expect(analysis.exerciseId, 'demo');
      expect(analysis.state, ExerciseState.unknown);
      expect(analysis.timestamp, _baseTime);
      expect(analysis.repetitionCount, 0);
      expect(analysis.events, isEmpty);
      expect(analysis.feedback, isEmpty);
    });

    test('preserves previous repetition snapshot when used for wiring', () {
      const analyzer = NoopExerciseAnalyzer(exerciseId: 'demo');
      final previous = ExerciseAnalysis(
        exerciseId: 'demo',
        state: ExerciseState.unknown,
        timestamp: _baseTime,
        repetitionCount: 3,
      );

      final analysis = analyzer.analyze(
        _features(_baseTime.add(const Duration(seconds: 1))),
        previousAnalysis: previous,
      );

      expect(analysis.repetitionCount, 3);
    });
  });
}

class _RecordingAnalyzer implements ExerciseAnalyzer {
  int calls = 0;
  int resetCount = 0;
  final previousFeaturesSeen = <PoseFeatures?>[];
  final previousAnalysisSeen = <ExerciseAnalysis?>[];

  @override
  String get exerciseId => 'recording';

  @override
  ExerciseAnalysis analyze(
    PoseFeatures features, {
    PoseFeatures? previousFeatures,
    ExerciseAnalysis? previousAnalysis,
  }) {
    calls++;
    previousFeaturesSeen.add(previousFeatures);
    previousAnalysisSeen.add(previousAnalysis);
    return ExerciseAnalysis(
      exerciseId: exerciseId,
      state: const ExerciseState(id: 'sample'),
      timestamp: features.timestamp,
    );
  }

  @override
  void reset() {
    resetCount++;
  }
}
