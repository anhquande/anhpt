import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_history_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/widgets/home_weekly_workout_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  required String name,
  required String profileId,
  required DateTime endedAt,
  Duration duration = const Duration(minutes: 10),
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
  int completedSteps = 3,
  int totalSteps = 3,
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'workout-$id',
      workoutName: name,
      profileId: profileId,
      profileName: profileId,
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      activeDuration: duration,
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      status: status,
    );

Future<void> _useTallHistorySurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('history is scoped to the selected local profile', (tester) async {
    await _useTallHistorySurface(tester);
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final now = DateTime.now();
    await store.saveWorkoutSessions([
      _session(
        id: 'mine',
        name: 'My Workout',
        profileId: 'me',
        endedAt: now,
      ),
      _session(
        id: 'other',
        name: 'Other Workout',
        profileId: 'other',
        endedAt: now,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(store: store, profileId: 'me'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Workout'), findsOneWidget);
    expect(find.text('Other Workout'), findsNothing);
  });

  testWidgets('history sorts newest first, groups by day, and marks incomplete',
      (tester) async {
    await _useTallHistorySurface(tester);
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final now = DateTime.now();
    await store.saveWorkoutSessions([
      _session(
        id: 'older',
        name: 'Older Workout',
        profileId: 'me',
        endedAt: now.subtract(const Duration(hours: 2)),
      ),
      _session(
        id: 'yesterday',
        name: 'Yesterday Workout',
        profileId: 'me',
        endedAt: now.subtract(const Duration(days: 1, hours: 1)),
      ),
      _session(
        id: 'newer',
        name: 'Newer Workout',
        profileId: 'me',
        endedAt: now.subtract(const Duration(minutes: 10)),
        duration: const Duration(minutes: 7),
        status: WorkoutSessionStatus.incomplete,
        completedSteps: 2,
        totalSteps: 4,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(store: store, profileId: 'me'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    final incompleteSession = find.byKey(
      const ValueKey('workout-history-session-newer'),
    );
    expect(incompleteSession, findsOneWidget);
    expect(
      find.descendant(
        of: incompleteSession,
        matching: find.text('Incomplete'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('7 min'), findsOneWidget);
    expect(find.textContaining('2/4 steps'), findsOneWidget);

    final newerY = tester.getTopLeft(find.text('Newer Workout')).dy;
    final olderY = tester.getTopLeft(find.text('Older Workout')).dy;
    final yesterdayY = tester.getTopLeft(find.text('Yesterday Workout')).dy;
    expect(newerY, lessThan(olderY));
    expect(olderY, lessThan(yesterdayY));
  });

  testWidgets('history has a calm empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();

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

    expect(find.text('No workout history yet'), findsOneWidget);
    expect(find.text('Workout sessions for Me will appear here.'), findsOneWidget);
  });

  testWidgets('Home weekly feedback opens workout history', (tester) async {
    await _useTallHistorySurface(tester);
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.saveWorkoutSessions([
      _session(
        id: 'home',
        name: 'Home Demo',
        profileId: 'me',
        endedAt: DateTime.now(),
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

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('1 workout • 10 min'));
    await tester.pumpAndSettle();

    expect(find.text('Workout history'), findsOneWidget);
    expect(find.text('Home Demo'), findsOneWidget);
  });
}
