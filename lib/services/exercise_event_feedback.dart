import '../core/pose/exercise_analysis.dart';

/// Converts engine-agnostic exercise events into short coaching phrases.
class ExerciseEventFeedback {
  const ExerciseEventFeedback._();

  static String? phrase(ExerciseEvent event, {required String language}) {
    final vietnamese = language == 'vi';
    final rep = event.repetitionCount;
    switch (event.code) {
      case 'squat_repetition_completed':
      case 'push_up_repetition_completed':
        if (rep == null) return vietnamese ? 'Tốt lắm' : 'Good';
        return vietnamese ? 'Lần $rep' : 'Rep $rep';
      case 'squat_torso_lean':
        return vietnamese ? 'Giữ thân người thẳng hơn' : 'Keep your torso more upright';
      case 'squat_knee_asymmetry':
        return vietnamese ? 'Giữ hai đầu gối đều nhau' : 'Keep both knees moving evenly';
      case 'push_up_body_not_aligned':
      case 'plank_body_not_aligned':
        return vietnamese ? 'Giữ vai và hông trên một đường thẳng' : 'Keep shoulders and hips in one straight line';
      case 'push_up_elbow_asymmetry':
        return vietnamese ? 'Giữ hai khuỷu tay đều nhau' : 'Move both elbows evenly';
      case 'plank_arms_not_extended':
        return vietnamese ? 'Giữ tay thẳng hơn' : 'Keep your arms straighter';
      default:
        return null;
    }
  }
}
