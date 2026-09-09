import '../models/workout_session.dart';

enum WorkoutHistoryStatusFilter { all, completed, incomplete }

enum WorkoutHistoryPeriodFilter { allTime, thisWeek, thisMonth, thisYear }

class WorkoutHistoryFilter {
  final WorkoutHistoryStatusFilter status;
  final WorkoutHistoryPeriodFilter period;
  final String? workoutId;

  const WorkoutHistoryFilter({
    this.status = WorkoutHistoryStatusFilter.all,
    this.period = WorkoutHistoryPeriodFilter.allTime,
    this.workoutId,
  });

  bool get isDefault =>
      status == WorkoutHistoryStatusFilter.all &&
      period == WorkoutHistoryPeriodFilter.allTime &&
      workoutId == null;

  List<WorkoutSession> apply(
    Iterable<WorkoutSession> sessions, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final bounds = _periodBounds(reference);
    return sessions.where((session) {
      if (!_matchesStatus(session)) return false;
      if (workoutId != null && session.workoutId != workoutId) return false;
      if (bounds != null &&
          (session.endedAt.isBefore(bounds.$1) ||
              !session.endedAt.isBefore(bounds.$2))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  }

  bool _matchesStatus(WorkoutSession session) => switch (status) {
        WorkoutHistoryStatusFilter.all => true,
        WorkoutHistoryStatusFilter.completed =>
          session.status == WorkoutSessionStatus.completed,
        WorkoutHistoryStatusFilter.incomplete =>
          session.status == WorkoutSessionStatus.incomplete,
      };

  (DateTime, DateTime)? _periodBounds(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return switch (period) {
      WorkoutHistoryPeriodFilter.allTime => null,
      WorkoutHistoryPeriodFilter.thisWeek => (
          day.subtract(Duration(days: day.weekday - DateTime.monday)),
          day
              .subtract(Duration(days: day.weekday - DateTime.monday))
              .add(const Duration(days: 7)),
        ),
      WorkoutHistoryPeriodFilter.thisMonth => (
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1),
        ),
      WorkoutHistoryPeriodFilter.thisYear => (
          DateTime(now.year),
          DateTime(now.year + 1),
        ),
    };
  }
}
