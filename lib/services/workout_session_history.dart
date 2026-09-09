import 'package:flutter/foundation.dart';

import '../models/workout_session.dart';
import 'local_store.dart';
import 'workout_session_analytics.dart';

class WorkoutSessionHistory {
  final LocalStore store;

  const WorkoutSessionHistory(this.store);

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

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
    DateTime? startedAt,
    DateTime? endedAt,
    int? estimatedCalories,
    WorkoutSessionEffort? effort,
  }) async {
    if (estimatedCalories != null && estimatedCalories < 0) {
      throw ArgumentError.value(
        estimatedCalories,
        'estimatedCalories',
        'must be non-negative',
      );
    }
    final end = endedAt ?? DateTime.now();
    final start = startedAt ?? end.subtract(activeDuration);
    final session = WorkoutSession(
      id: 'session_${end.microsecondsSinceEpoch}',
      workoutId: workoutId,
      workoutName: workoutName,
      profileId: profileId,
      profileName: profileName,
      startedAt: start,
      endedAt: end,
      activeDuration: activeDuration,
      completedSteps: completedSteps.clamp(0, totalSteps).toInt(),
      totalSteps: totalSteps,
      status: status,
      estimatedCalories: estimatedCalories,
      effort: effort,
    );
    final sessions = await load();
    sessions.insert(0, session);
    await store.saveWorkoutSessions(sessions);
    revision.value++;
    return session;
  }

  Future<WorkoutSession?> updateNote({
    required String sessionId,
    required String? note,
  }) async {
    final sessions = await load();
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return null;

    final updated = sessions[index].copyWithNote(note);
    if (updated.note == sessions[index].note) return updated;

    sessions[index] = updated;
    await store.saveWorkoutSessions(sessions);
    revision.value++;
    return updated;
  }

  Future<WorkoutSession?> updateMetrics({
    required String sessionId,
    required int? estimatedCalories,
    required WorkoutSessionEffort? effort,
  }) async {
    if (estimatedCalories != null && estimatedCalories < 0) {
      throw ArgumentError.value(
        estimatedCalories,
        'estimatedCalories',
        'must be non-negative',
      );
    }
    final sessions = await load();
    final index = sessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return null;

    final current = sessions[index];
    final updated = current.copyWithMetrics(
      estimatedCalories: estimatedCalories,
      effort: effort,
      replaceCalories: true,
      replaceEffort: true,
    );
    if (updated.estimatedCalories == current.estimatedCalories &&
        updated.effort == current.effort) {
      return updated;
    }

    sessions[index] = updated;
    await store.saveWorkoutSessions(sessions);
    revision.value++;
    return updated;
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

  Future<MonthlyWorkoutSummary> monthlySummary({
    DateTime? now,
    String? profileId,
  }) async =>
      WorkoutSessionAnalytics.monthlySummary(
        await load(),
        now: now,
        profileId: profileId,
      );

  Future<YearlyWorkoutSummary> yearlySummary({
    DateTime? now,
    String? profileId,
  }) async =>
      WorkoutSessionAnalytics.yearlySummary(
        await load(),
        now: now,
        profileId: profileId,
      );
}
