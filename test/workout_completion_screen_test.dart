import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_completion_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('completion summary fits a small phone and hides unavailable data',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutCompletionScreen(
          workoutName: 'Morning Mobility',
          profileName: 'Lilly',
          activeTime: Duration(minutes: 12, seconds: 34),
          completedSteps: 6,
          totalSteps: 6,
          progress: 1,
        ),
      ),
    );

    expect(find.text('Workout complete 🎉'), findsOneWidget);
    expect(find.text('Morning Mobility'), findsOneWidget);
    expect(find.text('Lilly'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('6 / 6'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Estimated calories'), findsNothing);
    expect(find.text('View progress'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completion summary shows optional backed metrics only when supplied',
      (tester) async {
    var viewedProgress = false;

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutCompletionScreen(
          workoutName: 'Strength Demo',
          activeTime: const Duration(minutes: 20),
          completedSteps: 8,
          totalSteps: 8,
          progress: 1,
          estimatedCalories: 85,
          progressContext: 'You trained 3 times this week.',
          onViewProgress: () => viewedProgress = true,
        ),
      ),
    );

    expect(find.text('~85 kcal'), findsOneWidget);
    expect(find.text('Estimated calories'), findsOneWidget);
    expect(find.text('You trained 3 times this week.'), findsOneWidget);
    expect(find.text('View progress'), findsOneWidget);

    await tester.ensureVisible(find.text('View progress'));
    await tester.tap(find.text('View progress'));
    expect(viewedProgress, isTrue);
  });

  testWidgets('Done uses supplied completion action', (tester) async {
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutCompletionScreen(
          workoutName: 'Quick Workout',
          activeTime: const Duration(minutes: 5),
          completedSteps: 3,
          totalSteps: 3,
          progress: 1,
          onDone: () => done = true,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    expect(done, isTrue);
  });

  testWidgets('completion reads weekly feedback without recording another session',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await WorkoutSessionHistory(store).record(
      workoutId: 'weekly-demo',
      workoutName: 'Weekly Demo',
      profileId: 'me',
      profileName: 'Me',
      activeDuration: const Duration(minutes: 7),
      completedSteps: 4,
      totalSteps: 4,
      status: WorkoutSessionStatus.completed,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: WorkoutCompletionScreen(
          workoutName: 'Weekly Demo',
          profileId: 'me',
          profileName: 'Me',
          activeTime: Duration(minutes: 7),
          completedSteps: 4,
          totalSteps: 4,
          progress: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('1 workout • 7 min'), findsOneWidget);

    final sessions = await store.loadWorkoutSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.workoutId, 'weekly-demo');
  });
}
