import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_history_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_analytics.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:anhpt/widgets/yearly_workout_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  required DateTime endedAt,
  required Duration duration,
  String profileId = 'me',
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'workout-$id',
      workoutName: 'Workout $id',
      profileId: profileId,
      profileName: profileId,
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      activeDuration: duration,
      completedSteps: status == WorkoutSessionStatus.completed ? 3 : 1,
      totalSteps: 3,
      status: status,
    );

void main() {
  test('yearly summary uses local year boundaries and monthly buckets', () {
    final summary = WorkoutSessionAnalytics.yearlySummary(
      [
        _session(
          id: 'jan',
          endedAt: DateTime(2026, 1, 1),
          duration: const Duration(minutes: 10),
        ),
        _session(
          id: 'sep',
          endedAt: DateTime(2026, 9, 8, 20),
          duration: const Duration(minutes: 20),
        ),
        _session(
          id: 'incomplete',
          endedAt: DateTime(2026, 9, 8, 21),
          duration: const Duration(minutes: 8),
          status: WorkoutSessionStatus.incomplete,
        ),
        _session(
          id: 'previous-start',
          endedAt: DateTime(2025, 1, 1),
          duration: const Duration(minutes: 5),
        ),
        _session(
          id: 'previous-end',
          endedAt: DateTime(2025, 12, 31, 23, 59),
          duration: const Duration(minutes: 15),
        ),
        _session(
          id: 'future',
          endedAt: DateTime(2027, 1, 1),
          duration: const Duration(minutes: 99),
        ),
      ],
      now: DateTime(2026, 9, 9),
      profileId: 'me',
    );

    expect(summary.yearStart, DateTime(2026));
    expect(summary.completedWorkouts, 2);
    expect(summary.activeDuration, const Duration(minutes: 30));
    expect(summary.previousCompletedWorkouts, 2);
    expect(summary.previousActiveDuration, const Duration(minutes: 20));
    expect(summary.months, hasLength(12));
    expect(summary.months[0].completedWorkouts, 1);
    expect(summary.months[0].activeDuration, const Duration(minutes: 10));
    expect(summary.months[8].completedWorkouts, 1);
    expect(summary.months[8].activeDuration, const Duration(minutes: 20));
    expect(summary.months[11].completedWorkouts, 0);
  });

  test('yearly summary keeps profiles separate', () {
    final summary = WorkoutSessionAnalytics.yearlySummary(
      [
        _session(
          id: 'mine',
          endedAt: DateTime(2026, 4, 10),
          duration: const Duration(minutes: 12),
        ),
        _session(
          id: 'other',
          endedAt: DateTime(2026, 4, 11),
          duration: const Duration(minutes: 30),
          profileId: 'other',
        ),
      ],
      now: DateTime(2026, 9, 9),
      profileId: 'me',
    );

    expect(summary.completedWorkouts, 1);
    expect(summary.activeDuration, const Duration(minutes: 12));
    expect(summary.months[3].completedWorkouts, 1);
  });

  test('persisted history contributes to yearly summary', () async {
    SharedPreferences.setMockInitialValues({});
    final history = WorkoutSessionHistory(LocalStore());
    final endedAt = DateTime(2026, 6, 15, 18);

    await history.record(
      workoutId: 'demo',
      workoutName: 'Demo Workout',
      profileId: 'me',
      profileName: 'Me',
      activeDuration: const Duration(minutes: 18),
      completedSteps: 4,
      totalSteps: 4,
      status: WorkoutSessionStatus.completed,
      endedAt: endedAt,
    );

    final summary = await history.yearlySummary(
      now: endedAt,
      profileId: 'me',
    );

    expect(summary.completedWorkouts, 1);
    expect(summary.activeDuration, const Duration(minutes: 18));
    expect(summary.months[5].completedWorkouts, 1);
  });

  testWidgets('yearly progress card shows totals and monthly breakdown',
      (tester) async {
    final months = List<MonthlyWorkoutBucket>.generate(
      12,
      (index) => MonthlyWorkoutBucket(
        month: index + 1,
        completedWorkouts: index == 0 || index == 8 ? 1 : 0,
        activeDuration: index == 0
            ? const Duration(minutes: 10)
            : index == 8
                ? const Duration(minutes: 20)
                : Duration.zero,
      ),
    );
    final summary = YearlyWorkoutSummary(
      yearStart: DateTime(2026),
      completedWorkouts: 2,
      activeDuration: const Duration(minutes: 30),
      previousCompletedWorkouts: 1,
      previousActiveDuration: const Duration(minutes: 15),
      months: months,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: YearlyWorkoutProgressCard(summary: summary),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('yearly-workout-progress-card')), findsOneWidget);
    expect(find.text('2026 overview'), findsOneWidget);
    expect(find.text('2 workouts • 30 min'), findsOneWidget);
    expect(find.text('Previous year: 1 workout • 15 min'), findsOneWidget);
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Sep'), findsOneWidget);
    expect(find.text('1 • 10 min'), findsOneWidget);
    expect(find.text('1 • 20 min'), findsOneWidget);
  });

  testWidgets('workout history exposes yearly progress for active profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.saveWorkoutSessions([
      _session(
        id: 'history',
        endedAt: DateTime.now(),
        duration: const Duration(minutes: 11),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(
          store: store,
          profileId: 'me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('yearly-workout-progress-card')), findsOneWidget);
    expect(find.text('${DateTime.now().year} overview'), findsOneWidget);
  });
}
