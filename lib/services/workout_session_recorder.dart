import '../models/workout_session.dart';
import 'workout_session_history.dart';

class WorkoutSessionRecorder {
  final WorkoutSessionHistory history;
  final String workoutId;
  final String workoutName;
  final String? profileId;
  final String? profileName;
  final DateTime startedAt;

  bool _recorded = false;

  WorkoutSessionRecorder({
    required this.history,
    required this.workoutId,
    required this.workoutName,
    required this.startedAt,
    this.profileId,
    this.profileName,
  });

  bool get recorded => _recorded;

  Future<WorkoutSession?> recordTerminal({
    required WorkoutSessionStatus status,
    required Duration activeDuration,
    required int completedSteps,
    required int totalSteps,
    DateTime? endedAt,
  }) async {
    if (_recorded) return null;
    _recorded = true;

    return history.record(
      workoutId: workoutId,
      workoutName: workoutName,
      profileId: profileId,
      profileName: profileName,
      startedAt: startedAt,
      endedAt: endedAt,
      activeDuration: activeDuration,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      status: status,
    );
  }
}
