import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  WorkoutBucketEntry entryRequiring(String version) => WorkoutBucketEntry(
    id: 'versioned-workout',
    name: 'Versioned workout',
    version: '1.0.0',
    workoutUrl: 'https://example.com/workout.yaml',
    workoutSha256: hash,
    workoutSize: 100,
    assetsUrl: 'https://example.com/assets.zip',
    assetsSha256: hash,
    assetsSize: 100,
    minAppVersion: version,
  );

  test('catalog compatibility uses the injected installed app version', () {
    final controller = AppController(LocalStore(), appVersion: '0.14.0');

    expect(
      controller.bucketEntryCompatibilityError(entryRequiring('0.14.0')),
      isNull,
    );
    expect(
      controller.bucketEntryCompatibilityError(entryRequiring('0.13.9')),
      isNull,
    );
    expect(
      controller.bucketEntryCompatibilityError(entryRequiring('0.14.1')),
      'Requires AnhPT 0.14.1 or newer.',
    );
  });

  test('unknown installed version fails safely', () {
    final controller = AppController(LocalStore());

    expect(
      controller.bucketEntryCompatibilityError(entryRequiring('0.14.0')),
      'Could not determine the installed AnhPT version.',
    );
  });
}
