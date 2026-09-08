import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_history_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  required DateTime endedAt,
  required Duration duration,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
  String profileId = 'me',
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
  testWidgets('Workout History shows current and previous month progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 15, 10);

    await store.saveWorkoutSessions([
      _session(
        id: 'current-one',
        endedAt: DateTime(now.year, now.month, 2, 10),
        duration: const Duration(minutes: 10),
      ),
      _session(
        id: 'current-two',
        endedAt: DateTime(now.year, now.month, 3, 10),
        duration: const Duration(minutes: 20),
      ),
      _session(
        id: 'current-incomplete',
        endedAt: DateTime(now.year, now.month, 4, 10),
        duration: const Duration(minutes: 40),
        status: WorkoutSessionStatus.incomplete,
      ),
      _session(
        id: 'previous',
        endedAt: previousMonth,
        duration: const Duration(minutes: 15),
      ),
      _session(
        id: 'other-profile',
        endedAt: DateTime(now.year, now.month, 5, 10),
        duration: const Duration(minutes: 50),
        profileId: 'other',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(
          store: store,
          profileId: 'me',
          profileName: 'Me',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('monthly-workout-progress-card')), findsOneWidget);
    expect(find.text('2 workouts • 30 min'), findsOneWidget);
    expect(find.text('Previous month: 1 workout • 15 min'), findsOneWidget);
    expect(find.textContaining('70 min'), findsNothing);
    expect(find.textContaining('80 min'), findsNothing);
  });
}
