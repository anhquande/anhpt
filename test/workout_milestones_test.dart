import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/workout_milestone_analytics.dart';
import 'package:anhpt/widgets/workout_milestones_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String profileId,
  required DateTime endedAt,
  Duration duration = const Duration(minutes: 20),
  bool completed = true,
}) {
  return WorkoutSession(
    id: id,
    workoutId: 'workout-$id',
    workoutName: 'Workout $id',
    profileId: profileId,
    startedAt: endedAt.subtract(duration),
    endedAt: endedAt,
    activeDuration: duration,
    completedSteps: completed ? 3 : 1,
    totalSteps: 3,
    status: completed
        ? WorkoutSessionStatus.completed
        : WorkoutSessionStatus.incomplete,
  );
}

void main() {
  test('milestones use completed sessions from selected profile only', () {
    final now = DateTime(2026, 9, 10, 18);
    final sessions = [
      _session(id: '1', profileId: 'me', endedAt: DateTime(2026, 9, 8, 18)),
      _session(id: '2', profileId: 'me', endedAt: DateTime(2026, 9, 9, 18)),
      _session(id: '3', profileId: 'me', endedAt: DateTime(2026, 9, 10, 18)),
      _session(id: 'other', profileId: 'other', endedAt: now),
      _session(id: 'partial', profileId: 'me', endedAt: now, completed: false),
    ];

    final summary = WorkoutMilestoneAnalytics.summarize(
      sessions,
      profileId: 'me',
      now: now,
    );

    expect(summary.unlockedMilestones.map((item) => item.id), containsAll([
      WorkoutMilestoneId.firstWorkout,
      WorkoutMilestoneId.sixtyMinutes,
      WorkoutMilestoneId.threeDayStreak,
    ]));
    expect(summary.unlockedMilestones.map((item) => item.id),
        isNot(contains(WorkoutMilestoneId.fiveWorkouts)));
  });

  test('count and duration milestones unlock at thresholds', () {
    final sessions = List.generate(
      10,
      (index) => _session(
        id: '$index',
        profileId: 'me',
        endedAt: DateTime(2026, 8, 1).add(Duration(days: index * 2)),
        duration: const Duration(minutes: 30),
      ),
    );

    final summary = WorkoutMilestoneAnalytics.summarize(
      sessions,
      profileId: 'me',
      now: DateTime(2026, 9, 10),
    );

    expect(summary.unlockedMilestones.map((item) => item.id), containsAll([
      WorkoutMilestoneId.firstWorkout,
      WorkoutMilestoneId.fiveWorkouts,
      WorkoutMilestoneId.tenWorkouts,
      WorkoutMilestoneId.sixtyMinutes,
      WorkoutMilestoneId.threeHundredMinutes,
    ]));
    expect(summary.unlockedMilestones.map((item) => item.id),
        isNot(contains(WorkoutMilestoneId.threeDayStreak)));
  });

  test('empty history is safe and has no next progress activity', () {
    final summary = WorkoutMilestoneAnalytics.summarize(
      const <WorkoutSession>[],
      profileId: 'me',
    );

    expect(summary.hasActivity, isFalse);
    expect(summary.unlockedCount, 0);
    expect(summary.nextMilestone?.id, WorkoutMilestoneId.firstWorkout);
  });

  testWidgets('achievement card shows unlocked badges and next progress',
      (tester) async {
    final summary = WorkoutMilestoneAnalytics.summarize([
      _session(
        id: 'one',
        profileId: 'me',
        endedAt: DateTime(2026, 9, 10),
        duration: const Duration(minutes: 20),
      ),
    ], profileId: 'me', now: DateTime(2026, 9, 10));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutMilestonesCard(summary: summary)),
      ),
    );

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);
    expect(find.text('First workout'), findsOneWidget);
    expect(find.byKey(const Key('workout-next-milestone')), findsOneWidget);
    expect(find.byKey(const Key('workout-next-milestone-progress')), findsOneWidget);
  });
}
