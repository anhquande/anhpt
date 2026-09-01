import 'package:anhpt/core/session_engine.dart';
import 'package:anhpt/models/workout_draft.dart';
import 'package:anhpt/models/workout_video_settings.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/services/workout_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const yaml = '''
version: 2
name: Camera workout
video:
  auto_enable: true
  layout: camera_picture_in_picture
  camera: back
steps:
  - name: Squat
    duration: 30s
''';

  test('parser accepts workout video settings', () {
    final workout = WorkoutParser.parse(
      yaml,
      id: 'camera-workout',
      defaultVoiceLanguage: 'en',
    );

    final video = WorkoutVideoSettings.fromYaml(workout.rawYaml);
    expect(video, isNotNull);
    expect(video!.autoEnable, isTrue);
    expect(video.layout, 'camera_picture_in_picture');
    expect(video.camera, 'back');
  });

  test('invalid camera and layout values are rejected', () {
    expect(
      () => WorkoutParser.parse(
        yaml.replaceFirst('camera: back', 'camera: external'),
        id: 'bad-camera',
        defaultVoiceLanguage: 'en',
      ),
      throwsA(isA<WorkoutValidationException>()),
    );
    expect(
      () => WorkoutParser.parse(
        yaml.replaceFirst(
          'layout: camera_picture_in_picture',
          'layout: floating',
        ),
        id: 'bad-layout',
        defaultVoiceLanguage: 'en',
      ),
      throwsA(isA<WorkoutValidationException>()),
    );
  });

  test('draft and serializer preserve video settings', () {
    final workout = WorkoutParser.parse(
      yaml,
      id: 'round-trip',
      defaultVoiceLanguage: 'en',
    );
    final serialized = WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(workout));

    expect(serialized, contains('video:'));
    expect(serialized, contains('  auto_enable: true'));
    expect(serialized, contains('  layout: camera_picture_in_picture'));
    expect(serialized, contains('  camera: back'));
  });

  test('workouts without video settings remain backward compatible', () {
    final workout = WorkoutParser.parse(
      '''
version: 2
name: Legacy workout
steps:
  - name: Plank
    duration: 20s
''',
      id: 'legacy',
      defaultVoiceLanguage: 'en',
    );

    final draft = WorkoutDraft.fromWorkout(workout);
    expect(draft.videoSettingsEnabled, isFalse);
    expect(WorkoutSerializer.toYaml(draft), isNot(contains('video:')));
  });

  test('session activates workout-specific video settings', () {
    final workout = WorkoutParser.parse(
      yaml,
      id: 'runtime',
      defaultVoiceLanguage: 'en',
    );
    final engine = SessionEngine(workout);
    addTearDown(engine.dispose);

    expect(WorkoutVideoRuntime.current?.autoEnable, isTrue);
    expect(WorkoutVideoRuntime.current?.layout, 'camera_picture_in_picture');
    expect(WorkoutVideoRuntime.current?.camera, 'back');
  });
}
