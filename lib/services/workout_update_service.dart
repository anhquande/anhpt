import '../app/app_controller.dart';
import '../models/workout_bucket.dart';

class WorkoutUpdateInfo {
  final InstalledWorkoutProvenance installed;
  final WorkoutBucketEntry available;

  const WorkoutUpdateInfo({
    required this.installed,
    required this.available,
  });

  String get installedVersion => installed.version;
  String get availableVersion => available.version;
}

extension WorkoutUpdateController on AppController {
  WorkoutUpdateInfo? updateForWorkout(String workoutId) {
    final installed = bucketProvenanceFor(workoutId);
    if (installed == null) return null;

    WorkoutBucketEntry? available;
    for (final entry in bucketCatalogEntries) {
      if (entry.sourceId == installed.sourceId &&
          entry.id == installed.entryId &&
          compareWorkoutVersions(entry.version, installed.version) > 0) {
        if (available == null ||
            compareWorkoutVersions(entry.version, available.version) > 0) {
          available = entry;
        }
      }
    }

    if (available == null) return null;
    return WorkoutUpdateInfo(installed: installed, available: available);
  }
}

int compareWorkoutVersions(String left, String right) {
  final leftVersion = _ParsedVersion.parse(left);
  final rightVersion = _ParsedVersion.parse(right);

  final coreLength = leftVersion.core.length > rightVersion.core.length
      ? leftVersion.core.length
      : rightVersion.core.length;
  for (var index = 0; index < coreLength; index++) {
    final leftPart =
        index < leftVersion.core.length ? leftVersion.core[index] : 0;
    final rightPart =
        index < rightVersion.core.length ? rightVersion.core[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }

  if (leftVersion.preRelease == null && rightVersion.preRelease == null) {
    return 0;
  }
  if (leftVersion.preRelease == null) return 1;
  if (rightVersion.preRelease == null) return -1;

  final leftPre = leftVersion.preRelease!;
  final rightPre = rightVersion.preRelease!;
  final preLength = leftPre.length > rightPre.length
      ? leftPre.length
      : rightPre.length;
  for (var index = 0; index < preLength; index++) {
    if (index >= leftPre.length) return -1;
    if (index >= rightPre.length) return 1;
    final leftId = leftPre[index];
    final rightId = rightPre[index];
    final leftNumber = int.tryParse(leftId);
    final rightNumber = int.tryParse(rightId);
    if (leftNumber != null && rightNumber != null) {
      if (leftNumber != rightNumber) return leftNumber.compareTo(rightNumber);
      continue;
    }
    if (leftNumber != null) return -1;
    if (rightNumber != null) return 1;
    final comparison = leftId.compareTo(rightId);
    if (comparison != 0) return comparison;
  }
  return 0;
}

class _ParsedVersion {
  final List<int> core;
  final List<String>? preRelease;

  const _ParsedVersion(this.core, this.preRelease);

  factory _ParsedVersion.parse(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final withoutBuild = normalized.split('+').first;
    final dash = withoutBuild.indexOf('-');
    final coreText = dash < 0 ? withoutBuild : withoutBuild.substring(0, dash);
    final preText = dash < 0 ? null : withoutBuild.substring(dash + 1);
    final core = coreText
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
    final preRelease = preText == null || preText.isEmpty
        ? null
        : preText.split('.').toList(growable: false);
    return _ParsedVersion(core, preRelease);
  }
}
