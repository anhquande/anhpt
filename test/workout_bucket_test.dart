import 'package:anhpt/models/workout_bucket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('bucket source round-trips persisted refresh state', () {
    final source = WorkoutBucketSource(
      id: 'community',
      name: 'Community workouts',
      catalogUrl:
          'https://raw.githubusercontent.com/example/bucket/main/bucket.json',
      enabled: false,
      lastRefreshedAt: DateTime.utc(2026, 8, 27),
      lastError: 'Offline',
      cachedCatalogJson: '{"schemaVersion":1}',
    );

    final restored = WorkoutBucketSource.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.catalogUri.scheme, 'https');
    expect(restored.enabled, isFalse);
    expect(restored.lastRefreshedAt, source.lastRefreshedAt);
    expect(restored.lastError, 'Offline');
    expect(restored.cachedCatalogJson, source.cachedCatalogJson);
  });

  test('catalog parses canonical schema and normalizes checksum', () {
    final catalog = WorkoutBucketCatalog.fromJson({
      'schemaVersion': 1,
      'name': 'AnhPT Community',
      'description': 'Public workouts',
      'workouts': [
        {
          'id': 'morning-flow',
          'name': 'Morning flow',
          'description': 'A short routine',
          'version': '1.2.0',
          'packageUrl': 'https://example.com/morning-flow.anhpt.zip',
          'sha256': hash.toUpperCase(),
          'tags': ['mobility', 'quick'],
          'author': 'AnhPT',
          'minAppVersion': '0.8.0',
          'size': 4096,
        },
      ],
    });

    expect(catalog.entries, hasLength(1));
    expect(catalog.entries.single.sha256, hash);
    expect(catalog.entries.single.tags, ['mobility', 'quick']);
    expect(catalog.entries.single.minAppVersion, '0.8.0');
    expect(catalog.entries.single.size, 4096);
    expect(catalog.entries.single.copyWithSource('community').sourceId,
        'community');
    expect(catalog.toJson()['workouts'], hasLength(1));
  });

  test('catalog accepts version, entries, package_url and checksum aliases',
      () {
    final catalog = WorkoutBucketCatalog.fromJson({
      'version': 1,
      'name': 'Bucket',
      'entries': [
        {
          'id': 'strength',
          'name': 'Strength',
          'version': '1',
          'package_url': 'https://cdn.example.com/strength.zip',
          'checksum': hash,
        },
      ],
    });

    expect(catalog.entries.single.description, isEmpty);
    expect(catalog.entries.single.packageUrl, contains('strength.zip'));
  });

  test('catalog rejects duplicates and malformed checksum', () {
    Map<String, dynamic> entry(String id, String checksum) => {
          'id': id,
          'name': 'Workout',
          'version': '1',
          'packageUrl': 'https://example.com/workout.zip',
          'sha256': checksum,
        };

    expect(
      () => WorkoutBucketCatalog.fromJson({
        'schemaVersion': 1,
        'name': 'Bucket',
        'workouts': [entry('same', hash), entry('same', hash)],
      }),
      throwsFormatException,
    );
    expect(
      () => WorkoutBucketEntry.fromJson(entry('workout', 'not-a-hash')),
      throwsFormatException,
    );
  });

  test('public HTTPS validation rejects unsafe source locations', () {
    for (final url in [
      'http://example.com/bucket.json',
      'https://localhost/bucket.json',
      'https://127.0.0.1/bucket.json',
      'https://192.168.1.20/bucket.json',
      'https://[::1]/bucket.json',
      'https://user:password@example.com/bucket.json',
    ]) {
      expect(() => requirePublicHttpsUri(url), throwsFormatException,
          reason: url);
    }
    expect(
      requirePublicHttpsUri('https://example.com/bucket.json').host,
      'example.com',
    );
    expect(
        requirePublicHttpsUri('https://fcc.gov/bucket.json').host, 'fcc.gov');
  });

  test('installed provenance round-trips', () {
    final provenance = InstalledWorkoutProvenance(
      workoutId: 'local-id',
      sourceId: 'community',
      entryId: 'morning-flow',
      version: '1.2.0',
      packageUrl: 'https://example.com/morning-flow.zip',
      sha256: hash,
      installedAt: DateTime.utc(2026, 8, 27, 12, 30),
    );

    final restored = InstalledWorkoutProvenance.fromJson(provenance.toJson());

    expect(restored.workoutId, provenance.workoutId);
    expect(restored.entryId, provenance.entryId);
    expect(restored.installedAt, provenance.installedAt);
    expect(restored.sha256, hash);
  });
}
