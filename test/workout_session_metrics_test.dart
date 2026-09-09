import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_session_detail_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_analytics.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({
  required String id,
  required DateTime endedAt,
  int? calories,
  WorkoutSessionEffort? effort,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
  String profileId = 'me',
}) =>
    WorkoutSession(
      id: id,
      workoutId: 'demo',
      workoutName: 'Demo Workout',
      profileId: profileId,
      profileName: 'Me',
      startedAt: endedAt.subtract(const Duration(minutes: 20)),
      endedAt: endedAt,
      activeDuration: const Duration(minutes: 20),
      completedSteps: status == WorkoutSessionStatus.completed ? 4 : 2,
      totalSteps: 4,
      status: status,
      estimatedCalories: calories,
      effort: effort,
    );

void main() {
  test('session metrics round trip and old data remains compatible', () {
    final original = _session(
      id: 'metrics',
      endedAt: DateTime(2026, 9, 9, 20),
      calories: 135,
      effort: WorkoutSessionEffort.moderate,
    );
    final restored = WorkoutSession.fromJson(original.toJson());
    expect(restored.estimatedCalories, 135);
    expect(restored.effort, WorkoutSessionEffort.moderate);

    final legacy = Map<String, dynamic>.from(original.toJson())
      ..remove('estimatedCalories')
      ..remove('effort');
    final oldSession = WorkoutSession.fromJson(legacy);
    expect(oldSession.estimatedCalories, isNull);
    expect(oldSession.effort, isNull);
  });

  test('updating metrics changes only the targeted session and can clear values',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final first = _session(id: 'first', endedAt: DateTime(2026, 9, 9, 20));
    final second = _session(id: 'second', endedAt: DateTime(2026, 9, 9, 21));
    await store.saveWorkoutSessions([first, second]);
    final history = WorkoutSessionHistory(store);

    final updated = await history.updateMetrics(
      sessionId: 'first',
      estimatedCalories: 210,
      effort: WorkoutSessionEffort.hard,
    );
    expect(updated?.estimatedCalories, 210);
    expect(updated?.effort, WorkoutSessionEffort.hard);

    var persisted = await store.loadWorkoutSessions();
    expect(persisted.first.estimatedCalories, 210);
    expect(persisted.first.effort, WorkoutSessionEffort.hard);
    expect(persisted.last.estimatedCalories, isNull);

    final cleared = await history.updateMetrics(
      sessionId: 'first',
      estimatedCalories: null,
      effort: null,
    );
    expect(cleared?.estimatedCalories, isNull);
    expect(cleared?.effort, isNull);
  });

  test('weekly and monthly calories include completed sessions in profile only', () {
    final sessions = [
      _session(
        id: 'one',
        endedAt: DateTime(2026, 9, 8, 10),
        calories: 100,
      ),
      _session(
        id: 'two',
        endedAt: DateTime(2026, 9, 9, 10),
        calories: 150,
      ),
      _session(
        id: 'incomplete',
        endedAt: DateTime(2026, 9, 9, 11),
        calories: 999,
        status: WorkoutSessionStatus.incomplete,
      ),
      _session(
        id: 'other',
        endedAt: DateTime(2026, 9, 9, 12),
        calories: 500,
        profileId: 'other',
      ),
    ];

    final weekly = WorkoutSessionAnalytics.weeklySummary(
      sessions,
      now: DateTime(2026, 9, 9),
      profileId: 'me',
    );
    final monthly = WorkoutSessionAnalytics.monthlySummary(
      sessions,
      now: DateTime(2026, 9, 9),
      profileId: 'me',
    );

    expect(weekly.totalCalories, 250);
    expect(monthly.totalCalories, 250);
  });

  testWidgets('session detail edits displays and clears metrics', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final session = _session(id: 'ui', endedAt: DateTime(2026, 9, 9, 20));
    await store.saveWorkoutSessions([session]);
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: WorkoutSessionDetailScreen(session: session)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('session-detail-edit-metrics')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('session-detail-calories-editor')),
      '180',
    );
    await tester.tap(find.byKey(const Key('session-detail-effort-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hard').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-detail-save-metrics')));
    await tester.pumpAndSettle();

    expect(find.text('180 kcal'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    var persisted = await store.loadWorkoutSessions();
    expect(persisted.single.estimatedCalories, 180);
    expect(persisted.single.effort, WorkoutSessionEffort.hard);

    await tester.tap(find.byKey(const Key('session-detail-edit-metrics')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('session-detail-calories-editor')),
      '',
    );
    await tester.tap(find.byKey(const Key('session-detail-effort-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not set').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-detail-save-metrics')));
    await tester.pumpAndSettle();

    persisted = await store.loadWorkoutSessions();
    expect(persisted.single.estimatedCalories, isNull);
    expect(persisted.single.effort, isNull);
  });
}
