import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/background_music.dart';
import '../models/coach_recording.dart';
import '../models/workout.dart';
import '../models/workout_bucket.dart';

class LocalStore {
  static const _workouts = 'anhpt.workouts.v1';
  static const _draft = 'anhpt.draft.v1';
  static const _onboarded = 'anhpt.onboarded';
  static const _voice = 'anhpt.defaultVoice';
  static const _coachRecordings = 'anhpt.coachRecordings.v1';
  static const _musicTracks = 'anhpt.musicTracks.v1';
  static const _workoutMusic = 'anhpt.workoutMusic.v1';
  static const _bucketSources = 'anhpt.bucketSources.v1';
  static const _defaultBucketSourceSeeded = 'anhpt.defaultBucketSourceSeeded.v1';
  static const _installedBucketWorkouts = 'anhpt.installedBucketWorkouts.v1';
  static const _quickFilterTagOrder = 'anhpt.quickFilterTagOrder.v1';
  static const _quickFilterHiddenTags = 'anhpt.quickFilterHiddenTags.v1';
  static const _seenWorkoutIds = 'anhpt.seenWorkoutIds.v1';

  static const defaultBucketSourceId = 'official';
  static const defaultBucketSourceName = 'AnhPT Official';
  static const defaultBucketSourceUrl = 'https://raw.githubusercontent.com/anhquande/anhpt-official-buckets/refs/heads/main/main/bucket.json';

  Future<List<Workout>> loadWorkouts() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_workouts);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Workout.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> saveWorkouts(List<Workout> workouts) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_workouts, jsonEncode(workouts.map((e) => e.toJson()).toList()));
  }

  Future<Set<String>> loadSeenWorkoutIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_seenWorkoutIds) ?? const []).toSet();
  }

  Future<void> markWorkoutSeen(String workoutId) async {
    final p = await SharedPreferences.getInstance();
    final ids = (p.getStringList(_seenWorkoutIds) ?? const []).toSet()..add(workoutId);
    await p.setStringList(_seenWorkoutIds, ids.toList());
  }

  Future<List<String>> loadQuickFilterTagOrder() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_quickFilterTagOrder) ?? const [];
  }

  Future<Set<String>> loadQuickFilterHiddenTags() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_quickFilterHiddenTags) ?? const []).toSet();
  }

  Future<void> saveQuickFilterPreferences({required List<String> orderedTags, required Set<String> hiddenTags}) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_quickFilterTagOrder, orderedTags);
    await p.setStringList(_quickFilterHiddenTags, hiddenTags.toList());
  }

  Future<void> saveDraft(String value) async { final p = await SharedPreferences.getInstance(); await p.setString(_draft, value); }
  Future<String?> loadDraft() async { final p = await SharedPreferences.getInstance(); return p.getString(_draft); }
  Future<void> clearDraft() async { final p = await SharedPreferences.getInstance(); await p.remove(_draft); }
  Future<bool> isOnboarded() async { final p = await SharedPreferences.getInstance(); return p.getBool(_onboarded) ?? false; }
  Future<void> setOnboarded() async { final p = await SharedPreferences.getInstance(); await p.setBool(_onboarded, true); }
  Future<String> defaultVoiceLanguage() async { final p = await SharedPreferences.getInstance(); return p.getString(_voice) ?? 'vi'; }
  Future<void> setDefaultVoiceLanguage(String value) async { final p = await SharedPreferences.getInstance(); await p.setString(_voice, value); }

  Future<Map<String, CoachRecording>> loadCoachRecordings() async {
    final p = await SharedPreferences.getInstance(); final raw = p.getString(_coachRecordings); if (raw == null) return {};
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return decoded.map((key, value) => MapEntry(key, CoachRecording.fromJson(Map<String, dynamic>.from(value as Map))));
  }
  Future<void> saveCoachRecordings(Map<String, CoachRecording> recordings) async { final p = await SharedPreferences.getInstance(); await p.setString(_coachRecordings, jsonEncode(recordings.map((k,v)=>MapEntry(k,v.toJson())))); }
  Future<List<MusicTrack>> loadMusicTracks() async { final p=await SharedPreferences.getInstance(); final raw=p.getString(_musicTracks); if(raw==null)return[]; return (jsonDecode(raw) as List).map((e)=>MusicTrack.fromJson(Map<String,dynamic>.from(e as Map))).toList(); }
  Future<void> saveMusicTracks(List<MusicTrack> tracks) async { final p=await SharedPreferences.getInstance(); await p.setString(_musicTracks,jsonEncode(tracks.where((e)=>!e.bundled).map((e)=>e.toJson()).toList())); }
  Future<Map<String, WorkoutMusicConfig>> loadWorkoutMusic() async { final p=await SharedPreferences.getInstance(); final raw=p.getString(_workoutMusic); if(raw==null)return{}; final d=Map<String,dynamic>.from(jsonDecode(raw) as Map); return d.map((k,v)=>MapEntry(k,WorkoutMusicConfig.fromJson(Map<String,dynamic>.from(v as Map)))); }
  Future<void> saveWorkoutMusic(Map<String, WorkoutMusicConfig> configs) async { final p=await SharedPreferences.getInstance(); await p.setString(_workoutMusic,jsonEncode(configs.map((k,v)=>MapEntry(k,v.toJson())))); }

  Future<List<WorkoutBucketSource>> loadBucketSources() async {
    final p=await SharedPreferences.getInstance(); final raw=p.getString(_bucketSources);
    final sources=raw==null?<WorkoutBucketSource>[]:(jsonDecode(raw) as List).map((v)=>WorkoutBucketSource.fromJson(Map<String,dynamic>.from(v as Map))).toList();
    final seeded=p.getBool(_defaultBucketSourceSeeded)??false; if(seeded)return sources;
    final result=sources.any((s)=>s.catalogUrl==defaultBucketSourceUrl)?sources:[const WorkoutBucketSource(id:defaultBucketSourceId,name:defaultBucketSourceName,catalogUrl:defaultBucketSourceUrl),...sources];
    await p.setString(_bucketSources,jsonEncode(result.map((s)=>s.toJson()).toList())); await p.setBool(_defaultBucketSourceSeeded,true); return result;
  }
  Future<void> saveBucketSources(List<WorkoutBucketSource> sources) async { final p=await SharedPreferences.getInstance(); await p.setString(_bucketSources,jsonEncode(sources.map((s)=>s.toJson()).toList())); }
  Future<List<InstalledWorkoutProvenance>> loadInstalledBucketWorkouts() async { final p=await SharedPreferences.getInstance(); final raw=p.getString(_installedBucketWorkouts); if(raw==null)return[]; return (jsonDecode(raw) as List).map((v)=>InstalledWorkoutProvenance.fromJson(Map<String,dynamic>.from(v as Map))).toList(); }
  Future<void> saveInstalledBucketWorkouts(List<InstalledWorkoutProvenance> workouts) async { final p=await SharedPreferences.getInstance(); await p.setString(_installedBucketWorkouts,jsonEncode(workouts.map((w)=>w.toJson()).toList())); }
}
