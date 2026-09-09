import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_history_filter.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session({
  required String id,
  required String workoutId,
  required DateTime endedAt,
  Duration activeDuration = const Duration(minutes: 10),
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) {
  return WorkoutSession(
    id: id,
    workoutId: workoutId,
    workoutName: workoutId == 'mobility' ? 'Morning Mobility' : 'High Plank',
    profileId: 'me',
    profileName: 'Me',
    startedAt: endedAt.subtract(activeDuration),
    endedAt: endedAt,
    activeDuration: activeDuration,
    completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
    totalSteps: 4,
    status: status,
  );
}

void main() {
  final now = DateTime(2026, 9, 9, 12);
  final sessions = [
    session(
      id: 'today-completed',
      workoutId: 'mobility',
      endedAt: DateTime(2026, 9, 9, 8),
      activeDuration: const Duration(minutes: 12),
    ),
    session(
      id: 'week-incomplete',
      workoutId: 'plank',
      endedAt: DateTime(2026, 9, 8, 18),
      activeDuration: const Duration(minutes: 5),
      status: WorkoutSessionStatus.incomplete,
    ),
    session(
      id: 'month-completed',
      workoutId: 'plank',
      endedAt: DateTime(2026, 9, 2, 9),
      activeDuration: const Duration(minutes: 20),
    ),
    session(
      id: 'year-completed',
      workoutId: 'mobility',
      endedAt: DateTime(2026, 4, 10, 9),
      activeDuration: const Duration(minutes: 8),
    ),
    session(
      id: 'old-completed',
      workoutId: 'mobility',
      endedAt: DateTime(2025, 12, 31, 23, 59),
      activeDuration: const Duration(minutes: 15),
    ),
  ];

  test('status filters completed and incomplete sessions', () {
    final completed = const WorkoutHistoryFilter(
      status: WorkoutHistoryStatusFilter.completed,
    ).apply(sessions, now: now);
    final incomplete = const WorkoutHistoryFilter(
      status: WorkoutHistoryStatusFilter.incomplete,
    ).apply(sessions, now: now);

    expect(completed.map((item) => item.id), isNot(contains('week-incomplete')));
    expect(incomplete.map((item) => item.id), ['week-incomplete']);
  });

  test('period filters use local week month and year boundaries', () {
    final week = const WorkoutHistoryFilter(
      period: WorkoutHistoryPeriodFilter.thisWeek,
    ).apply(sessions, now: now);
    final month = const WorkoutHistoryFilter(
      period: WorkoutHistoryPeriodFilter.thisMonth,
    ).apply(sessions, now: now);
    final year = const WorkoutHistoryFilter(
      period: WorkoutHistoryPeriodFilter.thisYear,
    ).apply(sessions, now: now);

    expect(week.map((item) => item.id), ['today-completed', 'week-incomplete']);
    expect(month.map((item) => item.id),
        ['today-completed', 'week-incomplete', 'month-completed']);
    expect(year.map((item) => item.id), [
      'today-completed',
      'week-incomplete',
      'month-completed',
      'year-completed',
    ]);
  });

  test('custom range includes both local calendar boundaries', () {
    final rangeSessions = [
      session(
        id: 'before',
        workoutId: 'mobility',
        endedAt: DateTime(2026, 9, 1, 23, 59, 59),
      ),
      session(
        id: 'start',
        workoutId: 'mobility',
        endedAt: DateTime(2026, 9, 2),
      ),
      session(
        id: 'middle',
        workoutId: 'plank',
        endedAt: DateTime(2026, 9, 4, 12),
      ),
      session(
        id: 'end',
        workoutId: 'mobility',
        endedAt: DateTime(2026, 9, 5, 23, 59, 59),
      ),
      session(
        id: 'after',
        workoutId: 'mobility',
        endedAt: DateTime(2026, 9, 6),
      ),
    ];

    final result = WorkoutHistoryFilter(
      period: WorkoutHistoryPeriodFilter.customRange,
      customStartDate: DateTime(2026, 9, 2, 18),
      customEndDate: DateTime(2026, 9, 5, 8),
    ).apply(rangeSessions, now: now);

    expect(result.map((item) => item.id), ['end', 'middle', 'start']);
  });

  test('custom range combines with existing filters and sort', () {
    final result = WorkoutHistoryFilter(
      status: WorkoutHistoryStatusFilter.completed,
      period: WorkoutHistoryPeriodFilter.customRange,
      workoutId: 'plank',
      searchQuery: 'high',
      sort: WorkoutHistorySort.oldestFirst,
      customStartDate: DateTime(2026, 9, 1),
      customEndDate: DateTime(2026, 9, 9),
    ).apply(sessions, now: now);

    expect(result.map((item) => item.id), ['month-completed']);
  });

  test('workout filter uses persisted workout id', () {
    final result = const WorkoutHistoryFilter(workoutId: 'plank').apply(
      sessions,
      now: now,
    );

    expect(result.map((item) => item.id), ['week-incomplete', 'month-completed']);
  });

  test('search matches workout name case-insensitively', () {
    final mobility = const WorkoutHistoryFilter(
      searchQuery: 'MOBILITY',
    ).apply(sessions, now: now);
    final partial = const WorkoutHistoryFilter(
      searchQuery: 'plAn',
    ).apply(sessions, now: now);

    expect(mobility.map((item) => item.workoutId).toSet(), {'mobility'});
    expect(partial.map((item) => item.workoutId).toSet(), {'plank'});
  });

  test('search combines with status period and workout filters', () {
    final result = const WorkoutHistoryFilter(
      status: WorkoutHistoryStatusFilter.completed,
      period: WorkoutHistoryPeriodFilter.thisMonth,
      workoutId: 'plank',
      searchQuery: 'high',
    ).apply(sessions, now: now);

    expect(result.map((item) => item.id), ['month-completed']);
  });

  test('all sort modes are deterministic', () {
    expect(
      const WorkoutHistoryFilter(sort: WorkoutHistorySort.newestFirst)
          .apply(sessions, now: now)
          .map((item) => item.id),
      [
        'today-completed',
        'week-incomplete',
        'month-completed',
        'year-completed',
        'old-completed',
      ],
    );
    expect(
      const WorkoutHistoryFilter(sort: WorkoutHistorySort.oldestFirst)
          .apply(sessions, now: now)
          .map((item) => item.id),
      [
        'old-completed',
        'year-completed',
        'month-completed',
        'week-incomplete',
        'today-completed',
      ],
    );
    expect(
      const WorkoutHistoryFilter(sort: WorkoutHistorySort.longestDuration)
          .apply(sessions, now: now)
          .map((item) => item.id),
      [
        'month-completed',
        'old-completed',
        'today-completed',
        'year-completed',
        'week-incomplete',
      ],
    );
    expect(
      const WorkoutHistoryFilter(sort: WorkoutHistorySort.shortestDuration)
          .apply(sessions, now: now)
          .map((item) => item.id),
      [
        'week-incomplete',
        'year-completed',
        'today-completed',
        'old-completed',
        'month-completed',
      ],
    );
  });

  test('all-time default keeps all sessions newest first', () {
    final result = const WorkoutHistoryFilter().apply(sessions, now: now);

    expect(result.length, sessions.length);
    expect(result.first.id, 'today-completed');
    expect(result.last.id, 'old-completed');
    expect(const WorkoutHistoryFilter().isDefault, isTrue);
    expect(
      const WorkoutHistoryFilter(searchQuery: 'mobility').isDefault,
      isFalse,
    );
    expect(
      const WorkoutHistoryFilter(sort: WorkoutHistorySort.oldestFirst).isDefault,
      isFalse,
    );
    expect(
      WorkoutHistoryFilter(
        period: WorkoutHistoryPeriodFilter.customRange,
        customStartDate: DateTime(2026, 9, 1),
        customEndDate: DateTime(2026, 9, 2),
      ).isDefault,
      isFalse,
    );
  });
}
