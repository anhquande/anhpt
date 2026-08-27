import 'package:anhpt/models/workout.dart';
import 'package:anhpt/models/workout_draft.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/services/workout_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Workout parse(String yaml) => WorkoutParser.parse(
        yaml,
        id: 'workout-1',
        defaultVoiceLanguage: 'vi',
      );

  test('schema v2 parses recordings, music and unique effective step ids', () {
    final workout = parse('''
version: 2
name: Audio workout
recording: recordings/intro.m4a
background_music:
  source: music/flow.mp3
  name: Flow
  volume: 0.4
steps:
  - name: Chuẩn bị tư thế
  - name: Plank
    recording: recordings/plank.m4a
  - name: Plank
''');

    expect(workout.recording, 'recordings/intro.m4a');
    expect(workout.backgroundMusic?.source, 'music/flow.mp3');
    expect(workout.backgroundMusic?.volume, .4);
    expect(workout.steps.whereType<WorkoutStep>().map((step) => step.id),
        ['chuan-bi-tu-the', 'plank', 'plank-2']);
    expect((workout.steps[1] as WorkoutStep).recording, 'recordings/plank.m4a');
  });

  test('explicit ids are globally unique across nested repeats', () {
    expect(
      () => parse('''
version: 2
name: Duplicate ids
steps:
  - id: plank
    name: Plank
  - repeat: 2
    steps:
      - id: plank
        name: Other plank
'''),
      throwsA(isA<WorkoutValidationException>()),
    );
  });

  test('unsafe recording paths are rejected', () {
    expect(
      () => parse('''
version: 2
name: Unsafe
recording: ../secret.m4a
steps:
  - name: Plank
'''),
      throwsA(isA<WorkoutValidationException>()),
    );
  });

  test('builder round trip preserves tags and audio configuration', () {
    final original = parse('''
version: 2
name: Round trip
tags: [core, beginner]
recording: recordings/intro.m4a
background_music:
  source: "asset:audio/bell.wav"
  enabled: false
  volume: 0.25
  ducking: medium
steps:
  - id: main-plank
    name: Plank
    duration: 20s
    recording: recordings/plank.m4a
''');

    final yaml = WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(original));
    final restored = parse(yaml);
    final step = restored.steps.single as WorkoutStep;
    expect(restored.version, 2);
    expect(restored.tags, ['core', 'beginner']);
    expect(restored.recording, 'recordings/intro.m4a');
    expect(restored.backgroundMusic?.enabled, isFalse);
    expect(restored.backgroundMusic?.ducking, 'medium');
    expect(step.id, 'main-plank');
    expect(step.recording, 'recordings/plank.m4a');
  });

  test('strong background music ducking modes parse and round trip', () {
    for (final mode in ['high', 'very_high']) {
      final original = parse('''
version: 2
name: Strong ducking
background_music:
  source: "asset:audio/bell.wav"
  ducking: $mode
steps:
  - name: Plank
''');
      final yaml = WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(original));
      expect(parse(yaml).backgroundMusic?.ducking, mode);
    }
  });

  test('duplicating a step gets a new implicit id and no recording', () {
    final source = StepDraft(
      id: 'plank',
      hasExplicitId: true,
      name: 'Plank',
      recording: 'recordings/plank.m4a',
    );
    final duplicate = source.clone();
    expect(duplicate.id, isEmpty);
    expect(duplicate.hasExplicitId, isFalse);
    expect(duplicate.recording, isEmpty);
  });

  test('schema v1 remains supported', () {
    final workout = parse('''
version: 1
name: Legacy
steps:
  - name: Rest
''');
    expect(workout.version, 1);
    expect((workout.steps.single as WorkoutStep).id, 'rest');
  });
}
