import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_personal_bests_analytics.dart';
import 'package:anhpt/widgets/workout_personal_bests_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String workoutId,
  required String name,
  required String profileId,
  required DateTime endedAt,
  Duration duration = const Duration(minutes: 10),
  int steps = 3,
  int? calories,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) =>
    WorkoutSession(
      id: id,
      workoutId: workoutId,
      workoutName: name,
      profileId: profileId,
      profileName: profileId,
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      activeDuration: duration,
      completedSteps: steps,
      totalSteps: steps,
      status: status,
      estimatedCalories: calories,
    );

void main() {
  test('personal bests use completed sessions from selected profile only', () {
    final now = DateTime(2026, 9, 10, 12);
    final summary = WorkoutPersonalBestsAnalytics.summarize([
      _session(
        id: 'short',
        workoutId: 'flow',
        name: 'Flow',
        profileId: 'me',
        endedAt: now.subtract(const Duration(days: 2)),
        duration: const Duration(minutes: 12),
        steps: 8,
        calories: 90,
      ),
      _session(
        id: 'long',
        workoutId: 'strength',
        name: 'Strength',
        profileId: 'me',
        endedAt: now,
        duration: const Duration(minutes: 30),
        steps: 5,
        calories: 180,
      ),
      _session(
        id: 'flow-2',
        workoutId: 'flow',
        name: 'Flow',
        profileId: 'me',
        endedAt: now.subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 14),
        steps: 10,
      ),
      _session(
        id: 'incomplete',
        workoutId: 'other',
        name: 'Incomplete',
        profileId: 'me',
        endedAt: now,
        duration: const Duration(minutes: 60),
        steps: 50,
        calories: 500,
        status: WorkoutSessionStatus.incomplete,
      ),
      _session(
        id: 'profile-other',
        workoutId: 'other',
        name: 'Other profile',
        profileId: 'other',
        endedAt: now,
        duration: const Duration(minutes: 90),
        steps: 99,
        calories: 900,
      ),
    ], profileId: 'me');

    expect(summary.longestWorkout?.id, 'long');
    expect(summary.mostStepsWorkout?.id, 'flow-2');
    expect(summary.highestCaloriesWorkout?.id, 'long');
    expect(summary.mostCompletedWorkoutId, 'flow');
    expect(summary.mostCompletedCount, 2);
  });

  test('ties prefer the most recent completed session', () {
    final older = DateTime(2026, 9, 8, 12);
    final newer = DateTime(2026, 9, 9, 12);
    final summary = WorkoutPersonalBestsAnalytics.summarize([
      _session(
        id: 'older',
        workoutId: 'a',
        name: 'A',
        profileId: 'me',
        endedAt: older,
        duration: const Duration(minutes: 20),
        steps: 10,
        calories: 100,
      ),
      _session(
        id: 'newer',
        workoutId: 'b',
        name: 'B',
        profileId: 'me',
        endedAt: newer,
        duration: const Duration(minutes: 20),
        steps: 10,
        calories: 100,
      ),
    ], profileId: 'me');

    expect(summary.longestWorkout?.id, 'newer');
    expect(summary.mostStepsWorkout?.id, 'newer');
    expect(summary.highestCaloriesWorkout?.id, 'newer');
    expect(summary.mostCompletedWorkoutId, 'b');
  });

  test('empty history and missing calories stay safe', () {
    expect(
      WorkoutPersonalBestsAnalytics.summarize(const []).hasRecords,
      isFalse,
    );
    final summary = WorkoutPersonalBestsAnalytics.summarize([
      _session(
        id: 'one',
        workoutId: 'flow',
        name: 'Flow',
        profileId: 'me',
        endedAt: DateTime(2026, 9, 10),
      ),
    ], profileId: 'me');
    expect(summary.highestCaloriesWorkout, isNull);
  });

  testWidgets('personal bests card renders available records only',
      (tester) async {
    final session = _session(
      id: 'one',
      workoutId: 'flow',
      name: 'Morning Flow',
      profileId: 'me',
      endedAt: DateTime(2026, 9, 10),
      duration: const Duration(minutes: 15),
      steps: 7,
    );
    final summary = WorkoutPersonalBestsAnalytics.summarize([session]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutPersonalBestsCard(summary: summary)),
      ),
    );

    expect(find.text('Personal bests'), findsOneWidget);
    expect(find.textContaining('15m'), findsOneWidget);
    expect(find.textContaining('7'), findsWidgets);
    expect(find.text('Most calories'), findsNothing);
    expect(find.textContaining('1×'), findsOneWidget);
  });
}
