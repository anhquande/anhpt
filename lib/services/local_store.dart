import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/background_music.dart';
import '../models/coach_recording.dart';
import '../models/workout.dart';

class LocalStore {
  static const _workouts = 'anhpt.workouts.v1';
  static const _draft = 'anhpt.draft.v1';
  static const _onboarded = 'anhpt.onboarded';
  static const _voice = 'anhpt.defaultVoice';
  static const _coachRecordings = 'anhpt.coachRecordings.v1';
  static const _musicTracks = 'anhpt.musicTracks.v1';
  static const _workoutMusic = 'anhpt.workoutMusic.v1';

  Future<List<Workout>> loadWorkouts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_workouts);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Workout.fromJson(Map<String, dynamic>.from(e as Map)))
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

  Future<Map<String, CoachRecording>> loadCoachRecordings() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_coachRecordings);
    if (raw == null) return {};
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return decoded.map((key, value) => MapEntry(
        key, CoachRecording.fromJson(Map<String, dynamic>.from(value as Map))));
  }

  Future<void> saveCoachRecordings(
      Map<String, CoachRecording> recordings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _coachRecordings,
        jsonEncode(
            recordings.map((key, value) => MapEntry(key, value.toJson()))));
  }

  Future<List<MusicTrack>> loadMusicTracks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_musicTracks);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => MusicTrack.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveMusicTracks(List<MusicTrack> tracks) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _musicTracks,
        jsonEncode(
            tracks.where((e) => !e.bundled).map((e) => e.toJson()).toList()));
  }

  Future<Map<String, WorkoutMusicConfig>> loadWorkoutMusic() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_workoutMusic);
    if (raw == null) return {};
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return decoded.map((key, value) => MapEntry(key,
        WorkoutMusicConfig.fromJson(Map<String, dynamic>.from(value as Map))));
  }

  Future<void> saveWorkoutMusic(Map<String, WorkoutMusicConfig> configs) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_workoutMusic,
        jsonEncode(configs.map((key, value) => MapEntry(key, value.toJson()))));
  }
}
