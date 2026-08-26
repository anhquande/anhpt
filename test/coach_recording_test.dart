import 'package:anhpt/models/coach_recording.dart';
import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('coach recording metadata round trips', () {
    final recording = CoachRecording(
        workoutId: 'workout-1',
        cue: 'workout_start',
        scope: 'description',
        profile: 'energetic_coach',
        language: 'vi-VN',
        audioPath: r'C:\recordings\start.m4a',
        createdAt: DateTime.utc(2026, 8, 26));
    final restored = CoachRecording.fromJson(recording.toJson());
    expect(restored.workoutId, recording.workoutId);
    expect(restored.cue, 'workout_start');
    expect(restored.scope, 'description');
    expect(restored.audioPath, recording.audioPath);
    expect(restored.version, CoachRecording.currentVersion);
  });

  test('step recording key includes structural step key', () {
    final recording = CoachRecording(
      workoutId: 'workout-1',
      cue: 'step_voice',
      scope: 'step',
      stepKey: '2.0',
      language: 'vi-VN',
      audioPath: r'C:\recordings\step.m4a',
      createdAt: DateTime.utc(2026, 8, 26),
    );

    expect(recording.storageKey, 'workout-1::step::2.0');
  });

  test('expanded repeated steps keep the same structural recording key', () {
    final workout = WorkoutParser.parse('''
version: 1
name: Test
steps:
  - name: Warm up
  - repeat: 2
    steps:
      - name: Plank
''', id: 'workout-1', defaultVoiceLanguage: 'vi');

    expect(workout.expand().map((step) => step.stepKey), ['0', '1.0', '1.0']);
  });

  test('assigned step recording resolves by workout and structural key',
      () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    final recording = CoachRecording(
      workoutId: 'workout-1',
      cue: 'step_voice',
      scope: 'step',
      stepKey: '1.0',
      language: 'vi-VN',
      audioPath: r'C:\recordings\step.m4a',
      createdAt: DateTime.utc(2026, 8, 26),
    );

    await controller.assignCoachRecording(recording);

    expect(
      controller
          .coachRecordingFor(
            workoutId: 'workout-1',
            scope: 'step',
            stepKey: '1.0',
          )
          ?.audioPath,
      recording.audioPath,
    );
    expect(
      controller.coachRecordingFor(
        workoutId: 'workout-1',
        scope: 'description',
      ),
      isNull,
    );
  });
}
