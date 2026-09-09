import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_history_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  required String workoutId,
  required String workoutName,
  required WorkoutSessionStatus status,
}) {
  final endedAt = DateTime.now().subtract(Duration(hours: id == 'done' ? 1 : 2));
  return WorkoutSession(
    id: id,
    workoutId: workoutId,
    workoutName: workoutName,
    profileId: 'me',
    profileName: 'Me',
    startedAt: endedAt.subtract(const Duration(minutes: 10)),
    endedAt: endedAt,
    activeDuration: const Duration(minutes: 10),
    completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
    totalSteps: 4,
    status: status,
  );
}

void main() {
  testWidgets('history shows filter controls and matching session count',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.saveWorkoutSessions([
      _session(
        id: 'done',
        workoutId: 'mobility',
        workoutName: 'Mobility',
        status: WorkoutSessionStatus.completed,
      ),
      _session(
        id: 'partial',
        workoutId: 'plank',
        workoutName: 'Plank',
        status: WorkoutSessionStatus.incomplete,
      ),
    ]);
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(store: store, profileId: 'me'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workout-history-filters')), findsOneWidget);
    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.text('Mobility'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
  });

  testWidgets('status filter updates results and clear restores all sessions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.saveWorkoutSessions([
      _session(
        id: 'done',
        workoutId: 'mobility',
        workoutName: 'Mobility',
        status: WorkoutSessionStatus.completed,
      ),
      _session(
        id: 'partial',
        workoutId: 'plank',
        workoutName: 'Plank',
        status: WorkoutSessionStatus.incomplete,
      ),
    ]);
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(store: store, profileId: 'me'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('workout-history-status-incomplete')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 session'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-history-session-partial')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('workout-history-session-done')),
        findsNothing);
    expect(find.byKey(const Key('workout-history-clear-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('workout-history-clear-filters')));
    await tester.pumpAndSettle();

    expect(find.text('2 sessions'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-history-session-done')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('workout-history-session-partial')),
        findsOneWidget);
    expect(find.byKey(const Key('workout-history-clear-filters')), findsNothing);
  });

  testWidgets('empty filtered results keep filter controls visible',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.saveWorkoutSessions([
      _session(
        id: 'done',
        workoutId: 'mobility',
        workoutName: 'Mobility',
        status: WorkoutSessionStatus.completed,
      ),
    ]);
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(store: store, profileId: 'me'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('workout-history-status-incomplete')),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 sessions'), findsOneWidget);
    expect(find.byKey(const Key('workout-history-filter-empty')), findsOneWidget);
    expect(find.byKey(const Key('workout-history-filters')), findsOneWidget);
    expect(find.byKey(const Key('workout-history-clear-filters')), findsOneWidget);
  });
}
