import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/workout.dart';
import '../models/workout_draft.dart';
import 'workout_parser.dart';
import 'workout_serializer.dart';

class WorkoutPackageService {
  static const _maxPackageBytes = 500 * 1024 * 1024;
  static const _maxFileBytes = 200 * 1024 * 1024;

  Future<bool> exportPackage(
    Workout workout, {
    required String Function(String source) resolveSource,
  }) async {
    final archive = Archive()
      ..add(ArchiveFile.string('workout.yaml', workout.rawYaml));
    final sources = _sources(workout)
        .where((source) => !source.startsWith('asset:'))
        .toSet();
    for (final source in sources) {
      final file = File(resolveSource(source));
      if (!await file.exists()) continue;
      final length = await file.length();
      if (length > _maxFileBytes) {
        throw StateError('Audio file is too large to export: $source');
      }
      archive.add(ArchiveFile.bytes(source, await file.readAsBytes()));
    }
    final bytes = ZipEncoder().encodeBytes(archive);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export portable workout',
      fileName: '${_safeName(workout.name)}.anhpt.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
    return path != null;
  }

  Future<Workout?> importPackage({required String defaultVoiceLanguage}) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import portable workout',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (picked == null) return null;
    final pickedFile = picked.files.single;
    final bytes = pickedFile.bytes ??
        (pickedFile.path == null
            ? null
            : await File(pickedFile.path!).readAsBytes());
    if (bytes == null) throw StateError('Could not read the selected package.');
    if (bytes.length > _maxPackageBytes) {
      throw StateError('Workout package is too large.');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final yamlEntry = archive.find('workout.yaml');
    if (yamlEntry == null) {
      throw StateError('Package does not contain workout.yaml.');
    }
    var totalExpandedBytes = 0;
    for (final entry in archive) {
      _validateArchiveName(entry.name);
      if (entry.size > _maxFileBytes) {
        throw StateError('Package entry is too large: ${entry.name}');
      }
      totalExpandedBytes += entry.size;
      if (totalExpandedBytes > _maxPackageBytes) {
        throw StateError('Expanded workout package is too large.');
      }
    }
    final yamlBytes = yamlEntry.readBytes();
    if (yamlBytes == null) {
      throw StateError('Could not read workout.yaml.');
    }

    final id = WorkoutParser.generateId();
    final parsed = WorkoutParser.parse(
      utf8.decode(yamlBytes),
      id: id,
      defaultVoiceLanguage: defaultVoiceLanguage,
    );
    final draft = WorkoutDraft.fromWorkout(parsed);
    final root = await getApplicationDocumentsDirectory();
    final target = Directory(
        '${root.path}${Platform.pathSeparator}imports${Platform.pathSeparator}$id');
    await target.create(recursive: true);
    final copiedSources = <String, String>{};
    final usedNames = <String>{};

    Future<String> copyReference(String source) async {
      if (source.startsWith('asset:')) return source;
      final copied = copiedSources[source];
      if (copied != null) return copied;
      final entry = archive.find(source);
      final content = entry?.readBytes();
      if (entry == null || content == null) return source;
      final originalName = source.replaceAll('\\', '/').split('/').last;
      final dot = originalName.lastIndexOf('.');
      final stem = dot <= 0 ? originalName : originalName.substring(0, dot);
      final extension = dot <= 0 ? '' : originalName.substring(dot);
      var fileName = originalName;
      var suffix = 2;
      while (!usedNames.add(fileName.toLowerCase())) {
        fileName = '$stem-${suffix++}$extension';
      }
      final destination =
          File('${target.path}${Platform.pathSeparator}$fileName');
      await destination.writeAsBytes(content, flush: true);
      final reference = 'imports/$id/$fileName';
      copiedSources[source] = reference;
      return reference;
    }

    draft.recording =
        draft.recording.isEmpty ? '' : await copyReference(draft.recording);
    if (draft.backgroundMusicSource.isNotEmpty) {
      draft.backgroundMusicSource =
          await copyReference(draft.backgroundMusicSource);
    }
    Future<void> copySteps(List<WorkoutDraftNode> nodes) async {
      for (final node in nodes) {
        if (node is StepDraft && node.recording.isNotEmpty) {
          node.recording = await copyReference(node.recording);
        } else if (node is RepeatDraft) {
          await copySteps(node.steps);
        }
      }
    }

    await copySteps(draft.steps);
    final yaml = WorkoutSerializer.toYaml(draft);
    return WorkoutParser.parse(
      yaml,
      id: id,
      defaultVoiceLanguage: defaultVoiceLanguage,
    );
  }

  Iterable<String> _sources(Workout workout) sync* {
    if (workout.recording != null) yield workout.recording!;
    if (workout.backgroundMusic != null) yield workout.backgroundMusic!.source;
    Iterable<String> stepSources(List<WorkoutNode> nodes) sync* {
      for (final node in nodes) {
        if (node is WorkoutStep && node.recording != null) {
          yield node.recording!;
        } else if (node is RepeatGroup) {
          yield* stepSources(node.steps);
        }
      }
    }

    yield* stepSources(workout.steps);
  }

  void _validateArchiveName(String name) {
    final normalized = name.replaceAll('\\', '/');
    if (normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:/').hasMatch(normalized) ||
        normalized.split('/').contains('..')) {
      throw StateError('Unsafe package entry: $name');
    }
  }

  String _safeName(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
    return safe.replaceAll(RegExp(r'^-+|-+$'), '').isEmpty ? 'workout' : safe;
  }
}
