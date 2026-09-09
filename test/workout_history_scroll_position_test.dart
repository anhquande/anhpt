import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_history_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session(int index, DateTime endedAt) => WorkoutSession(
      id: 'session-$index',
      workoutId: 'workout-${index % 3}',
      workoutName: 'Workout ${index % 3}',
      profileId: 'me',
      profileName: 'Me',
      startedAt: endedAt.subtract(const Duration(minutes: 12)),
      endedAt: endedAt,
      activeDuration: const Duration(minutes: 12),
      completedSteps: index.isEven ? 4 : 2,
      totalSteps: 4,
      status: index.isEven
          ? WorkoutSessionStatus.completed
          : WorkoutSessionStatus.incomplete,
    );

void main() {
  testWidgets('changing history filter preserves scroll position', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final now = DateTime.now();
    await store.saveWorkoutSessions([
      for (var index = 0; index < 24; index++)
        _session(index, now.subtract(Duration(hours: index * 3))),
    ]);

    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    final listFinder = find.byKey(
      const PageStorageKey<String>('workout-history-list'),
    );
    expect(listFinder, findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('workout-history-status-completed')),
      220,
      scrollable: find.descendant(
        of: listFinder,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    final beforeController = tester.widget<ListView>(listFinder).controller!;
    final before = beforeController.offset;
    expect(before, greaterThan(0));

    await tester.tap(
      find.byKey(const ValueKey('workout-history-status-completed')),
    );
    await tester.pumpAndSettle();

    final afterController = tester.widget<ListView>(listFinder).controller!;
    final after = afterController.offset;
    expect(after, closeTo(before, 1));
    expect(
      find.byKey(const ValueKey('workout-history-status-completed')),
      findsOneWidget,
    );
  });
}
