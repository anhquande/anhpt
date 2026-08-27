import 'package:anhpt/models/coach_recording.dart';
import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/screens/workout_detail_screen.dart';
import 'package:anhpt/widgets/coach_recording_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      audioPath: 'coach_recordings/step.m4a',
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
    controller.workouts = [
      WorkoutParser.parse('''
version: 1
name: Test
steps:
  - name: Warm up
  - name: Plank
''', id: 'workout-1', defaultVoiceLanguage: 'vi')
    ];
    final recording = CoachRecording(
      workoutId: 'workout-1',
      cue: 'step_voice',
      scope: 'step',
      stepKey: '1',
      language: 'vi-VN',
      audioPath: 'coach_recordings/step.m4a',
      createdAt: DateTime.utc(2026, 8, 26),
    );

    await controller.assignCoachRecording(recording);

    expect(
      controller
          .coachRecordingFor(
            workoutId: 'workout-1',
            scope: 'step',
            stepKey: '1',
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

  testWidgets('step recording opens a centered dialog with the step guide',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(LocalStore());
    controller.workouts = [
      WorkoutParser.parse('''
version: 2
name: Guided workout
steps:
  - name: Plank
    guide: Keep your back straight and breathe evenly.
''', id: 'workout-1', defaultVoiceLanguage: 'en')
    ];

    await tester.pumpWidget(MaterialApp(
      home: WorkoutDetailScreen(
        controller: controller,
        workoutId: 'workout-1',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Record step cue'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Record step cue'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Step recording: Plank'), findsOneWidget);
    expect(find.text('Guide to read'), findsOneWidget);
    expect(find.text('Keep your back straight and breathe evenly.'),
        findsOneWidget);
    expect(find.text('Open microphone settings'), findsNothing);
    expect(find.textContaining('Windows does not show'), findsNothing);
    expect(find.text('Ready to record.'), findsNothing);
  });

  for (final scope in ['description', 'step']) {
    testWidgets('$scope recording shows an inline player when assigned',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(LocalStore());
      final workout = WorkoutParser.parse('''
version: 2
name: Recorded workout
recording: coach_recordings/intro.m4a
steps:
  - id: plank
    name: Plank
    recording: coach_recordings/plank.m4a
''', id: 'workout-1', defaultVoiceLanguage: 'en');
      controller.workouts = [workout];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoachRecordingCard(
            controller: controller,
            workout: workout,
            scope: scope,
            stepKey: scope == 'step' ? '0' : null,
            title:
                scope == 'step' ? 'Step recording' : 'Introduction recording',
            cueDescription: 'Record this cue.',
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Assigned recording'), findsOneWidget);
      expect(find.byTooltip('Play preview'), findsOneWidget);
      expect(find.byTooltip('Stop preview'), findsOneWidget);
      expect(find.text('Delete recording'), findsOneWidget);
      final recordCenter = tester.getCenter(find.text('Record replacement'));
      final deleteCenter = tester.getCenter(find.text('Delete recording'));
      expect(recordCenter.dx, lessThan(deleteCenter.dx));
      expect((recordCenter.dy - deleteCenter.dy).abs(), lessThan(2));
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
