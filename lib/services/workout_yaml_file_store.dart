import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/workout.dart';

class WorkoutYamlFileStore {
  final Directory? rootDirectory;
  Directory? _directory;

  WorkoutYamlFileStore({this.rootDirectory});

  Future<Directory?> _workoutsDirectory() async {
    if (kIsWeb) return null;
    if (_directory != null) return _directory;
    final documents = rootDirectory ?? await getApplicationDocumentsDirectory();
    final directory = rootDirectory ??
        Directory(
          '${documents.path}${Platform.pathSeparator}AnhPT'
          '${Platform.pathSeparator}workouts',
        );
    await directory.create(recursive: true);
    _directory = directory;
    return directory;
  }

  Future<void> save(Workout workout) async {
    final directory = await _workoutsDirectory();
    if (directory == null) return;
    final target = File(
      '${directory.path}${Platform.pathSeparator}${_safeId(workout.id)}.yaml',
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(workout.rawYaml, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<void> replaceAll(List<Workout> workouts) async {
    final directory = await _workoutsDirectory();
    if (directory == null) return;
    final expected =
        workouts.map((workout) => '${_safeId(workout.id)}.yaml').toSet();
    await for (final entity in directory.list()) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.yaml') &&
          !expected.contains(entity.uri.pathSegments.last)) {
        await entity.delete();
      }
    }
    for (final workout in workouts) {
      await save(workout);
    }
  }

  Future<void> delete(String workoutId) async {
    final directory = await _workoutsDirectory();
    if (directory == null) return;
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_safeId(workoutId)}.yaml',
    );
    if (await file.exists()) await file.delete();
  }

  String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
}
