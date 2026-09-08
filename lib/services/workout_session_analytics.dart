import '../models/workout_session.dart';

class WeeklyWorkoutSummary {
  final DateTime weekStart;
  final int completedWorkouts;
  final Duration activeDuration;
  final int previousCompletedWorkouts;
  final Duration previousActiveDuration;

  const WeeklyWorkoutSummary({
    required this.weekStart,
    required this.completedWorkouts,
    required this.activeDuration,
    required this.previousCompletedWorkouts,
    required this.previousActiveDuration,
  });

  bool get hasActivity => completedWorkouts > 0;
  bool get hasPreviousActivity => previousCompletedWorkouts > 0;
}

class WorkoutSessionAnalytics {
  static WeeklyWorkoutSummary weeklySummary(
    Iterable<WorkoutSession> sessions, {
    DateTime? now,
    String? profileId,
  }) {
    final reference = now ?? DateTime.now();
    final day = DateTime(reference.year, reference.month, reference.day);
    final weekStart = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final previousWeekStart = weekStart.subtract(const Duration(days: 7));

    var completedWorkouts = 0;
    var activeDuration = Duration.zero;
    var previousCompletedWorkouts = 0;
    var previousActiveDuration = Duration.zero;

    for (final session in sessions) {
      if (!session.completed) continue;
      if (profileId != null && session.profileId != profileId) continue;
      final endedAt = session.endedAt;
      if (!endedAt.isBefore(weekStart) && endedAt.isBefore(nextWeekStart)) {
        completedWorkouts++;
        activeDuration += session.activeDuration;
      } else if (!endedAt.isBefore(previousWeekStart) &&
          endedAt.isBefore(weekStart)) {
        previousCompletedWorkouts++;
        previousActiveDuration += session.activeDuration;
      }
    }

    return WeeklyWorkoutSummary(
      weekStart: weekStart,
      completedWorkouts: completedWorkouts,
      activeDuration: activeDuration,
      previousCompletedWorkouts: previousCompletedWorkouts,
      previousActiveDuration: previousActiveDuration,
    );
  }
}
