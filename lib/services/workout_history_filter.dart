import '../models/workout_session.dart';

enum WorkoutHistoryStatusFilter { all, completed, incomplete }

enum WorkoutHistoryPeriodFilter { allTime, thisWeek, thisMonth, thisYear, customRange }

enum WorkoutHistorySort {
  newestFirst,
  oldestFirst,
  longestDuration,
  shortestDuration,
}

class WorkoutHistoryFilter {
  final WorkoutHistoryStatusFilter status;
  final WorkoutHistoryPeriodFilter period;
  final String? workoutId;
  final String searchQuery;
  final WorkoutHistorySort sort;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  const WorkoutHistoryFilter({
    this.status = WorkoutHistoryStatusFilter.all,
    this.period = WorkoutHistoryPeriodFilter.allTime,
    this.workoutId,
    this.searchQuery = '',
    this.sort = WorkoutHistorySort.newestFirst,
    this.customStartDate,
    this.customEndDate,
  });

  bool get isDefault =>
      status == WorkoutHistoryStatusFilter.all &&
      period == WorkoutHistoryPeriodFilter.allTime &&
      workoutId == null &&
      searchQuery.trim().isEmpty &&
      sort == WorkoutHistorySort.newestFirst;

  List<WorkoutSession> apply(
    Iterable<WorkoutSession> sessions, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final bounds = _periodBounds(reference);
    final query = searchQuery.trim().toLowerCase();
    final result = sessions.where((session) {
      if (!_matchesStatus(session)) return false;
      if (workoutId != null && session.workoutId != workoutId) return false;
      if (query.isNotEmpty) {
        final matchesWorkout = session.workoutName.toLowerCase().contains(query);
        final matchesNote = session.note?.toLowerCase().contains(query) ?? false;
        if (!matchesWorkout && !matchesNote) return false;
      }
      if (bounds != null &&
          (session.endedAt.isBefore(bounds.$1) ||
              !session.endedAt.isBefore(bounds.$2))) {
        return false;
      }
      return true;
    }).toList();

    result.sort(_compare);
    return result;
  }

  int _compare(WorkoutSession a, WorkoutSession b) => switch (sort) {
        WorkoutHistorySort.newestFirst => _withIdTieBreak(
            b.endedAt.compareTo(a.endedAt),
            a,
            b,
          ),
        WorkoutHistorySort.oldestFirst => _withIdTieBreak(
            a.endedAt.compareTo(b.endedAt),
            a,
            b,
          ),
        WorkoutHistorySort.longestDuration => _withIdTieBreak(
            b.activeDuration.compareTo(a.activeDuration),
            a,
            b,
          ),
        WorkoutHistorySort.shortestDuration => _withIdTieBreak(
            a.activeDuration.compareTo(b.activeDuration),
            a,
            b,
          ),
      };

  int _withIdTieBreak(int comparison, WorkoutSession a, WorkoutSession b) {
    if (comparison != 0) return comparison;
    final endedAtComparison = b.endedAt.compareTo(a.endedAt);
    if (endedAtComparison != 0) return endedAtComparison;
    return a.id.compareTo(b.id);
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
      WorkoutHistoryPeriodFilter.customRange => _customBounds(),
    };
  }

  (DateTime, DateTime)? _customBounds() {
    final start = customStartDate;
    final end = customEndDate;
    if (start == null || end == null) return null;

    final startDay = DateTime(start.year, start.month, start.day);
    final endExclusive = DateTime(end.year, end.month, end.day).add(
      const Duration(days: 1),
    );
    return (startDay, endExclusive);
  }
}
