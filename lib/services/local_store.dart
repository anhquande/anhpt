import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';

class LocalStore {
  static const _workouts = 'anhpt.workouts.v1';
  static const _draft = 'anhpt.draft.v1';
  static const _onboarded = 'anhpt.onboarded';
  static const _voice = 'anhpt.defaultVoice';

  Future<List<Workout>> loadWorkouts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_workouts);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Workout.fromJson(Map<String,dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveWorkouts(List<Workout> workouts) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _workouts,
      jsonEncode(workouts.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveDraft(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_draft, value);
  }

  Future<String?> loadDraft() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_draft);
  }

  Future<void> clearDraft() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_draft);
  }

  Future<bool> isOnboarded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_onboarded) ?? false;
  }

  Future<void> setOnboarded() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_onboarded, true);
  }

  Future<String> defaultVoiceLanguage() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_voice) ?? 'vi';
  }

  Future<void> setDefaultVoiceLanguage(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_voice, value);
  }
}
