import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:anhpt/widgets/home_weekly_workout_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  required String profileId,
  required Duration duration,
  required DateTime endedAt,
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
      completedSteps: 3,
      totalSteps: 3,
      status: WorkoutSessionStatus.completed,
    );

void main() {
  testWidgets('Home weekly feedback is scoped to the active profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final now = DateTime.now();
    await store.saveWorkoutSessions([
      _session(
        id: 'me',
        profileId: 'me',
        duration: const Duration(minutes: 10),
        endedAt: now,
      ),
      _session(
        id: 'other',
        profileId: 'other',
        duration: const Duration(minutes: 25),
        endedAt: now,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeWeeklyWorkoutFeedback(
            store: store,
            profileId: 'me',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('1 workout • 10 min'), findsOneWidget);
    expect(find.textContaining('35 min'), findsNothing);
  });

  testWidgets('Home feedback refreshes when a completed session is recorded',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final history = WorkoutSessionHistory(store);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeWeeklyWorkoutFeedback(
            store: store,
            profileId: 'me',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No completed workouts yet'), findsOneWidget);

    await history.record(
      workoutId: 'demo',
      workoutName: 'Demo',
      profileId: 'me',
      profileName: 'Me',
      activeDuration: const Duration(minutes: 7),
      completedSteps: 3,
      totalSteps: 3,
      status: WorkoutSessionStatus.completed,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 workout • 7 min'), findsOneWidget);
  });
}
