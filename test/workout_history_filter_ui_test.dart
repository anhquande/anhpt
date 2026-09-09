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
  Duration duration = const Duration(minutes: 10),
  int hoursAgo = 1,
}) {
  final endedAt = DateTime.now().subtract(Duration(hours: hoursAgo));
  return WorkoutSession(
    id: id,
    workoutId: workoutId,
    workoutName: workoutName,
    profileId: 'me',
    profileName: 'Me',
    startedAt: endedAt.subtract(duration),
    endedAt: endedAt,
    activeDuration: duration,
    completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
    totalSteps: 4,
    status: status,
  );
}

Future<LocalStore> _pumpHistory(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = LocalStore();
  await store.saveWorkoutSessions([
    _session(
      id: 'mobility',
      workoutId: 'mobility',
      workoutName: 'Morning Mobility',
      status: WorkoutSessionStatus.completed,
      duration: const Duration(minutes: 12),
      hoursAgo: 1,
    ),
    _session(
      id: 'plank',
      workoutId: 'plank',
      workoutName: 'High Plank',
      status: WorkoutSessionStatus.incomplete,
      duration: const Duration(minutes: 5),
      hoursAgo: 2,
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
  return store;
}

void main() {
  testWidgets('history shows search sort controls and matching session count',
      (tester) async {
    await _pumpHistory(tester);

    expect(find.byKey(const Key('workout-history-filters')), findsOneWidget);
    expect(find.byKey(const Key('workout-history-search')), findsOneWidget);
    expect(find.byKey(const Key('workout-history-sort')), findsOneWidget);
    expect(find.text('2 sessions'), findsOneWidget);
  });

  testWidgets('search narrows sessions by workout name', (tester) async {
    await _pumpHistory(tester);

    await tester.enterText(
      find.byKey(const Key('workout-history-search')),
      'MOBILITY',
    );
    await tester.pump();

    expect(find.text('1 session'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workout-history-session-mobility')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workout-history-session-plank')),
      findsNothing,
    );
    expect(find.byKey(const Key('workout-history-clear-filters')), findsOneWidget);
  });

  testWidgets('search combines with status filter and clear restores defaults',
      (tester) async {
    await _pumpHistory(tester);

    await tester.enterText(
      find.byKey(const Key('workout-history-search')),
      'plank',
    );
    await tester.tap(
      find.byKey(const ValueKey('workout-history-status-incomplete')),
    );
    await tester.pump();

    expect(find.text('1 session'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workout-history-session-plank')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('workout-history-clear-filters')));
    await tester.pump();

    expect(find.text('2 sessions'), findsOneWidget);
    final search = tester.widget<TextField>(
      find.byKey(const Key('workout-history-search')),
    );
    expect(search.controller?.text, isEmpty);
    expect(find.byKey(const Key('workout-history-clear-filters')), findsNothing);
  });

  testWidgets('empty search keeps controls visible', (tester) async {
    await _pumpHistory(tester);

    await tester.enterText(
      find.byKey(const Key('workout-history-search')),
      'does-not-exist',
    );
    await tester.pump();

    expect(find.text('0 sessions'), findsOneWidget);
    expect(find.byKey(const Key('workout-history-filter-empty')), findsOneWidget);
    expect(find.byKey(const Key('workout-history-search')), findsOneWidget);
    expect(find.byKey(const Key('workout-history-sort')), findsOneWidget);
  });
}
