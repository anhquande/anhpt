import 'dart:io';

import 'package:anhpt/models/workout.dart';
import 'package:anhpt/models/workout_draft.dart';
import 'package:anhpt/services/media_repository.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/services/workout_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exercise demo and optional step reference round trip', () {
    final hash = List.filled(64, 'a').join();
    final yaml = '''
version: 2
name: Video workout
exercises:
  - id: exercise_plank
    name: Plank
    demo_video: sha256:$hash
steps:
  - name: Prepare
  - name: Plank
    duration: 30s
    exercise_id: exercise_plank
''';
    final workout =
        WorkoutParser.parse(yaml, id: 'workout', defaultVoiceLanguage: 'en');
    expect(workout.exercises.single.demoMediaId, 'sha256:$hash');
    expect((workout.steps.first as WorkoutStep).exerciseId, isNull);
    expect((workout.steps.last as WorkoutStep).exerciseId, 'exercise_plank');

    final restored = WorkoutParser.parse(
        WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(workout)),
        id: 'restored',
        defaultVoiceLanguage: 'en');
    expect(restored.exercises.single.demoMediaId, 'sha256:$hash');
    expect(restored.rawYaml, contains('demo_media:'));
    expect((restored.steps.last as WorkoutStep).exerciseId, 'exercise_plank');
  });

  test('legacy demo_video is accepted and serialized as demo_media', () {
    final hash = List.filled(64, 'b').join();
    final workout = WorkoutParser.parse('''
version: 2
name: Legacy video
exercises:
  - id: squat
    name: Squat
    demo_video: sha256:$hash
steps:
  - name: Squat
    exercise_id: squat
''', id: 'legacy', defaultVoiceLanguage: 'en');
    expect(workout.exercises.single.demoMediaId, 'sha256:$hash');
    expect(WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(workout)),
        contains('demo_media:'));
  });

  test('readable relative demonstration path round trips', () {
    final workout = WorkoutParser.parse('''
version: 2
name: Readable media
exercises:
  - id: squat
    name: Squat
    demo_media: media/squat-demo.gif
steps:
  - name: Squat
    exercise_id: squat
''', id: 'readable', defaultVoiceLanguage: 'en');
    expect(workout.exercises.single.demoMediaId, 'media/squat-demo.gif');
    expect(WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(workout)),
        contains('demo_media: media/squat-demo.gif'));
  });

  test('unknown exercise reference is rejected', () {
    expect(
      () => WorkoutParser.parse('''
version: 2
name: Invalid
steps:
  - name: Plank
    exercise_id: missing
''', id: 'invalid', defaultVoiceLanguage: 'en'),
      throwsA(isA<WorkoutValidationException>()),
    );
  });

  test('local media repository deduplicates identical bytes', () async {
    final directory = await Directory.systemTemp.createTemp('anhpt-media-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = LocalMediaRepository(rootDirectory: directory);
    final first =
        await repository.importBytes([1, 2, 3, 4], fileName: 'plank.mp4');
    final second =
        await repository.importBytes([1, 2, 3, 4], fileName: 'copy.mp4');
    expect(second.id, first.id);
    expect(first.relativePath, startsWith('media/plank-'));
    expect(first.relativePath, endsWith('.mp4'));
    expect(await repository.get(first.relativePath), first);
    expect(await repository.exists(first.id), isTrue);
    expect(directory.listSync(recursive: true).whereType<File>().length, 2);
  });

  test('media repository records image and animation metadata', () async {
    final directory = await Directory.systemTemp.createTemp('anhpt-image-');
    addTearDown(() => directory.delete(recursive: true));
    final repository = LocalMediaRepository(rootDirectory: directory);
    final image = await repository
        .importBytes([1, 2, 3], fileName: 'pose.png', type: 'image');
    final animation = await repository
        .importBytes([4, 5, 6], fileName: 'move.gif', type: 'animation');
    expect(image.mimeType, 'image/png');
    expect(animation.mimeType, 'image/gif');
  });
}
