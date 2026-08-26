import 'package:flutter/foundation.dart';
import '../data/sample_data.dart';
import '../models/coach_recording.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../services/local_store.dart';
import '../services/workout_parser.dart';
import '../services/music_library_service.dart';

class AppController extends ChangeNotifier {
  final LocalStore store;
  AppController(this.store);

  bool loading = true;
  bool onboarded = false;
  String defaultVoiceLanguage = 'vi';
  List<Workout> workouts = [];
  Map<String, CoachRecording> coachRecordings = {};
  List<MusicTrack> musicTracks = [];
  Map<String, WorkoutMusicConfig> workoutMusic = {};
  final MusicLibraryService musicLibrary = MusicLibraryService();

  Future<void> initialize() async {
    onboarded = await store.isOnboarded();
    defaultVoiceLanguage = await store.defaultVoiceLanguage();
    workouts = await store.loadWorkouts();
    coachRecordings = await store.loadCoachRecordings();
    musicTracks = [
      MusicTrack(
          id: 'bundled-soft-bell',
          name: 'Soft Bell Pulse',
          mood: 'Calm',
          source: 'audio/bell.wav',
          bundled: true,
          createdAt: DateTime.utc(2026)),
      ...await store.loadMusicTracks(),
    ];
    workoutMusic = await store.loadWorkoutMusic();

    if (workouts.isEmpty) {
      final sample = WorkoutParser.parse(
        sampleYaml,
        id: WorkoutParser.generateId(),
        defaultVoiceLanguage: defaultVoiceLanguage,
        favorite: true,
      );
      workouts = [sample];
      await store.saveWorkouts(workouts);
    }

    loading = false;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await store.setOnboarded();
    notifyListeners();
  }

  Workout? byId(String id) {
    for (final w in workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> saveWorkout(Workout workout) async {
    final i = workouts.indexWhere((w) => w.id == workout.id);
    if (i >= 0) {
      workouts[i] = workout;
    } else {
      workouts.add(workout);
    }
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> deleteWorkout(String id) async {
    workouts.removeWhere((w) => w.id == id);
    workoutMusic.remove(id);
    await store.saveWorkouts(workouts);
    await store.saveWorkoutMusic(workoutMusic);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final i = workouts.indexWhere((w) => w.id == id);
    if (i < 0) return;
    workouts[i] = workouts[i].copyWith(
      favorite: !workouts[i].favorite,
      updatedAt: DateTime.now(),
    );
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> markUsed(String id) async {
    final i = workouts.indexWhere((w) => w.id == id);
    if (i < 0) return;
    workouts[i] = workouts[i].copyWith(
      lastUsedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await store.saveWorkouts(workouts);
    notifyListeners();
  }

  Future<void> updateDefaultVoiceLanguage(String value) async {
    defaultVoiceLanguage = value;
    await store.setDefaultVoiceLanguage(value);
    notifyListeners();
  }

  CoachRecording? coachRecordingFor({
    required String workoutId,
    required String scope,
    String? stepKey,
  }) {
    for (final recording in coachRecordings.values) {
      if (recording.workoutId == workoutId &&
          recording.scope == scope &&
          recording.stepKey == stepKey) {
        return recording;
      }
    }
    return null;
  }

  Future<void> assignCoachRecording(CoachRecording recording) async {
    coachRecordings.removeWhere((_, existing) =>
        existing.workoutId == recording.workoutId &&
        existing.scope == recording.scope &&
        existing.stepKey == recording.stepKey);
    coachRecordings[recording.storageKey] = recording;
    await store.saveCoachRecordings(coachRecordings);
    notifyListeners();
  }

  Future<CoachRecording?> removeCoachRecording({
    required String workoutId,
    required String scope,
    String? stepKey,
  }) async {
    String? match;
    for (final entry in coachRecordings.entries) {
      if (entry.value.workoutId == workoutId &&
          entry.value.scope == scope &&
          entry.value.stepKey == stepKey) {
        match = entry.key;
        break;
      }
    }
    final removed = match == null ? null : coachRecordings.remove(match);
    await store.saveCoachRecordings(coachRecordings);
    notifyListeners();
    return removed;
  }

  WorkoutMusicConfig musicConfigFor(String workoutId) =>
      workoutMusic[workoutId] ?? WorkoutMusicConfig(workoutId: workoutId);
  MusicTrack? musicTrackById(String? id) {
    if (id == null) return null;
    for (final track in musicTracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  Future<bool> importMusicTrack() async {
    final path = await musicLibrary.importAudioFile();
    if (path == null) return false;
    final name =
        path.split(RegExp(r'[\\/]')).last.replaceFirst(RegExp(r'\.[^.]+$'), '');
    musicTracks.add(MusicTrack(
        id: 'personal-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        mood: 'Custom',
        source: path,
        bundled: false,
        createdAt: DateTime.now()));
    await store.saveMusicTracks(musicTracks);
    notifyListeners();
    return true;
  }

  Future<void> updateMusicTrack(MusicTrack updated) async {
    final index = musicTracks.indexWhere((track) => track.id == updated.id);
    if (index < 0 || musicTracks[index].bundled) return;
    musicTracks[index] = updated;
    await store.saveMusicTracks(musicTracks);
    notifyListeners();
  }

  List<String> workoutsUsingTrack(String trackId) => workoutMusic.values
      .where((config) => config.trackId == trackId)
      .map((config) => config.workoutId)
      .toList();

  Future<void> deleteMusicTrack(String trackId) async {
    final track = musicTrackById(trackId);
    if (track == null || track.bundled) return;
    for (final workoutId in workoutsUsingTrack(trackId)) {
      workoutMusic[workoutId] =
          musicConfigFor(workoutId).copyWith(clearTrack: true, enabled: false);
    }
    musicTracks.removeWhere((item) => item.id == trackId);
    await musicLibrary.delete(track.source);
    await store.saveMusicTracks(musicTracks);
    await store.saveWorkoutMusic(workoutMusic);
    notifyListeners();
  }

  Future<void> setWorkoutMusic(WorkoutMusicConfig config) async {
    workoutMusic[config.workoutId] = config;
    await store.saveWorkoutMusic(workoutMusic);
    notifyListeners();
  }

  List<Workout> get favorites {
    final list = workouts.where((w) => w.favorite).toList();
    list.sort(_recent);
    return list;
  }

  List<Workout> get others {
    final list = workouts.where((w) => !w.favorite).toList();
    list.sort(_recent);
    return list;
  }

  static int _recent(Workout a, Workout b) {
    final aa = a.lastUsedAt ?? a.updatedAt;
    final bb = b.lastUsedAt ?? b.updatedAt;
    return bb.compareTo(aa);
  }
}
