import 'dart:convert';

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
      'schemaVersion': 1,
      'name': 'Official',
      'workouts': [
        {
          'id': 'flow',
          'name': 'Flow',
          'version': '1.0.0',
          'packageUrl': 'https://example.com/flow.anhpt.zip',
          'sha256': List.filled(64, 'a').join(),
        }
      ],
    });
    final service = WorkoutBucketService(
      client: MockClient((_) async => http.Response(raw, 200)),
    );
    final result = await service.refresh(const WorkoutBucketSource(
      id: 'official',
      name: 'Official',
      catalogUrl: 'https://example.com/bucket.json',
    ));

    expect(result.catalog.entries.single.id, 'flow');
    expect(result.fromCache, isFalse);
  });

  test('refresh falls back to last-good catalog when offline', () async {
    final cached = jsonEncode({
      'schemaVersion': 1,
      'name': 'Cached',
      'workouts': <Object>[],
    });
    final service = WorkoutBucketService(
      client: MockClient((_) async => throw StateError('offline')),
    );
    final result = await service.refresh(WorkoutBucketSource(
      id: 'official',
      name: 'Official',
      catalogUrl: 'https://example.com/bucket.json',
      cachedCatalogJson: cached,
    ));

    expect(result.catalog.name, 'Cached');
    expect(result.fromCache, isTrue);
  });

  test('package checksum is verified before import', () async {
    final bytes = utf8.encode('package');
    final service = WorkoutBucketService(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    final valid = WorkoutBucketEntry(
      id: 'flow',
      name: 'Flow',
      version: '1.0.0',
      packageUrl: 'https://example.com/flow.anhpt.zip',
      sha256: sha256.convert(bytes).toString(),
      size: bytes.length,
    );
    expect(await service.downloadPackage(valid), bytes);

    final invalid = WorkoutBucketEntry(
      id: 'flow',
      name: 'Flow',
      version: '1.0.0',
      packageUrl: valid.packageUrl,
      sha256: List.filled(64, '0').join(),
    );
    expect(() => service.downloadPackage(invalid), throwsStateError);
  });

  test('package import rejects unsupported optional manifest', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('workout.yaml', '''
version: 1
name: Test
steps:
  - name: Move
'''))
      ..add(ArchiveFile.string(
        'manifest.json',
        jsonEncode({'schemaVersion': 99, 'workoutFile': 'workout.yaml'}),
      ));
    final bytes = ZipEncoder().encodeBytes(archive);

    expect(
      () => WorkoutPackageService().importPackageBytes(
        bytes,
        defaultVoiceLanguage: 'en',
      ),
      throwsStateError,
    );
  });

  test('package import rejects duplicate normalized archive paths', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('workout.yaml', '''
version: 1
name: Test
steps:
  - name: Move
'''))
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
