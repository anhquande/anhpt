import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/workout.dart';
import '../models/workout_draft.dart';
import 'workout_parser.dart';
import 'workout_serializer.dart';
import 'media_repository.dart';

class WorkoutPackageService {
  static const _maxPackageBytes = 500 * 1024 * 1024;
  static const _maxFileBytes = 200 * 1024 * 1024;

  Future<bool> exportPackage(
    Workout workout, {
    required String Function(String source) resolveSource,
    required MediaRepository mediaRepository,
  }) async {
    final archive = Archive()
      ..add(ArchiveFile.string('workout.yaml', workout.rawYaml));
    final mediaManifest = <Map<String, dynamic>>[];
    for (final mediaReference in workout.exercises
        .map((exercise) => exercise.demoMediaId)
        .whereType<String>()
        .toSet()) {
      final asset = await mediaRepository.get(mediaReference);
      final uri = await mediaRepository.resolveUri(mediaReference);
      if (asset == null || uri == null) continue;
      final file = File.fromUri(uri);
      final extension = asset.relativePath.contains('.')
          ? asset.relativePath.substring(asset.relativePath.lastIndexOf('.'))
          : '';
      final path = 'assets/${asset.id.substring(7)}$extension';
      archive.add(ArchiveFile.bytes(path, await file.readAsBytes()));
      mediaManifest.add({
        'id': asset.id,
        'reference': mediaReference,
        'type': asset.type,
        'path': path,
      });
    }
    archive.add(ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'schemaVersion': 1,
          'workoutFile': 'workout.yaml',
          if (mediaManifest.isNotEmpty) 'assets': mediaManifest,
        })));
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

  Future<Workout?> importPackage({
    required String defaultVoiceLanguage,
    required MediaRepository mediaRepository,
  }) async {
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
    return importPackageBytes(
      Uint8List.fromList(bytes),
      defaultVoiceLanguage: defaultVoiceLanguage,
      mediaRepository: mediaRepository,
    );
  }

  /// Imports downloaded bytes through the same validation path as the picker.
  Future<Workout> importPackageBytes(
    Uint8List bytes, {
    required String defaultVoiceLanguage,
    MediaRepository? mediaRepository,
  }) async {
    if (bytes.length > _maxPackageBytes) {
      throw StateError('Workout package is too large.');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final yamlEntry = archive.find('workout.yaml');
    if (yamlEntry == null) {
      throw StateError('Package does not contain workout.yaml.');
    }
    final manifestEntry = archive.find('manifest.json');
    Map<String, dynamic>? packageManifest;
    if (manifestEntry != null) {
      final manifestBytes = manifestEntry.readBytes();
      if (manifestBytes == null) {
        throw StateError('Could not read package manifest.');
      }
      final manifest = jsonDecode(utf8.decode(manifestBytes));
      if (manifest is! Map ||
          manifest['schemaVersion'] != 1 ||
          (manifest['workoutFile'] ?? 'workout.yaml') != 'workout.yaml') {
        throw StateError('Unsupported workout package manifest.');
      }
      packageManifest = Map<String, dynamic>.from(manifest);
    }
    var totalExpandedBytes = 0;
    if (archive.length > 256) {
      throw StateError('Workout package contains too many entries.');
    }
    final normalizedNames = <String>{};
    for (final entry in archive) {
      _validateArchiveName(entry.name);
      final normalized = entry.name.replaceAll('\\', '/').toLowerCase();
      if (normalized.length > 240 || !normalizedNames.add(normalized)) {
        throw StateError('Unsafe or duplicate package entry: ${entry.name}');
      }
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
    if (mediaRepository != null && packageManifest?['assets'] is List) {
      final requiredReferences = parsed.exercises
          .map((exercise) => exercise.demoMediaId)
          .whereType<String>()
          .toSet();
      final importedReferences = <String, String>{};
      for (final rawAsset in packageManifest!['assets'] as List) {
        final asset = Map<String, dynamic>.from(rawAsset as Map);
        final id = asset['id'];
        final reference = asset['reference'] ?? id;
        final path = asset['path'];
        if (id is! String ||
            reference is! String ||
            path is! String ||
            !requiredReferences.contains(reference)) {
          continue;
        }
        _validateArchiveName(path);
        final content = archive.find(path)?.readBytes();
        if (content == null) {
          throw StateError('Package media is missing: $path');
        }
        final imported = await mediaRepository.importBytes(content,
            fileName: path.split('/').last,
            type: asset['type'] as String? ?? 'video');
        if (imported.id != id.toLowerCase()) {
          throw StateError('Package media hash does not match: $path');
        }
        importedReferences[reference] = imported.relativePath;
      }
      if (importedReferences.isNotEmpty) {
        final draft = WorkoutDraft.fromWorkout(parsed);
        for (var index = 0; index < draft.exercises.length; index++) {
          final exercise = draft.exercises[index];
          final replacement = importedReferences[exercise.demoMediaId];
          if (replacement == null) continue;
          draft.exercises[index] = Exercise(
            id: exercise.id,
            name: exercise.name,
            demoMediaId: replacement,
          );
        }
        final normalizedYaml = WorkoutSerializer.toYaml(draft);
        return _importAudioReferences(
          WorkoutParser.parse(
            normalizedYaml,
            id: id,
            defaultVoiceLanguage: defaultVoiceLanguage,
          ),
          archive,
          id,
          defaultVoiceLanguage,
        );
      }
    }
    return _importAudioReferences(parsed, archive, id, defaultVoiceLanguage);
  }

  Future<Workout> _importAudioReferences(
    Workout parsed,
    Archive archive,
    String id,
    String defaultVoiceLanguage,
  ) async {
    final draft = WorkoutDraft.fromWorkout(parsed);
    final root = await getApplicationDocumentsDirectory();
    final imports = Directory('${root.path}${Platform.pathSeparator}imports');
    await imports.create(recursive: true);
    final target = Directory('${imports.path}${Platform.pathSeparator}$id');
    final staging =
        Directory('${imports.path}${Platform.pathSeparator}.tmp-$id');
    await staging.create(recursive: true);
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
          File('${staging.path}${Platform.pathSeparator}$fileName');
      await destination.writeAsBytes(content, flush: true);
      final reference = 'imports/$id/$fileName';
      copiedSources[source] = reference;
      return reference;
    }

    try {
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
      final result = WorkoutParser.parse(
        yaml,
        id: id,
        defaultVoiceLanguage: defaultVoiceLanguage,
      );
      await staging.rename(target.path);
      return result;
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
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
