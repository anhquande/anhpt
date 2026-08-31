import 'package:anhpt/app/app_controller.dart';
import 'package:anhpt/models/workout_bucket.dart';
import 'package:anhpt/services/local_store.dart';
import 'package:anhpt/services/workout_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout versions compare semantically', () {
    expect(compareWorkoutVersions('1.10.0', '1.9.0'), greaterThan(0));
    expect(compareWorkoutVersions('v2.0', '1.99.99'), greaterThan(0));
    expect(compareWorkoutVersions('1.0.0', '1.0.0-beta.2'), greaterThan(0));
    expect(compareWorkoutVersions('1.0.0-beta.10', '1.0.0-beta.2'), greaterThan(0));
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
          packageUrl: 'https://example.com/v2.zip',
          sha256: 'b' * 64,
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
        packageUrl: 'https://example.com/old.zip',
        sha256: 'c' * 64,
      ),
    ];
    expect(controller.updateForWorkout('local-workout'), isNull);
  });
}
