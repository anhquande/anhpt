import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_history_filter.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session({
  required String id,
  required String workoutId,
  required DateTime endedAt,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) {
  return WorkoutSession(
    id: id,
    workoutId: workoutId,
    workoutName: workoutId == 'mobility' ? 'Mobility' : 'Plank',
    profileId: 'me',
    profileName: 'Me',
    startedAt: endedAt.subtract(const Duration(minutes: 10)),
    endedAt: endedAt,
    activeDuration: const Duration(minutes: 10),
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
    ),
    session(
      id: 'week-incomplete',
      workoutId: 'plank',
      endedAt: DateTime(2026, 9, 8, 18),
      status: WorkoutSessionStatus.incomplete,
    ),
    session(
      id: 'month-completed',
      workoutId: 'plank',
      endedAt: DateTime(2026, 9, 2, 9),
    ),
    session(
      id: 'year-completed',
      workoutId: 'mobility',
      endedAt: DateTime(2026, 4, 10, 9),
    ),
    session(
      id: 'old-completed',
      workoutId: 'mobility',
      endedAt: DateTime(2025, 12, 31, 23, 59),
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

    expect(
      week.map((item) => item.id),
      ['today-completed', 'week-incomplete'],
    );
    expect(
      month.map((item) => item.id),
      ['today-completed', 'week-incomplete', 'month-completed'],
    );
    expect(
      year.map((item) => item.id),
      [
        'today-completed',
        'week-incomplete',
        'month-completed',
        'year-completed',
      ],
    );
  });

  test('workout filter uses persisted workout id', () {
    final result = const WorkoutHistoryFilter(workoutId: 'plank').apply(
      sessions,
      now: now,
    );

    expect(result.map((item) => item.id), [
      'week-incomplete',
      'month-completed',
    ]);
  });

  test('status period and workout filters combine', () {
    final result = const WorkoutHistoryFilter(
      status: WorkoutHistoryStatusFilter.completed,
      period: WorkoutHistoryPeriodFilter.thisMonth,
      workoutId: 'plank',
    ).apply(sessions, now: now);

    expect(result.map((item) => item.id), ['month-completed']);
  });

  test('all-time default keeps all sessions newest first', () {
    final result = const WorkoutHistoryFilter().apply(sessions, now: now);

    expect(result.length, sessions.length);
    expect(result.first.id, 'today-completed');
    expect(result.last.id, 'old-completed');
    expect(const WorkoutHistoryFilter().isDefault, isTrue);
  });
}
