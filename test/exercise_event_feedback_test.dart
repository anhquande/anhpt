import 'package:anhpt/core/pose/pose.dart';
import 'package:anhpt/services/exercise_event_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExerciseEventFeedback', () {
    test('maps repetition events with their count', () {
      final event = ExerciseEvent(
        type: ExerciseEventType.repetitionCompleted,
        timestamp: DateTime.utc(2026, 1, 1),
        code: 'squat_repetition_completed',
        repetitionCount: 3,
      );

      expect(ExerciseEventFeedback.phrase(event, language: 'vi'), 'Lần 3');
      expect(ExerciseEventFeedback.phrase(event, language: 'en'), 'Rep 3');
    });

    test('maps supported form cues', () {
      final event = ExerciseEvent(
        type: ExerciseEventType.feedbackChanged,
        timestamp: DateTime.utc(2026, 1, 1),
        code: 'plank_arms_not_extended',
      );

      expect(
        ExerciseEventFeedback.phrase(event, language: 'vi'),
        'Giữ tay thẳng hơn',
      );
      expect(
        ExerciseEventFeedback.phrase(event, language: 'en'),
        'Keep your arms straighter',
      );
    });

    test('ignores structural and unknown events', () {
      final event = ExerciseEvent(
        type: ExerciseEventType.stateChanged,
        timestamp: DateTime.utc(2026, 1, 1),
        code: 'squat_state_changed',
      );

      expect(ExerciseEventFeedback.phrase(event, language: 'vi'), isNull);
    });
  });
}
