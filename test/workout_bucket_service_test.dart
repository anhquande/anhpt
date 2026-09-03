import 'dart:convert';
import 'dart:typed_data';

import 'package:anhpt/models/workout.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/services/workout_bucket_service.dart';
import 'package:anhpt/services/workout_package_service.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('refresh parses a public HTTPS catalog', () async {
    final raw = jsonEncode({
      'schemaVersion': 2,
      'name': 'Official',
      'workouts': [
        {
          'id': 'flow',
          'name': 'Flow',
          'version': '1.0.0',
          'workoutUrl': 'https://example.com/flow.yaml',
          'workoutSha256': List.filled(64, 'a').join(),
          'workoutSize': 100,
          'assetsUrl': 'https://example.com/flow.assets.zip',
          'assetsSha256': List.filled(64, 'b').join(),
          'assetsSize': 200,
        },
      ],
    });
    final service = WorkoutBucketService(
      client: MockClient((_) async => http.Response(raw, 200)),
    );
    final result = await service.refresh(
      const WorkoutBucketSource(
        id: 'official',
        name: 'Official',
        catalogUrl: 'https://example.com/bucket.json',
      ),
    );

    expect(result.catalog.entries.single.id, 'flow');
    expect(result.fromCache, isFalse);
  });

  test('refresh falls back to last-good catalog when offline', () async {
    final cached = jsonEncode({
      'schemaVersion': 2,
      'name': 'Cached',
      'workouts': <Object>[],
    });
    final service = WorkoutBucketService(
      client: MockClient((_) async => throw StateError('offline')),
    );
    final result = await service.refresh(
      WorkoutBucketSource(
        id: 'official',
        name: 'Official',
        catalogUrl: 'https://example.com/bucket.json',
        cachedCatalogJson: cached,
      ),
    );

    expect(result.catalog.name, 'Cached');
    expect(result.fromCache, isTrue);
  });

  test('workout checksum is verified independently', () async {
    final bytes = utf8.encode('package');
    final service = WorkoutBucketService(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    final valid = WorkoutBucketEntry(
      id: 'flow',
      name: 'Flow',
      version: '1.0.0',
      workoutUrl: 'https://example.com/flow.yaml',
      workoutSha256: sha256.convert(bytes).toString(),
      workoutSize: bytes.length,
    );
    expect(await service.downloadWorkout(valid), bytes);

    final invalid = WorkoutBucketEntry(
      id: 'flow',
      name: 'Flow',
      version: '1.0.0',
      workoutUrl: valid.workoutUrl,
      workoutSha256: List.filled(64, '0').join(),
      workoutSize: bytes.length,
    );
    expect(() => service.downloadWorkout(invalid), throwsStateError);
  });

  test('workout definition and assets download independently', () async {
    final workoutBytes = utf8.encode('workout yaml');
    final assetsBytes = utf8.encode('assets zip');
    final service = WorkoutBucketService(
      client: MockClient(
        (request) async => request.url.path.endsWith('.yaml')
            ? http.Response.bytes(workoutBytes, 200)
            : http.Response.bytes(assetsBytes, 200),
      ),
    );
    final entry = WorkoutBucketEntry(
      id: 'flow',
      name: 'Flow',
      version: '1.0.0',
      workoutUrl: 'https://example.com/flow.workout.yaml',
      workoutSha256: sha256.convert(workoutBytes).toString(),
      workoutSize: workoutBytes.length,
      assetsUrl: 'https://example.com/flow.assets.zip',
      assetsSha256: sha256.convert(assetsBytes).toString(),
      assetsSize: assetsBytes.length,
    );

    expect(await service.downloadWorkout(entry), workoutBytes);
    expect(await service.downloadAssets(entry), assetsBytes);
  });

  test(
    'split YAML and assets import through the validated package path',
    () async {
      final assets = Archive()
        ..add(
          ArchiveFile.string(
            'manifest.json',
            jsonEncode({'schemaVersion': 1, 'workoutFile': 'workout.yaml'}),
          ),
        )
        ..add(ArchiveFile.string('coach_recordings/move.m4a', 'audio'));
      final workout =
          await WorkoutPackageService(
            supportsPackageFileExtraction: false,
          ).importSplitPackageBytes(
            Uint8List.fromList(
              utf8.encode('''
version: 2
name: Split workout
steps:
  - name: Move
    recording: coach_recordings/move.m4a
'''),
            ),
            Uint8List.fromList(ZipEncoder().encodeBytes(assets)),
            defaultVoiceLanguage: 'en',
          );

      expect(workout.name, 'Split workout');
      expect(workout.steps.single, isA<WorkoutStep>());
    },
  );

  test('package import rejects unsupported optional manifest', () async {
    final archive = Archive()
      ..add(
        ArchiveFile.string('workout.yaml', '''
version: 1
name: Test
steps:
  - name: Move
'''),
      )
      ..add(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({'schemaVersion': 99, 'workoutFile': 'workout.yaml'}),
        ),
      );
    final bytes = ZipEncoder().encodeBytes(archive);

    expect(
      () => WorkoutPackageService().importPackageBytes(
        bytes,
        defaultVoiceLanguage: 'en',
      ),
      throwsStateError,
    );
  });

  test('package import works without local file extraction', () async {
    final archive = Archive()
      ..add(
        ArchiveFile.string('workout.yaml', '''
version: 2
name: Browser workout
recording: coach_recordings/intro.m4a
background_music:
  source: music/calm.mp3
steps:
  - name: Move
    recording: coach_recordings/move.m4a
'''),
      )
      ..add(
        ArchiveFile.string(
          'manifest.json',
          jsonEncode({'schemaVersion': 1, 'workoutFile': 'workout.yaml'}),
        ),
      )
      ..add(ArchiveFile.string('coach_recordings/intro.m4a', 'intro'))
      ..add(ArchiveFile.string('coach_recordings/move.m4a', 'move'))
      ..add(ArchiveFile.string('music/calm.mp3', 'music'));
    final bytes = ZipEncoder().encodeBytes(archive);

    final workout = await WorkoutPackageService(
      supportsPackageFileExtraction: false,
    ).importPackageBytes(bytes, defaultVoiceLanguage: 'en');

    expect(workout.name, 'Browser workout');
    expect(workout.recording, 'coach_recordings/intro.m4a');
    expect(workout.backgroundMusic?.source, 'music/calm.mp3');
  });

  test('package import rejects duplicate normalized archive paths', () async {
    final archive = Archive()
      ..add(
        ArchiveFile.string('workout.yaml', '''
version: 1
name: Test
steps:
  - name: Move
'''),
      )
      ..add(ArchiveFile.string('Audio/guide.wav', 'one'))
      ..add(ArchiveFile.string('audio/GUIDE.wav', 'two'));
    final bytes = ZipEncoder().encodeBytes(archive);

    expect(
      () => WorkoutPackageService().importPackageBytes(
        bytes,
        defaultVoiceLanguage: 'en',
      ),
      throwsStateError,
    );
  });
}
