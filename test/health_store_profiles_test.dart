import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anhpt/models/health.dart';
import 'package:anhpt/services/health_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates legacy single-profile Health data into Me', () async {
    final measuredAt = DateTime(2026, 8, 28, 7, 30);
    SharedPreferences.setMockInitialValues({
      'anhpt.health.profile.v1': jsonEncode(const HealthProfile(
        sex: HealthSex.male,
        birthYear: 1980,
        heightCm: 175,
      ).toJson()),
      'anhpt.health.measurements.v1': jsonEncode([
        WeightMeasurement(
          id: 'legacy-1',
          weightKg: 72.4,
          measuredAt: measuredAt,
        ).toJson(),
      ]),
    });

    final store = HealthStore();
    final profiles = await store.loadLocalProfiles();
    final active = await store.activeLocalProfile();
    final profile = await store.loadProfile();
    final measurements = await store.loadMeasurements();

    expect(profiles, hasLength(1));
    expect(active.name, 'Me');
    expect(profile.birthYear, 1980);
    expect(profile.heightCm, 175);
    expect(measurements.single.weightKg, 72.4);
  });

  test('keeps measurements isolated between local profiles', () async {
    SharedPreferences.setMockInitialValues({});
    final store = HealthStore();
    final me = await store.activeLocalProfile();
    final other = await store.createLocalProfile('Alex');

    await store.saveMeasurements([
      WeightMeasurement(
        id: 'me-1',
        weightKg: 70,
        measuredAt: DateTime(2026, 8, 29, 8),
      ),
    ], me.id);
    await store.saveMeasurements([
      WeightMeasurement(
        id: 'alex-1',
        weightKg: 80,
        measuredAt: DateTime(2026, 8, 29, 9),
      ),
    ], other.id);

    expect((await store.loadMeasurements(me.id)).single.weightKg, 70);
    expect((await store.loadMeasurements(other.id)).single.weightKg, 80);
  });

  test('deleting a profile never deletes another profile data', () async {
    SharedPreferences.setMockInitialValues({});
    final store = HealthStore();
    final me = await store.activeLocalProfile();
    final other = await store.createLocalProfile('Guest');
    await store.saveMeasurements([
      WeightMeasurement(
        id: 'me-1',
        weightKg: 70,
        measuredAt: DateTime(2026, 8, 29),
      ),
    ], me.id);

    await store.deleteLocalProfile(other.id);

    expect(await store.loadMeasurements(me.id), hasLength(1));
    expect((await store.loadLocalProfiles()).single.id, me.id);
  });
}
