import '../models/workout_session.dart';
import 'local_store.dart';
import 'workout_session_analytics.dart';

class WorkoutSessionHistory {
  final LocalStore store;

  const WorkoutSessionHistory(this.store);

  Future<List<WorkoutSession>> load() => store.loadWorkoutSessions();

  Future<WorkoutSession> record({
    required String workoutId,
    required String workoutName,
    String? profileId,
    String? profileName,
    required Duration activeDuration,
    required int completedSteps,
    required int totalSteps,
    required WorkoutSessionStatus status,
    DateTime? endedAt,
  }) async {
    final end = endedAt ?? DateTime.now();
    final session = WorkoutSession(
      id: 'session_${end.microsecondsSinceEpoch}',
      workoutId: workoutId,
      workoutName: workoutName,
      profileId: profileId,
      profileName: profileName,
      startedAt: end.subtract(activeDuration),
      endedAt: end,
      activeDuration: activeDuration,
      completedSteps: completedSteps.clamp(0, totalSteps),
      totalSteps: totalSteps,
      status: status,
    );
    final sessions = await load();
    sessions.insert(0, session);
    await store.saveWorkoutSessions(sessions);
    return session;
  }

  Future<WeeklyWorkoutSummary> weeklySummary({
    DateTime? now,
    String? profileId,
  }) async =>
      WorkoutSessionAnalytics.weeklySummary(
        await load(),
        now: now,
        profileId: profileId,
      );
}
