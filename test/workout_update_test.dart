import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orphaned bucket provenance does not hide a missing workout', () {
    final controller = AppController(LocalStore())
      ..installedBucketWorkouts = [
        InstalledWorkoutProvenance(
          workoutId: 'missing-local-workout',
          sourceId: 'official',
          entryId: 'flow',
          version: '1.0.0',
          packageUrl: 'https://example.com/flow.zip',
          sha256: 'a' * 64,
          installedAt: DateTime.utc(2026),
        ),
      ];
    const entry = WorkoutBucketEntry(
      sourceId: 'official',
      id: 'flow',
      name: 'Flow',
      version: '1.0.0',
      workoutUrl: 'https://example.com/flow.yaml',
      workoutSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      workoutSize: 512,
    );

    expect(controller.bucketInstallState(entry), 'notInstalled');
  });


  test('bucket compatibility accepts the exact minimum app version', () {
    final controller = AppController(LocalStore(), appVersion: '0.14.0');
    const compatible = WorkoutBucketEntry(
      id: 'feature-demo',
      name: 'Feature Demo',
      version: '1.0.0',
      workoutUrl: 'https://example.com/workout.yaml',
      workoutSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      workoutSize: 512,
      minAppVersion: '0.14.0',
    );
    const tooNew = WorkoutBucketEntry(
      id: 'future-demo',
      name: 'Future Demo',
      version: '1.0.0',
      workoutUrl: 'https://example.com/future.yaml',
      workoutSha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      workoutSize: 512,
      minAppVersion: '0.15.0',
    );

    expect(controller.bucketEntryCompatibilityError(compatible), isNull);
    expect(
      controller.bucketEntryCompatibilityError(tooNew),
      'Requires AnhPT 0.15.0 or newer.',
    );
  });

  test('workout versions compare semantically', () {
    expect(compareWorkoutVersions('1.10.0', '1.9.0'), greaterThan(0));
    expect(compareWorkoutVersions('v2.0', '1.99.99'), greaterThan(0));
    expect(compareWorkoutVersions('1.0.0', '1.0.0-beta.2'), greaterThan(0));
    expect(
      compareWorkoutVersions('1.0.0-beta.10', '1.0.0-beta.2'),
      greaterThan(0),
    );
    expect(compareWorkoutVersions('1.0.0+5', '1.0.0+4'), 0);
  });

  test('updateForWorkout only returns a newer bucket version', () {
    final controller = AppController(LocalStore())
      ..installedBucketWorkouts = [
        InstalledWorkoutProvenance(
          workoutId: 'local-workout',
          sourceId: 'official',
          sourceName: 'AnhPT Official',
          entryId: 'karate-1',
          originalName: 'Karate Workout',
          version: '1.9.0',
          packageUrl: 'https://example.com/v1.zip',
          sha256: 'a' * 64,
          installedAt: DateTime.utc(2026, 8, 1),
        ),
      ]
      ..bucketCatalogEntries = [
        WorkoutBucketEntry(
          sourceId: 'official',
          id: 'karate-1',
          name: 'Karate Workout',
          version: '1.10.0',
          workoutUrl: 'https://example.com/v2.yaml',
          workoutSha256: 'b' * 64,
          workoutSize: 512,
        ),
      ];

    final update = controller.updateForWorkout('local-workout');
    expect(update, isNotNull);
    expect(update!.installedVersion, '1.9.0');
    expect(update.availableVersion, '1.10.0');

    controller.bucketCatalogEntries = [
      WorkoutBucketEntry(
        sourceId: 'official',
        id: 'karate-1',
        name: 'Karate Workout',
        version: '1.8.0',
        workoutUrl: 'https://example.com/old.yaml',
        workoutSha256: 'c' * 64,
        workoutSize: 512,
      ),
    ];
    expect(controller.updateForWorkout('local-workout'), isNull);
  });
}
