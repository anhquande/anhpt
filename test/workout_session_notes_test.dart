import 'package:anhpt/models/workout_session.dart';
import 'package:anhpt/screens/workout_session_detail_screen.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_session_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _session({String? note}) => WorkoutSession(
      id: 'session-note',
      workoutId: 'demo',
      workoutName: 'Demo Workout',
      profileId: 'me',
      profileName: 'Me',
      startedAt: DateTime(2026, 9, 9, 12),
      endedAt: DateTime(2026, 9, 9, 12, 10),
      activeDuration: const Duration(minutes: 10),
      completedSteps: 4,
      totalSteps: 4,
      status: WorkoutSessionStatus.completed,
      note: note,
    );

void main() {
  test('workout session note round trips and old data remains compatible', () {
    final withNote = _session(note: ' Felt strong today. ');
    final restored = WorkoutSession.fromJson(withNote.toJson());
    expect(restored.note, 'Felt strong today.');

    final legacyJson = Map<String, dynamic>.from(withNote.toJson())..remove('note');
    expect(WorkoutSession.fromJson(legacyJson).note, isNull);
  });

  test('updating a note changes only the targeted session', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final target = _session();
    final other = WorkoutSession(
      id: 'other',
      workoutId: 'other-workout',
      workoutName: 'Other Workout',
      startedAt: DateTime(2026, 9, 8, 10),
      endedAt: DateTime(2026, 9, 8, 10, 5),
      activeDuration: const Duration(minutes: 5),
      completedSteps: 2,
      totalSteps: 2,
      status: WorkoutSessionStatus.completed,
      note: 'Keep me',
    );
    await store.saveWorkoutSessions([target, other]);

    final history = WorkoutSessionHistory(store);
    final updated = await history.updateNote(
      sessionId: target.id,
      note: '  Easier than last time  ',
    );

    expect(updated?.note, 'Easier than last time');
    final loaded = await store.loadWorkoutSessions();
    expect(loaded.firstWhere((item) => item.id == target.id).note,
        'Easier than last time');
    expect(loaded.firstWhere((item) => item.id == other.id).note, 'Keep me');

    await history.updateNote(sessionId: target.id, note: '   ');
    final cleared = await store.loadWorkoutSessions();
    expect(cleared.firstWhere((item) => item.id == target.id).note, isNull);
  });

  testWidgets('session detail adds edits and clears a persisted note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    final session = _session();
    await store.saveWorkoutSessions([session]);

    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: WorkoutSessionDetailScreen(session: session)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add a note about how this workout felt.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-detail-edit-note')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('session-detail-note-editor')),
      'Shoulders felt better today',
    );
    await tester.tap(find.byKey(const Key('session-detail-save-note')));
    await tester.pumpAndSettle();

    expect(find.text('Shoulders felt better today'), findsOneWidget);
    var loaded = await store.loadWorkoutSessions();
    expect(loaded.single.note, 'Shoulders felt better today');

    await tester.tap(find.byKey(const Key('session-detail-edit-note')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('session-detail-note-editor')),
      '',
    );
    await tester.tap(find.byKey(const Key('session-detail-save-note')));
    await tester.pumpAndSettle();

    expect(find.text('Add a note about how this workout felt.'), findsOneWidget);
    loaded = await store.loadWorkoutSessions();
    expect(loaded.single.note, isNull);
  });
}
