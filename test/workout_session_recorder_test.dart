import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:anhpt/services/workout_session_recorder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records completed session with exact runtime context and timestamps',
      () async {
    final store = LocalStore();
    final startedAt = DateTime(2026, 9, 9, 8, 0, 5);
    final endedAt = DateTime(2026, 9, 9, 8, 12, 40);
    final recorder = WorkoutSessionRecorder(
      history: WorkoutSessionHistory(store),
      workoutId: 'installed-workout-id',
      workoutName: 'Morning Mobility',
      profileId: 'profile-a',
      profileName: 'Lilly',
      startedAt: startedAt,
    );

    final recorded = await recorder.recordTerminal(
      status: WorkoutSessionStatus.completed,
      activeDuration: const Duration(minutes: 10, seconds: 20),
      completedSteps: 6,
      totalSteps: 6,
      endedAt: endedAt,
    );

    expect(recorded, isNotNull);
    final sessions = await store.loadWorkoutSessions();
    expect(sessions, hasLength(1));
    final session = sessions.single;
    expect(session.workoutId, 'installed-workout-id');
    expect(session.workoutName, 'Morning Mobility');
    expect(session.profileId, 'profile-a');
    expect(session.profileName, 'Lilly');
    expect(session.startedAt, startedAt);
    expect(session.endedAt, endedAt);
    expect(session.activeDuration, const Duration(minutes: 10, seconds: 20));
    expect(session.completedSteps, 6);
    expect(session.totalSteps, 6);
    expect(session.status, WorkoutSessionStatus.completed);
  });

  test('records explicit early end as incomplete', () async {
    final store = LocalStore();
    final recorder = WorkoutSessionRecorder(
      history: WorkoutSessionHistory(store),
      workoutId: 'plank',
      workoutName: 'High Plank',
      profileId: 'me',
      profileName: 'Me',
      startedAt: DateTime(2026, 9, 9, 9),
    );

    await recorder.recordTerminal(
      status: WorkoutSessionStatus.incomplete,
      activeDuration: const Duration(minutes: 3),
      completedSteps: 2,
      totalSteps: 5,
      endedAt: DateTime(2026, 9, 9, 9, 4),
    );

    final session = (await store.loadWorkoutSessions()).single;
    expect(session.status, WorkoutSessionStatus.incomplete);
    expect(session.completedSteps, 2);
    expect(session.totalSteps, 5);
  });

  test('terminal recording is exactly once even when called repeatedly',
      () async {
    final store = LocalStore();
    final recorder = WorkoutSessionRecorder(
      history: WorkoutSessionHistory(store),
      workoutId: 'demo',
      workoutName: 'Demo',
      startedAt: DateTime(2026, 9, 9, 10),
    );

    final first = recorder.recordTerminal(
      status: WorkoutSessionStatus.completed,
      activeDuration: const Duration(minutes: 5),
      completedSteps: 3,
      totalSteps: 3,
      endedAt: DateTime(2026, 9, 9, 10, 5),
    );
    final second = recorder.recordTerminal(
      status: WorkoutSessionStatus.completed,
      activeDuration: const Duration(minutes: 5),
      completedSteps: 3,
      totalSteps: 3,
      endedAt: DateTime(2026, 9, 9, 10, 5, 1),
    );

    expect(await first, isNotNull);
    expect(await second, isNull);
    expect(recorder.recorded, isTrue);
    expect(await store.loadWorkoutSessions(), hasLength(1));
  });
}
