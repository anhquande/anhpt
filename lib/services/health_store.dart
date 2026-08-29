import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health.dart';

class HealthStore {
  static const _profileKey = 'anhpt.health.profile.v1';
  static const _measurementsKey = 'anhpt.health.measurements.v1';

  Future<HealthProfile> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profileKey);
    if (raw == null) return const HealthProfile();
    return HealthProfile.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> saveProfile(HealthProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<List<WeightMeasurement>> loadMeasurements() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_measurementsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    final values = <WeightMeasurement>[];
    for (final item in decoded) {
      try {
        final measurement = WeightMeasurement.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        if (measurement.weightKg > 0 && measurement.weightKg < 500) {
          values.add(measurement);
        }
      } catch (_) {
        // Keep the store tolerant to one malformed legacy/imported record.
      }
    }
    values.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return values;
  }

  Future<void> saveMeasurements(List<WeightMeasurement> measurements) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _measurementsKey,
      jsonEncode(measurements.map((value) => value.toJson()).toList()),
    );
  }

  Future<void> clearMeasurements() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_measurementsKey);
  }
}
