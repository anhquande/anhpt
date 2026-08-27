import 'dart:io';

import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/services/workout_yaml_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes recording and demonstration references to a YAML file',
      () async {
    final directory = await Directory.systemTemp.createTemp('anhpt-yaml-');
    addTearDown(() => directory.delete(recursive: true));
    final hash = List.filled(64, 'a').join();
    final workout = WorkoutParser.parse('''
version: 2
name: Persisted media
exercises:
  - id: plank
    name: Plank
    demo_media: media/plank-${hash.substring(0, 8)}.gif
steps:
  - id: plank-step
    name: Plank
    recording: coach_recordings/plank.m4a
    exercise_id: plank
''', id: 'workout-1', defaultVoiceLanguage: 'en');
    final store = WorkoutYamlFileStore(rootDirectory: directory);

    await store.save(workout);

    final yaml = await File(
      '${directory.path}${Platform.pathSeparator}workout-1.yaml',
    ).readAsString();
    expect(yaml, contains('recording: coach_recordings/plank.m4a'));
    expect(yaml, contains('exercise_id: plank'));
    expect(
        yaml, contains('demo_media: media/plank-${hash.substring(0, 8)}.gif'));
  });
}
