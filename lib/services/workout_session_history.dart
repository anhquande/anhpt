import 'package:flutter/foundation.dart';

import '../models/workout_session.dart';
import 'local_store.dart';
import 'workout_session_analytics.dart';

class WorkoutSessionHistory {
  final LocalStore store;

  const WorkoutSessionHistory(this.store);

  /// Lightweight local change signal used by read-only progress surfaces.
  ///
  /// Session persistence remains the source of truth. The revision only tells
  /// widgets that they should reload that persisted data.
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
  }) async {
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
    );
    final sessions = await load();
    sessions.insert(0, session);
    await store.saveWorkoutSessions(sessions);
    revision.value++;
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
