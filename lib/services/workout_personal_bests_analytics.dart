import '../models/workout_session.dart';

class WorkoutPersonalBestsSummary {
  final WorkoutSession? longestWorkout;
  final WorkoutSession? mostStepsWorkout;
  final WorkoutSession? highestCaloriesWorkout;
  final String? mostCompletedWorkoutId;
  final String? mostCompletedWorkoutName;
  final int mostCompletedCount;

  const WorkoutPersonalBestsSummary({
    this.longestWorkout,
    this.mostStepsWorkout,
    this.highestCaloriesWorkout,
    this.mostCompletedWorkoutId,
    this.mostCompletedWorkoutName,
    this.mostCompletedCount = 0,
  });

  bool get hasRecords => longestWorkout != null;
}

class WorkoutPersonalBestsAnalytics {
  const WorkoutPersonalBestsAnalytics._();

  static WorkoutPersonalBestsSummary summarize(
    Iterable<WorkoutSession> sessions, {
    String? profileId,
  }) {
    final completed = sessions
        .where((session) =>
            session.completed &&
            (profileId == null || session.profileId == profileId))
        .toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (completed.isEmpty) return const WorkoutPersonalBestsSummary();

    WorkoutSession longest = completed.first;
    WorkoutSession mostSteps = completed.first;
    WorkoutSession? highestCalories;
    final counts = <String, int>{};
    final latestByWorkout = <String, WorkoutSession>{};

    for (final session in completed) {
      if (session.activeDuration > longest.activeDuration) longest = session;
      if (session.completedSteps > mostSteps.completedSteps) mostSteps = session;
      if (session.estimatedCalories != null &&
          (highestCalories == null ||
              session.estimatedCalories! > highestCalories.estimatedCalories!)) {
        highestCalories = session;
      }
      counts.update(session.workoutId, (value) => value + 1, ifAbsent: () => 1);
      latestByWorkout.putIfAbsent(session.workoutId, () => session);
    }

    String? mostCompletedId;
    var mostCompletedCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > mostCompletedCount) {
        mostCompletedId = entry.key;
        mostCompletedCount = entry.value;
      } else if (entry.value == mostCompletedCount && mostCompletedId != null) {
        final candidate = latestByWorkout[entry.key]!;
        final current = latestByWorkout[mostCompletedId]!;
        if (candidate.endedAt.isAfter(current.endedAt)) mostCompletedId = entry.key;
      }
    }

    return WorkoutPersonalBestsSummary(
      longestWorkout: longest,
      mostStepsWorkout: mostSteps,
      highestCaloriesWorkout: highestCalories,
      mostCompletedWorkoutId: mostCompletedId,
      mostCompletedWorkoutName: latestByWorkout[mostCompletedId]?.workoutName,
      mostCompletedCount: mostCompletedCount,
    );
  }
}
