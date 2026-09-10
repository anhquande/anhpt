import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_consistency_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession session({
  required String id,
  required DateTime endedAt,
  String profileId = 'me',
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) {
  return WorkoutSession(
    id: id,
    workoutId: 'plank',
    workoutName: 'High Plank',
    profileId: profileId,
    profileName: profileId,
    startedAt: endedAt.subtract(const Duration(minutes: 10)),
    endedAt: endedAt,
    activeDuration: const Duration(minutes: 10),
    completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
    totalSteps: 4,
    status: status,
  );
}

void main() {
  test('counts current and longest streak with duplicate workout days', () {
    final sessions = [
      session(id: 'today-a', endedAt: DateTime(2026, 9, 10, 8)),
      session(id: 'today-b', endedAt: DateTime(2026, 9, 10, 18)),
      session(id: 'yesterday', endedAt: DateTime(2026, 9, 9, 9)),
      session(id: 'two-days', endedAt: DateTime(2026, 9, 8, 9)),
      session(id: 'gap', endedAt: DateTime(2026, 9, 6, 9)),
      session(id: 'old-a', endedAt: DateTime(2026, 8, 1, 9)),
      session(id: 'old-b', endedAt: DateTime(2026, 8, 2, 9)),
      session(id: 'old-c', endedAt: DateTime(2026, 8, 3, 9)),
      session(id: 'old-d', endedAt: DateTime(2026, 8, 4, 9)),
    ];

    final result = WorkoutConsistencyAnalytics.summarize(
      sessions,
      profileId: 'me',
      now: DateTime(2026, 9, 10, 12),
    );

    expect(result.currentStreakDays, 3);
    expect(result.longestStreakDays, 4);
    expect(result.workoutDaysThisWeek, 3);
    expect(result.workoutDaysThisMonth, 4);
  });

  test('yesterday keeps current streak alive when today has no workout', () {
    final result = WorkoutConsistencyAnalytics.summarize(
      [
        session(id: 'yesterday', endedAt: DateTime(2026, 9, 9, 23, 59)),
        session(id: 'two-days', endedAt: DateTime(2026, 9, 8, 0, 1)),
      ],
      profileId: 'me',
      now: DateTime(2026, 9, 10, 12),
    );

    expect(result.currentStreakDays, 2);
    expect(result.longestStreakDays, 2);
  });

  test('missed day breaks current streak', () {
    final result = WorkoutConsistencyAnalytics.summarize(
      [session(id: 'older', endedAt: DateTime(2026, 9, 8, 12))],
      profileId: 'me',
      now: DateTime(2026, 9, 10, 12),
    );

    expect(result.currentStreakDays, 0);
    expect(result.longestStreakDays, 1);
  });

  test('ignores incomplete sessions and other profiles', () {
    final result = WorkoutConsistencyAnalytics.summarize(
      [
        session(
          id: 'incomplete',
          endedAt: DateTime(2026, 9, 10, 8),
          status: WorkoutSessionStatus.incomplete,
        ),
        session(
          id: 'other',
          endedAt: DateTime(2026, 9, 10, 9),
          profileId: 'other',
        ),
      ],
      profileId: 'me',
      now: DateTime(2026, 9, 10, 12),
    );

    expect(result.currentStreakDays, 0);
    expect(result.longestStreakDays, 0);
    expect(result.workoutDaysThisWeek, 0);
    expect(result.workoutDaysThisMonth, 0);
  });
}
