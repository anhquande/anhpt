import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../data/sample_data.dart';
import '../models/coach_recording.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../models/workout_draft.dart';
import '../services/local_store.dart';
import '../services/workout_parser.dart';
import '../services/workout_serializer.dart';
import '../services/music_library_service.dart';
import '../services/workout_package_service.dart';

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
  final WorkoutPackageService workoutPackages = WorkoutPackageService();
  String? _documentsPath;

  Future<void> initialize() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        _documentsPath = (await getApplicationDocumentsDirectory()).path;
      } catch (_) {
        _documentsPath = null;
      }
    }
    onboarded = await store.isOnboarded();
    defaultVoiceLanguage = await store.defaultVoiceLanguage();
    workouts = await store.loadWorkouts();
    workouts = workouts.map((stored) {
      try {
        return WorkoutParser.parse(
          stored.rawYaml,
          id: stored.id,
          defaultVoiceLanguage: defaultVoiceLanguage,
          favorite: stored.favorite,
          createdAt: stored.createdAt,
        ).copyWith(
          updatedAt: stored.updatedAt,
          lastUsedAt: stored.lastUsedAt,
        );
      } on WorkoutValidationException {
        return stored;
      }
    }).toList();
    coachRecordings = await store.loadCoachRecordings();
    final personalTracks = await store.loadMusicTracks();
    musicTracks = [
      MusicTrack(
          id: 'bundled-soft-bell',
          name: 'Soft Bell Pulse',
          mood: 'Calm',
          source: 'audio/bell.wav',
          bundled: true,
          createdAt: DateTime.utc(2026)),
      ...personalTracks,
    ];
    await _refreshGeneratedMusicNames(personalTracks);
    workoutMusic = await store.loadWorkoutMusic();

    await _migrateLegacyAudioAssignments();

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

  String portableAudioSource(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('asset:')) return normalized;
    final root = _documentsPath?.replaceAll('\\', '/');
    if (root != null &&
        normalized.toLowerCase().startsWith('${root.toLowerCase()}/')) {
      return normalized.substring(root.length + 1);
    }
    for (final folder in const ['coach_recordings', 'music']) {
      final marker = '/$folder/';
      final index = normalized.toLowerCase().lastIndexOf(marker);
      if (index >= 0) return normalized.substring(index + 1);
    }
    return normalized;
  }

  String resolveAudioSource(String source) {
    if (source.startsWith('asset:')) return source.substring(6);
    final root = _documentsPath;
    if (root == null || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source)) {
      return source;
    }
    return '$root/${source.replaceAll('\\', '/')}';
  }

  String _trackSource(MusicTrack track) => track.bundled
      ? 'asset:${track.source}'
      : portableAudioSource(track.source);

  Future<void> _migrateLegacyAudioAssignments() async {
    var changed = false;
    final migrated = <Workout>[];
    for (final workout in workouts) {
      final draft = WorkoutDraft.fromWorkout(workout);
      var workoutChanged = false;
      if (draft.recording.isEmpty) {
        CoachRecording? legacy;
        for (final item in coachRecordings.values) {
          if (item.workoutId == workout.id && item.scope == 'description') {
            legacy = item;
            break;
          }
        }
        if (legacy != null) {
          draft.recording = portableAudioSource(legacy.audioPath);
          workoutChanged = true;
        }
      }
      for (final legacy in coachRecordings.values.where((item) =>
          item.workoutId == workout.id &&
          item.scope == 'step' &&
          item.stepKey != null)) {
        final step = _draftStepAt(draft.steps, legacy.stepKey!);
        if (step != null && step.recording.isEmpty) {
          step.recording = portableAudioSource(legacy.audioPath);
          step.hasExplicitId = true;
          workoutChanged = true;
        }
      }
      final legacyMusic = workoutMusic[workout.id];
      if (draft.backgroundMusicSource.isEmpty && legacyMusic?.trackId != null) {
        final track = musicTrackById(legacyMusic!.trackId);
        if (track != null) {
          draft.backgroundMusicSource = _trackSource(track);
          draft.backgroundMusicName = track.name;
          draft.backgroundMusicEnabled = legacyMusic.enabled;
          draft.backgroundMusicVolume = legacyMusic.baseVolume;
          draft.backgroundMusicDucking = legacyMusic.duckingMode;
          workoutChanged = true;
        }
      }
      if (workoutChanged) {
        migrated.add(_parseDraft(draft, workout));
        changed = true;
      } else {
        migrated.add(workout);
      }
    }
    if (changed) {
      workouts = migrated;
      await store.saveWorkouts(workouts);
    }
    if (coachRecordings.isNotEmpty || workoutMusic.isNotEmpty) {
      coachRecordings = {};
      workoutMusic = {};
      await store.saveCoachRecordings(coachRecordings);
      await store.saveWorkoutMusic(workoutMusic);
    }
  }

  Workout _parseDraft(WorkoutDraft draft, Workout previous) =>
      WorkoutParser.parse(
        WorkoutSerializer.toYaml(draft),
        id: previous.id,
        defaultVoiceLanguage: defaultVoiceLanguage,
        favorite: previous.favorite,
        createdAt: previous.createdAt,
      );

  StepDraft? _draftStepAt(List<WorkoutDraftNode> nodes, String path) {
    final indexes = path.split('.').map(int.tryParse).toList();
    List<WorkoutDraftNode> current = nodes;
    for (var depth = 0; depth < indexes.length; depth++) {
      final index = indexes[depth];
      if (index == null || index < 0 || index >= current.length) return null;
      final node = current[index];
      if (depth == indexes.length - 1) return node is StepDraft ? node : null;
      if (node is! RepeatDraft) return null;
      current = node.steps;
    }
    return null;
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

  Future<bool> exportWorkoutPackage(String workoutId) async {
    final workout = byId(workoutId);
    if (workout == null) return false;
    return workoutPackages.exportPackage(
      workout,
      resolveSource: resolveAudioSource,
    );
  }

  Future<bool> importWorkoutPackage() async {
    final workout = await workoutPackages.importPackage(
      defaultVoiceLanguage: defaultVoiceLanguage,
    );
    if (workout == null) return false;
    await saveWorkout(workout);
    return true;
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
    final workout = byId(workoutId);
    if (workout == null) return null;
    String? source;
    if (scope == 'description') source = workout.recording;
    if (scope == 'step' && stepKey != null) {
      source = _workoutStepAt(workout.steps, stepKey)?.recording;
    }
    if (source == null) return null;
    return CoachRecording(
        workoutId: workoutId,
        cue: scope == 'description' ? 'workout_description' : 'step_voice',
        scope: scope,
        stepKey: stepKey,
        language: '',
        audioPath: resolveAudioSource(source),
        createdAt: workout.updatedAt);
  }

  Future<void> assignCoachRecording(CoachRecording recording) async {
    final workout = byId(recording.workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout);
    final source = portableAudioSource(recording.audioPath);
    if (recording.scope == 'description') {
      draft.recording = source;
    } else if (recording.stepKey != null) {
      final step = _draftStepAt(draft.steps, recording.stepKey!);
      if (step == null) return;
      step.recording = source;
      step.hasExplicitId = true;
    }
    await saveWorkout(_parseDraft(draft, workout));
  }

  Future<CoachRecording?> removeCoachRecording({
    required String workoutId,
    required String scope,
    String? stepKey,
  }) async {
    final removed =
        coachRecordingFor(workoutId: workoutId, scope: scope, stepKey: stepKey);
    final workout = byId(workoutId);
    if (removed == null || workout == null) return removed;
    final draft = WorkoutDraft.fromWorkout(workout);
    if (scope == 'description') {
      draft.recording = '';
    } else if (stepKey != null) {
      final step = _draftStepAt(draft.steps, stepKey);
      if (step != null) step.recording = '';
    }
    await saveWorkout(_parseDraft(draft, workout));
    return removed;
  }

  WorkoutStep? _workoutStepAt(List<WorkoutNode> nodes, String path) {
    final indexes = path.split('.').map(int.tryParse).toList();
    List<WorkoutNode> current = nodes;
    for (var depth = 0; depth < indexes.length; depth++) {
      final index = indexes[depth];
      if (index == null || index < 0 || index >= current.length) return null;
      final node = current[index];
      if (depth == indexes.length - 1) return node is WorkoutStep ? node : null;
      if (node is! RepeatGroup) return null;
      current = node.steps;
    }
    return null;
  }

  WorkoutMusicConfig musicConfigFor(String workoutId) {
    final music = byId(workoutId)?.backgroundMusic;
    if (music == null) return WorkoutMusicConfig(workoutId: workoutId);
    MusicTrack? track;
    for (final item in musicTracks) {
      if (_trackSource(item) == music.source) {
        track = item;
        break;
      }
    }
    return WorkoutMusicConfig(
        workoutId: workoutId,
        trackId: track?.id,
        enabled: music.enabled,
        baseVolume: music.volume,
        duckingMode: music.ducking);
  }

  MusicTrack? musicTrackById(String? id) {
    if (id == null) return null;
    for (final track in musicTracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  Future<bool> importMusicTrack() async {
    final imported = await musicLibrary.importAudioFile();
    if (imported == null) return false;
    final name = await musicLibrary.resolveDisplayName(
      imported.path,
      originalFileName: imported.originalFileName,
    );
    musicTracks.add(MusicTrack(
        id: 'personal-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        mood: 'Custom',
        source: imported.path,
        bundled: false,
        createdAt: DateTime.now()));
    await store.saveMusicTracks(musicTracks);
    notifyListeners();
    return true;
  }

  Future<void> _refreshGeneratedMusicNames(
      List<MusicTrack> personalTracks) async {
    var changed = false;
    final renamedSources = <String, String>{};
    for (final track in personalTracks) {
      final cleaned = MusicLibraryService.cleanFileName(track.name);
      if (cleaned == track.name && cleaned != 'Imported track') continue;
      final resolved = await musicLibrary.resolveDisplayName(
        track.source,
        persistedName: track.name,
      );
      final index = musicTracks.indexWhere((item) => item.id == track.id);
      if (index < 0 || resolved == musicTracks[index].name) continue;
      musicTracks[index] = MusicTrack(
        id: track.id,
        name: resolved,
        mood: track.mood,
        source: track.source,
        bundled: false,
        createdAt: track.createdAt,
      );
      renamedSources[_trackSource(musicTracks[index])] = resolved;
      changed = true;
    }
    if (!changed) return;
    await store.saveMusicTracks(musicTracks);
    workouts = workouts.map((workout) {
      final music = workout.backgroundMusic;
      final resolved = music == null ? null : renamedSources[music.source];
      if (resolved == null || resolved == music!.name) return workout;
      final draft = WorkoutDraft.fromWorkout(workout)
        ..backgroundMusicName = resolved;
      return _parseDraft(draft, workout);
    }).toList();
    await store.saveWorkouts(workouts);
  }

  Future<void> updateMusicTrack(MusicTrack updated) async {
    final index = musicTracks.indexWhere((track) => track.id == updated.id);
    if (index < 0 || musicTracks[index].bundled) return;
    final affectedWorkoutIds = workoutsUsingTrack(updated.id);
    musicTracks[index] = updated;
    await store.saveMusicTracks(musicTracks);
    for (final workoutId in affectedWorkoutIds) {
      final workout = byId(workoutId);
      if (workout == null) continue;
      final draft = WorkoutDraft.fromWorkout(workout)
        ..backgroundMusicName = updated.name;
      await saveWorkout(_parseDraft(draft, workout));
    }
    notifyListeners();
  }

  List<String> workoutsUsingTrack(String trackId) {
    final track = musicTrackById(trackId);
    if (track == null) return [];
    final source = _trackSource(track);
    return workouts
        .where((workout) => workout.backgroundMusic?.source == source)
        .map((workout) => workout.id)
        .toList();
  }

  Future<void> deleteMusicTrack(String trackId) async {
    final track = musicTrackById(trackId);
    if (track == null || track.bundled) return;
    for (final workoutId in workoutsUsingTrack(trackId)) {
      final workout = byId(workoutId)!;
      final draft = WorkoutDraft.fromWorkout(workout)
        ..backgroundMusicSource = ''
        ..backgroundMusicName = '';
      await saveWorkout(_parseDraft(draft, workout));
    }
    musicTracks.removeWhere((item) => item.id == trackId);
    await musicLibrary.delete(track.source);
    await store.saveMusicTracks(musicTracks);
    await store.saveWorkoutMusic(workoutMusic);
    notifyListeners();
  }

  Future<void> setWorkoutMusic(WorkoutMusicConfig config) async {
    final workout = byId(config.workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout);
    final track = musicTrackById(config.trackId);
    if (track == null) {
      draft.backgroundMusicSource = '';
      draft.backgroundMusicName = '';
    } else {
      draft.backgroundMusicSource = _trackSource(track);
      draft.backgroundMusicName = track.name;
      draft.backgroundMusicEnabled = config.enabled;
      draft.backgroundMusicVolume = config.baseVolume;
      draft.backgroundMusicDucking = config.duckingMode;
    }
    await saveWorkout(_parseDraft(draft, workout));
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
