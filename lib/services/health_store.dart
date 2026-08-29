import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health.dart';
import '../models/local_profile.dart';

class HealthStore {
  static const _legacyProfileKey = 'anhpt.health.profile.v1';
  static const _legacyMeasurementsKey = 'anhpt.health.measurements.v1';
  static const _profilesKey = 'anhpt.health.localProfiles.v1';
  static const _activeProfileKey = 'anhpt.health.activeProfile.v1';
  static const _migrationKey = 'anhpt.health.multiProfileMigrated.v1';

  String _profileKey(String profileId) => 'anhpt.health.profile.v2.$profileId';
  String _measurementsKey(String profileId) =>
      'anhpt.health.measurements.v2.$profileId';

  Future<void> ensureMigrated() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_migrationKey) == true) return;

    final existingProfiles = _decodeProfiles(preferences.getString(_profilesKey));
    if (existingProfiles.isNotEmpty) {
      await preferences.setBool(_migrationKey, true);
      if (preferences.getString(_activeProfileKey) == null) {
        await preferences.setString(_activeProfileKey, existingProfiles.first.id);
      }
      return;
    }

    final me = LocalProfile(
      id: 'me',
      name: 'Me',
      createdAt: DateTime.now(),
    );
    await preferences.setString(_profilesKey, jsonEncode([me.toJson()]));
    await preferences.setString(_activeProfileKey, me.id);

    final legacyProfile = preferences.getString(_legacyProfileKey);
    if (legacyProfile != null) {
      await preferences.setString(_profileKey(me.id), legacyProfile);
    }
    final legacyMeasurements = preferences.getString(_legacyMeasurementsKey);
    if (legacyMeasurements != null) {
      await preferences.setString(_measurementsKey(me.id), legacyMeasurements);
    }

    await preferences.setBool(_migrationKey, true);
  }

  Future<List<LocalProfile>> loadLocalProfiles() async {
    await ensureMigrated();
    final preferences = await SharedPreferences.getInstance();
    final profiles = _decodeProfiles(preferences.getString(_profilesKey));
    profiles.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return profiles;
  }

  Future<LocalProfile> activeLocalProfile() async {
    final profiles = await loadLocalProfiles();
    final preferences = await SharedPreferences.getInstance();
    final activeId = preferences.getString(_activeProfileKey);
    return profiles.firstWhere(
      (profile) => profile.id == activeId,
      orElse: () => profiles.first,
    );
  }

  Future<void> setActiveProfile(String profileId) async {
    final profiles = await loadLocalProfiles();
    if (!profiles.any((profile) => profile.id == profileId)) {
      throw StateError('Unknown local profile: $profileId');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeProfileKey, profileId);
  }

  Future<LocalProfile> createLocalProfile(
    String name, {
    String? avatarBase64,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Profile name cannot be empty.');
    final profiles = await loadLocalProfiles();
    final profile = LocalProfile(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      avatarBase64: avatarBase64,
      createdAt: DateTime.now(),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profilesKey,
      jsonEncode([...profiles, profile].map((value) => value.toJson()).toList()),
    );
    return profile;
  }

  Future<void> updateLocalProfile(
    String profileId, {
    required String name,
    String? avatarBase64,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Profile name cannot be empty.');
    final profiles = await loadLocalProfiles();
    final updated = [
      for (final profile in profiles)
        profile.id == profileId
            ? profile.copyWith(
                name: trimmed,
                avatarBase64: avatarBase64,
                clearAvatar: avatarBase64 == null,
              )
            : profile,
    ];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profilesKey,
      jsonEncode(updated.map((value) => value.toJson()).toList()),
    );
  }

  Future<void> renameLocalProfile(String profileId, String name) async {
    final profiles = await loadLocalProfiles();
    final current = profiles.firstWhere((profile) => profile.id == profileId);
    await updateLocalProfile(
      profileId,
      name: name,
      avatarBase64: current.avatarBase64,
    );
  }

  Future<bool> profileHasHealthData(String profileId) async {
    final preferences = await SharedPreferences.getInstance();
    final rawMeasurements = preferences.getString(_measurementsKey(profileId));
    if (rawMeasurements != null) {
      try {
        if ((jsonDecode(rawMeasurements) as List).isNotEmpty) return true;
      } catch (_) {}
    }
    final rawProfile = preferences.getString(_profileKey(profileId));
    if (rawProfile == null) return false;
    try {
      final profile = HealthProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(rawProfile) as Map),
      );
      return profile.sex != HealthSex.unspecified ||
          profile.birthYear != null ||
          profile.heightCm != null ||
          profile.unitSystem != HealthUnitSystem.metric;
    } catch (_) {
      return true;
    }
  }

  Future<void> deleteLocalProfile(String profileId) async {
    final profiles = await loadLocalProfiles();
    if (profiles.length <= 1) {
      throw StateError('At least one local profile is required.');
    }
    final remaining = profiles.where((profile) => profile.id != profileId).toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profilesKey,
      jsonEncode(remaining.map((value) => value.toJson()).toList()),
    );
    await preferences.remove(_profileKey(profileId));
    await preferences.remove(_measurementsKey(profileId));
    if (preferences.getString(_activeProfileKey) == profileId) {
      await preferences.setString(_activeProfileKey, remaining.first.id);
    }
  }

  Future<String> _resolveProfileId([String? profileId]) async =>
      profileId ?? (await activeLocalProfile()).id;

  Future<HealthProfile> loadProfile([String? profileId]) async {
    final id = await _resolveProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_profileKey(id));
    if (raw == null) return const HealthProfile();
    return HealthProfile.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> saveProfile(HealthProfile profile, [String? profileId]) async {
    final id = await _resolveProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey(id), jsonEncode(profile.toJson()));
  }

  Future<List<WeightMeasurement>> loadMeasurements([String? profileId]) async {
    final id = await _resolveProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_measurementsKey(id));
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

  Future<void> saveMeasurements(List<WeightMeasurement> measurements,
      [String? profileId]) async {
    final id = await _resolveProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _measurementsKey(id),
      jsonEncode(measurements.map((value) => value.toJson()).toList()),
    );
  }

  Future<void> clearMeasurements([String? profileId]) async {
    final id = await _resolveProfileId(profileId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_measurementsKey(id));
  }

  List<LocalProfile> _decodeProfiles(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((value) => LocalProfile.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
