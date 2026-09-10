import '../models/workout_session.dart';

class WorkoutConsistencySummary {
  final int currentStreakDays;
  final int longestStreakDays;
  final int workoutDaysThisWeek;
  final int workoutDaysThisMonth;

  const WorkoutConsistencySummary({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.workoutDaysThisWeek,
    required this.workoutDaysThisMonth,
  });

  bool get hasActivity => longestStreakDays > 0;
}

class WorkoutConsistencyAnalytics {
  const WorkoutConsistencyAnalytics._();

  static WorkoutConsistencySummary summarize(
    Iterable<WorkoutSession> sessions, {
    String? profileId,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = _dateOnly(reference.toLocal());
    final completedDays = <DateTime>{};

    for (final session in sessions) {
      if (!session.completed) continue;
      if (profileId != null && session.profileId != profileId) continue;
      completedDays.add(_dateOnly(session.endedAt.toLocal()));
    }

    if (completedDays.isEmpty) {
      return const WorkoutConsistencySummary(
        currentStreakDays: 0,
        longestStreakDays: 0,
        workoutDaysThisWeek: 0,
        workoutDaysThisMonth: 0,
      );
    }

    final sortedDays = completedDays.toList()..sort();
    var longestStreak = 1;
    var runningStreak = 1;
    for (var index = 1; index < sortedDays.length; index++) {
      final previous = sortedDays[index - 1];
      final current = sortedDays[index];
      if (current.difference(previous).inDays == 1) {
        runningStreak++;
        if (runningStreak > longestStreak) longestStreak = runningStreak;
      } else {
        runningStreak = 1;
      }
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final streakAnchor = completedDays.contains(today)
        ? today
        : completedDays.contains(yesterday)
            ? yesterday
            : null;
    var currentStreak = 0;
    if (streakAnchor != null) {
      var cursor = streakAnchor;
      while (completedDays.contains(cursor)) {
        currentStreak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    final weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(today.year, today.month);
    final nextMonthStart = DateTime(today.year, today.month + 1);

    final workoutDaysThisWeek = completedDays
        .where((day) => !day.isBefore(weekStart) && day.isBefore(nextWeekStart))
        .length;
    final workoutDaysThisMonth = completedDays
        .where((day) => !day.isBefore(monthStart) && day.isBefore(nextMonthStart))
        .length;

    return WorkoutConsistencySummary(
      currentStreakDays: currentStreak,
      longestStreakDays: longestStreak,
      workoutDaysThisWeek: workoutDaysThisWeek,
      workoutDaysThisMonth: workoutDaysThisMonth,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
