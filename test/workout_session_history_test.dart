import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_analytics.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession session({
  required String id,
  required DateTime endedAt,
  required Duration duration,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
  String? profileId = 'me',
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'workout-$id',
      workoutName: 'Workout $id',
      profileId: profileId,
      profileName: profileId == null ? null : 'Profile $profileId',
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      activeDuration: duration,
      completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
      totalSteps: 4,
      status: status,
    );

void main() {
  test('workout session round trips through LocalStore', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final original = session(
      id: 'one',
      endedAt: DateTime(2026, 9, 8, 18, 30),
      duration: const Duration(minutes: 12, seconds: 5),
    );

    await store.saveWorkoutSessions([original]);
    final loaded = await store.loadWorkoutSessions();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'one');
    expect(loaded.single.workoutId, 'workout-one');
    expect(loaded.single.profileId, 'me');
    expect(loaded.single.activeDuration, const Duration(minutes: 12, seconds: 5));
    expect(loaded.single.status, WorkoutSessionStatus.completed);
  });

  test('weekly summary uses Monday boundary and ignores incomplete sessions', () {
    final summary = WorkoutSessionAnalytics.weeklySummary(
      [
        session(
          id: 'monday',
          endedAt: DateTime(2026, 9, 7),
          duration: const Duration(minutes: 10),
        ),
        session(
          id: 'tuesday',
          endedAt: DateTime(2026, 9, 8, 20),
          duration: const Duration(minutes: 20),
        ),
        session(
          id: 'incomplete',
          endedAt: DateTime(2026, 9, 8, 21),
          duration: const Duration(minutes: 8),
          status: WorkoutSessionStatus.incomplete,
        ),
        session(
          id: 'previous-sunday',
          endedAt: DateTime(2026, 9, 6, 23, 59),
          duration: const Duration(minutes: 15),
        ),
      ],
      now: DateTime(2026, 9, 8, 22),
      profileId: 'me',
    );

    expect(summary.weekStart, DateTime(2026, 9, 7));
    expect(summary.completedWorkouts, 2);
    expect(summary.activeDuration, const Duration(minutes: 30));
    expect(summary.previousCompletedWorkouts, 1);
    expect(summary.previousActiveDuration, const Duration(minutes: 15));
  });

  test('weekly summary keeps local profiles separate when requested', () {
    final sessions = [
      session(
        id: 'me',
        endedAt: DateTime(2026, 9, 8, 10),
        duration: const Duration(minutes: 10),
        profileId: 'me',
      ),
      session(
        id: 'lilly',
        endedAt: DateTime(2026, 9, 8, 11),
        duration: const Duration(minutes: 25),
        profileId: 'lilly',
      ),
    ];

    final me = WorkoutSessionAnalytics.weeklySummary(
      sessions,
      now: DateTime(2026, 9, 8),
      profileId: 'me',
    );
    final all = WorkoutSessionAnalytics.weeklySummary(
      sessions,
      now: DateTime(2026, 9, 8),
    );

    expect(me.completedWorkouts, 1);
    expect(me.activeDuration, const Duration(minutes: 10));
    expect(all.completedWorkouts, 2);
    expect(all.activeDuration, const Duration(minutes: 35));
  });

  test('monthly summary uses local month boundary and previous month context', () {
    final summary = WorkoutSessionAnalytics.monthlySummary(
      [
        session(
          id: 'month-start',
          endedAt: DateTime(2026, 9, 1),
          duration: const Duration(minutes: 10),
        ),
        session(
          id: 'current',
          endedAt: DateTime(2026, 9, 8, 20),
          duration: const Duration(minutes: 20),
        ),
        session(
          id: 'incomplete',
          endedAt: DateTime(2026, 9, 8, 21),
          duration: const Duration(minutes: 8),
          status: WorkoutSessionStatus.incomplete,
        ),
        session(
          id: 'previous-last-day',
          endedAt: DateTime(2026, 8, 31, 23, 59),
          duration: const Duration(minutes: 15),
        ),
        session(
          id: 'older',
          endedAt: DateTime(2026, 7, 31, 23, 59),
          duration: const Duration(minutes: 30),
        ),
      ],
      now: DateTime(2026, 9, 8, 22),
      profileId: 'me',
    );

    expect(summary.monthStart, DateTime(2026, 9));
    expect(summary.completedWorkouts, 2);
    expect(summary.activeDuration, const Duration(minutes: 30));
    expect(summary.previousCompletedWorkouts, 1);
    expect(summary.previousActiveDuration, const Duration(minutes: 15));
  });

  test('monthly summary keeps profiles separate', () {
    final sessions = [
      session(
        id: 'me',
        endedAt: DateTime(2026, 9, 8),
        duration: const Duration(minutes: 10),
        profileId: 'me',
      ),
      session(
        id: 'other',
        endedAt: DateTime(2026, 9, 9),
        duration: const Duration(minutes: 25),
        profileId: 'other',
      ),
    ];

    final me = WorkoutSessionAnalytics.monthlySummary(
      sessions,
      now: DateTime(2026, 9, 10),
      profileId: 'me',
    );

    expect(me.completedWorkouts, 1);
    expect(me.activeDuration, const Duration(minutes: 10));
  });

  test('history record immediately contributes to current weekly feedback', () async {
    SharedPreferences.setMockInitialValues({});
    final history = WorkoutSessionHistory(LocalStore());
    final endedAt = DateTime(2026, 9, 8, 19);

    await history.record(
      workoutId: 'demo',
      workoutName: 'Demo Workout',
      profileId: 'me',
      profileName: 'Me',
      activeDuration: const Duration(minutes: 7),
      completedSteps: 3,
      totalSteps: 3,
      status: WorkoutSessionStatus.completed,
      endedAt: endedAt,
    );

    final weekly = await history.weeklySummary(
      now: endedAt,
      profileId: 'me',
    );
    final monthly = await history.monthlySummary(
      now: endedAt,
      profileId: 'me',
    );

    expect(weekly.completedWorkouts, 1);
    expect(weekly.activeDuration, const Duration(minutes: 7));
    expect(monthly.completedWorkouts, 1);
    expect(monthly.activeDuration, const Duration(minutes: 7));
  });
}
