import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../data/sample_data.dart';
import '../models/coach_recording.dart';
import '../models/background_music.dart';
import '../models/workout.dart';
import '../models/workout_draft.dart';
import '../models/workout_bucket.dart';
import '../models/media_asset.dart';
import '../services/local_store.dart';
import '../services/workout_parser.dart';
import '../services/workout_serializer.dart';
import '../services/music_library_service.dart';
import '../services/workout_package_service.dart';
import '../services/workout_bucket_service.dart';
import '../services/media_repository.dart';
import '../services/workout_yaml_file_store.dart';
import '../services/coach_recording_service.dart';

class AppController extends ChangeNotifier {
  static const currentAppVersion = '0.8.2';
  final LocalStore store;
  final WorkoutYamlFileStore? yamlFileStore;
  AppController(this.store, {this.yamlFileStore});

  bool loading = true;
  bool onboarded = false;
  String defaultVoiceLanguage = 'vi';
  List<Workout> workouts = [];
  Map<String, CoachRecording> coachRecordings = {};
  List<MusicTrack> musicTracks = [];
  Map<String, WorkoutMusicConfig> workoutMusic = {};
  List<WorkoutBucketSource> bucketSources = [];
  List<WorkoutBucketEntry> bucketCatalogEntries = [];
  List<InstalledWorkoutProvenance> installedBucketWorkouts = [];
  bool bucketCatalogLoading = false;
  String? bucketCatalogError;
  final MusicLibraryService musicLibrary = MusicLibraryService();
  final WorkoutPackageService workoutPackages = WorkoutPackageService();
  final WorkoutBucketService workoutBuckets = WorkoutBucketService();
  final LocalMediaRepository mediaLibrary = LocalMediaRepository();
  final CoachRecordingService recordingFiles = CoachRecordingService();
  String? _documentsPath;

  Future<void> initialize() async {
    if (!kIsWeb) {
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
        ).copyWith(updatedAt: stored.updatedAt, lastUsedAt: stored.lastUsedAt);
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
        createdAt: DateTime.utc(2026),
      ),
      ...personalTracks,
    ];
    await _refreshGeneratedMusicNames(personalTracks);
    workoutMusic = await store.loadWorkoutMusic();
    bucketSources = await store.loadBucketSources();
    installedBucketWorkouts = await store.loadInstalledBucketWorkouts();
    final storedProvenanceCount = installedBucketWorkouts.length;
    _removeOrphanedBucketProvenance();
    if (installedBucketWorkouts.length != storedProvenanceCount) {
      await store.saveInstalledBucketWorkouts(installedBucketWorkouts);
    }
    _loadCachedBucketCatalogs();

    await _migrateLegacyAudioAssignments();
    await _migrateReadableRecordingNames();
    await _migrateReadableMusicPaths();
    await _migrateDemoMediaReferences();

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

    await yamlFileStore?.replaceAll(workouts);

    loading = false;
    notifyListeners();
  }

  Future<MediaAsset?> importDemoMedia() async {
    if (kIsWeb) {
      throw StateError(
        'Local demonstration media import is not available on Web yet.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return null;
      final file = File(picked.path);
      if (await file.length() > 20 * 1024 * 1024) {
        throw StateError('Demonstration media must be 20 MB or smaller.');
      }
      return mediaLibrary.importFile(file, type: 'video');
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose exercise demonstration media',
      type: FileType.custom,
      allowedExtensions: const [
        'mp4',
        'mov',
        'webm',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
      ],
      withData: kIsWeb,
    );
    if (result == null) return null;
    final picked = result.files.single;
    if (picked.size > 20 * 1024 * 1024) {
      throw StateError('Demonstration media must be 20 MB or smaller.');
    }
    final extension = picked.extension?.toLowerCase() ?? '';
    final type = extension == 'gif'
        ? 'animation'
        : {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? 'image'
        : 'video';
    if (picked.bytes != null) {
      return mediaLibrary.importBytes(
        picked.bytes!,
        fileName: picked.name,
        type: type,
      );
    }
    if (picked.path == null) {
      throw StateError('Could not read the selected media file.');
    }
    return mediaLibrary.importFile(File(picked.path!), type: type);
  }

  Future<Uri?> resolveMediaUri(String mediaId) =>
      mediaLibrary.resolveUri(mediaId);

  Future<MediaAsset?> mediaAsset(String mediaId) => mediaLibrary.get(mediaId);

  Future<void> _migrateDemoMediaReferences() async {
    var changed = false;
    final migrated = <Workout>[];
    for (final workout in workouts) {
      final draft = WorkoutDraft.fromWorkout(workout);
      var workoutChanged = false;
      for (var index = 0; index < draft.exercises.length; index++) {
        final exercise = draft.exercises[index];
        final reference = exercise.demoMediaId;
        if (reference == null || !reference.startsWith('sha256:')) continue;
        final asset = await mediaLibrary.get(reference);
        if (asset == null) continue;
        draft.exercises[index] = Exercise(
          id: exercise.id,
          name: exercise.name,
          demoMediaId: asset.relativePath,
        );
        workoutChanged = true;
      }
      migrated.add(workoutChanged ? _parseDraft(draft, workout) : workout);
      changed = changed || workoutChanged;
    }
    if (changed) {
      workouts = migrated;
      await store.saveWorkouts(workouts);
    }
  }

  Future<void> _migrateReadableRecordingNames() async {
    var changed = false;
    final migrated = <Workout>[];
    for (final workout in workouts) {
      final draft = WorkoutDraft.fromWorkout(workout);
      var workoutChanged = false;

      Future<String> migrateSource(String source, String cueName) async {
        if (source.startsWith('asset:')) return source;
        final absolute = resolveAudioSource(source);
        if (!await File(absolute).exists()) return source;
        final leaf = absolute.replaceAll('\\', '/').split('/').last;
        final dot = leaf.lastIndexOf('.');
        final currentStem = dot > 0 ? leaf.substring(0, dot) : leaf;
        final expected = CoachRecordingService.readableStem(cueName);
        final alreadyManaged = source
            .replaceAll('\\', '/')
            .startsWith('coach_recordings/');
        if (alreadyManaged &&
            RegExp(
              '^${RegExp.escape(expected)}(?:-[0-9]+)?\$',
            ).hasMatch(currentStem)) {
          return source;
        }
        final renamed = await recordingFiles.renameForCue(absolute, cueName);
        return portableAudioSource(renamed);
      }

      if (draft.recording.isNotEmpty) {
        final renamed = await migrateSource(
          draft.recording,
          '${workout.name} introduction',
        );
        if (renamed != draft.recording) {
          draft.recording = renamed;
          workoutChanged = true;
        }
      }

      Future<void> migrateSteps(List<WorkoutDraftNode> nodes) async {
        for (final node in nodes) {
          if (node is StepDraft && node.recording.isNotEmpty) {
            final renamed = await migrateSource(node.recording, node.name);
            if (renamed != node.recording) {
              node.recording = renamed;
              workoutChanged = true;
            }
          } else if (node is RepeatDraft) {
            await migrateSteps(node.steps);
          }
        }
      }

      await migrateSteps(draft.steps);
      migrated.add(workoutChanged ? _parseDraft(draft, workout) : workout);
      changed = changed || workoutChanged;
    }
    if (changed) {
      workouts = migrated;
      await store.saveWorkouts(workouts);
    }
  }

  Future<void> _migrateReadableMusicPaths() async {
    final migratedSources = <String, String>{};
    var tracksChanged = false;
    for (var index = 0; index < musicTracks.length; index++) {
      final track = musicTracks[index];
      if (track.bundled) continue;
      final oldSource = _trackSource(track);
      final absolute = resolveAudioSource(oldSource);
      if (!await File(absolute).exists()) continue;
      final moved = await musicLibrary.moveToLibrary(absolute, track.name);
      final newSource = portableAudioSource(moved);
      migratedSources[oldSource] = newSource;
      if (moved == track.source) continue;
      musicTracks[index] = MusicTrack(
        id: track.id,
        name: track.name,
        mood: track.mood,
        source: moved,
        bundled: false,
        createdAt: track.createdAt,
      );
      tracksChanged = true;
    }

    var workoutsChanged = false;
    final migratedWorkouts = <Workout>[];
    for (final workout in workouts) {
      final music = workout.backgroundMusic;
      if (music == null || music.source.startsWith('asset:')) {
        migratedWorkouts.add(workout);
        continue;
      }
      var replacement = migratedSources[music.source];
      if (replacement == null) {
        final absolute = resolveAudioSource(music.source);
        if (await File(absolute).exists()) {
          final preferred = music.name?.trim().isNotEmpty == true
              ? music.name!
              : absolute.replaceAll('\\', '/').split('/').last;
          final moved = await musicLibrary.moveToLibrary(absolute, preferred);
          replacement = portableAudioSource(moved);
          migratedSources[music.source] = replacement;
        }
      }

      final effectiveSource = replacement ?? music.source;
      final alreadyInLibrary = musicTracks.any(
        (track) => _trackSource(track) == effectiveSource,
      );
      final effectiveAbsolute = resolveAudioSource(effectiveSource);
      if (!alreadyInLibrary && await File(effectiveAbsolute).exists()) {
        final preferredName = music.name?.trim();
        final displayName = preferredName != null && preferredName.isNotEmpty
            ? preferredName
            : await musicLibrary.resolveDisplayName(effectiveAbsolute);
        musicTracks.add(
          MusicTrack(
            id: 'personal-${DateTime.now().microsecondsSinceEpoch}',
            name: displayName,
            mood: 'Imported',
            source: effectiveAbsolute,
            bundled: false,
            createdAt: DateTime.now(),
          ),
        );
        tracksChanged = true;
      }

      if (replacement == null || replacement == music.source) {
        migratedWorkouts.add(workout);
        continue;
      }
      final draft = WorkoutDraft.fromWorkout(workout)
        ..backgroundMusicSource = replacement;
      migratedWorkouts.add(_parseDraft(draft, workout));
      workoutsChanged = true;
    }
    if (tracksChanged) await store.saveMusicTracks(musicTracks);
    if (workoutsChanged) {
      workouts = migratedWorkouts;
      await store.saveWorkouts(workouts);
    }
  }

  Future<void> assignStepDemoMedia({
    required String workoutId,
    required String stepKey,
    required MediaAsset asset,
  }) async {
    final workout = byId(workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout);
    final step = _draftStepAt(draft.steps, stepKey);
    if (step == null) return;
    final existingIndex = draft.exercises.indexWhere(
      (exercise) => exercise.id == step.exerciseId,
    );
    final normalizedName = step.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = normalizedName.isEmpty
        ? asset.id.substring(7, 15)
        : normalizedName;
    var exerciseId = existingIndex >= 0
        ? draft.exercises[existingIndex].id
        : 'exercise-$base';
    var suffix = 2;
    while (draft.exercises.any(
      (exercise) => exercise.id == exerciseId && exercise.id != step.exerciseId,
    )) {
      exerciseId = 'exercise-$base-${suffix++}';
    }
    final exercise = Exercise(
      id: exerciseId,
      name: step.name.trim(),
      demoMediaId: asset.relativePath,
    );
    if (existingIndex >= 0) {
      draft.exercises[existingIndex] = exercise;
    } else {
      draft.exercises.add(exercise);
    }
    step.exerciseId = exerciseId;
    await saveWorkout(_parseDraft(draft, workout));
  }

  Future<void> removeStepDemoMedia({
    required String workoutId,
    required String stepKey,
  }) async {
    final workout = byId(workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout);
    final step = _draftStepAt(draft.steps, stepKey);
    if (step == null || step.exerciseId.isEmpty) return;
    final exerciseId = step.exerciseId;
    step.exerciseId = '';
    bool isUsed(List<WorkoutDraftNode> nodes) {
      for (final node in nodes) {
        if (node is StepDraft && node.exerciseId == exerciseId) return true;
        if (node is RepeatDraft && isUsed(node.steps)) return true;
      }
      return false;
    }

    if (!isUsed(draft.steps)) {
      draft.exercises.removeWhere((exercise) => exercise.id == exerciseId);
    }
    await saveWorkout(_parseDraft(draft, workout));
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
      for (final legacy in coachRecordings.values.where(
        (item) =>
            item.workoutId == workout.id &&
            item.scope == 'step' &&
            item.stepKey != null,
      )) {
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
    await yamlFileStore?.save(workout);
    notifyListeners();
  }

  Future<void> setWorkoutCompletionAction(
    String workoutId, {
    required bool enabled,
  }) async {
    final workout = byId(workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout)
      ..completionAction = enabled ? 'shutdown_or_exit' : 'none';
    await saveWorkout(_parseDraft(draft, workout));
  }

  Future<void> setWorkoutScreenOffAfterStart(
    String workoutId, {
    required bool enabled,
  }) async {
    final workout = byId(workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout)
      ..screenOffAfterStart = enabled ? '10s' : '';
    await saveWorkout(_parseDraft(draft, workout));
  }

  Future<bool> exportWorkoutPackage(String workoutId) async {
    final workout = byId(workoutId);
    if (workout == null) return false;
    return workoutPackages.exportPackage(
      workout,
      resolveSource: resolveAudioSource,
      mediaRepository: mediaLibrary,
    );
  }

  Future<bool> importWorkoutPackage() async {
    final workout = await workoutPackages.importPackage(
      defaultVoiceLanguage: defaultVoiceLanguage,
      mediaRepository: mediaLibrary,
    );
    if (workout == null) return false;
    await saveWorkout(workout);
    await _migrateReadableMusicPaths();
    await yamlFileStore?.replaceAll(workouts);
    return true;
  }

  void _loadCachedBucketCatalogs() {
    final entries = <WorkoutBucketEntry>[];
    for (final source in bucketSources.where((item) => item.enabled)) {
      final cached = source.cachedCatalogJson;
      if (cached == null) continue;
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(cached) as Map);
        entries.addAll(
          WorkoutBucketCatalog.fromJson(
            decoded,
          ).entries.map((entry) => entry.copyWithSource(source.id)),
        );
      } catch (_) {
        // A bad cache is ignored and replaced on the next successful refresh.
      }
    }
    bucketCatalogEntries = entries;
  }

  Future<void> addBucketSource(String name, String catalogUrl) async {
    final uri = requirePublicHttpsUri(catalogUrl, field: 'catalog URL');
    final source = WorkoutBucketSource(
      id: 'bucket-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? uri.host : name.trim(),
      catalogUrl: uri.toString(),
    );
    bucketSources = [...bucketSources, source];
    await store.saveBucketSources(bucketSources);
    notifyListeners();
    await refreshBucketSource(source.id);
  }

  Future<void> removeBucketSource(String id) async {
    bucketSources = bucketSources.where((source) => source.id != id).toList();
    bucketCatalogEntries = bucketCatalogEntries
        .where((entry) => entry.sourceId != id)
        .toList();
    await store.saveBucketSources(bucketSources);
    notifyListeners();
  }

  Future<void> setBucketSourceEnabled(String id, bool enabled) async {
    bucketSources = bucketSources
        .map(
          (source) =>
              source.id == id ? source.copyWith(enabled: enabled) : source,
        )
        .toList();
    await store.saveBucketSources(bucketSources);
    _loadCachedBucketCatalogs();
    notifyListeners();
  }

  Future<void> refreshAllBucketSources() async {
    for (final source in bucketSources.where((item) => item.enabled).toList()) {
      await refreshBucketSource(source.id);
    }
  }

  Future<void> refreshBucketSource(String id) async {
    final index = bucketSources.indexWhere((source) => source.id == id);
    if (index < 0 || !bucketSources[index].enabled) return;
    bucketCatalogLoading = true;
    bucketCatalogError = null;
    notifyListeners();
    final source = bucketSources[index];
    try {
      final result = await workoutBuckets.refresh(source);
      bucketSources[index] = source.copyWith(
        lastRefreshedAt: DateTime.now(),
        cachedCatalogJson: result.rawJson,
        clearLastError: true,
      );
      if (result.fromCache) {
        bucketSources[index] = bucketSources[index].copyWith(
          lastError: 'Offline — showing the last downloaded catalog.',
        );
      }
      await store.saveBucketSources(bucketSources);
      _loadCachedBucketCatalogs();
    } catch (error) {
      bucketCatalogError = '$error';
      bucketSources[index] = source.copyWith(lastError: '$error');
      await store.saveBucketSources(bucketSources);
    } finally {
      bucketCatalogLoading = false;
      notifyListeners();
    }
  }

  String bucketInstallState(WorkoutBucketEntry entry) {
    final workoutIds = workouts.map((workout) => workout.id).toSet();
    final installed = installedBucketWorkouts.where(
      (item) =>
          workoutIds.contains(item.workoutId) &&
          item.sourceId == entry.sourceId &&
          item.entryId == entry.id,
    );
    if (installed.isEmpty) return 'notInstalled';
    return installed.any((item) => item.version == entry.version)
        ? 'installed'
        : 'updateAvailable';
  }

  String? bucketEntryCompatibilityError(WorkoutBucketEntry entry) {
    if (entry.minAppVersion != null &&
        _compareVersions(currentAppVersion, entry.minAppVersion!) < 0) {
      return 'Requires AnhPT ${entry.minAppVersion} or newer.';
    }
    return null;
  }

  void _removeOrphanedBucketProvenance() {
    final workoutIds = workouts.map((workout) => workout.id).toSet();
    installedBucketWorkouts.removeWhere(
      (item) => !workoutIds.contains(item.workoutId),
    );
  }

  InstalledWorkoutProvenance? bucketProvenanceFor(String workoutId) {
    for (final item in installedBucketWorkouts) {
      if (item.workoutId == workoutId) return item;
    }
    return null;
  }

  String bucketSourceName(InstalledWorkoutProvenance provenance) {
    final storedName = provenance.sourceName?.trim();
    if (storedName != null && storedName.isNotEmpty) return storedName;
    for (final source in bucketSources) {
      if (source.id == provenance.sourceId) return source.name;
    }
    return provenance.sourceId;
  }

  String? bucketOriginalName(InstalledWorkoutProvenance provenance) {
    final storedName = provenance.originalName?.trim();
    if (storedName != null && storedName.isNotEmpty) return storedName;
    for (final entry in bucketCatalogEntries) {
      if (entry.sourceId == provenance.sourceId &&
          entry.id == provenance.entryId) {
        return entry.name;
      }
    }
    return null;
  }

  Future<bool> installBucketEntry(
    WorkoutBucketEntry entry, {
    BucketInstallConflictResolution? resolution,
  }) async {
    _removeOrphanedBucketProvenance();
    final sourceId = entry.sourceId;
    if (sourceId == null) {
      throw StateError('Catalog entry has no bucket source.');
    }
    final compatibilityError = bucketEntryCompatibilityError(entry);
    if (compatibilityError != null) {
      throw StateError(compatibilityError);
    }
    final existingIndex = installedBucketWorkouts.indexWhere(
      (item) => item.sourceId == sourceId && item.entryId == entry.id,
    );
    if (existingIndex >= 0 && resolution == null) {
      throw StateError('Choose how to handle the installed workout.');
    }
    if (existingIndex >= 0 &&
        resolution == BucketInstallConflictResolution.keepLocal) {
      return false;
    }
    final workoutBytes = await workoutBuckets.downloadWorkout(entry);
    final assetsBytes = await workoutBuckets.downloadAssets(entry);
    var imported = await workoutPackages.importSplitPackageBytes(
      workoutBytes,
      assetsBytes,
      defaultVoiceLanguage: defaultVoiceLanguage,
      mediaRepository: mediaLibrary,
    );
    if (existingIndex >= 0 &&
        resolution == BucketInstallConflictResolution.replace) {
      final previous = installedBucketWorkouts[existingIndex];
      workouts.removeWhere((workout) => workout.id == previous.workoutId);
      installedBucketWorkouts.removeAt(existingIndex);
    }
    final uniqueName = uniqueLocalWorkoutName(
      imported.name,
      workouts.map((workout) => workout.name),
    );
    if (uniqueName != imported.name) {
      final draft = WorkoutDraft.fromWorkout(imported)..name = uniqueName;
      imported = _parseDraft(draft, imported);
    }
    workouts.add(imported);
    final sourceName = bucketSources
        .where((source) => source.id == sourceId)
        .map((source) => source.name)
        .firstOrNull;
    installedBucketWorkouts.add(
      InstalledWorkoutProvenance(
        workoutId: imported.id,
        sourceId: sourceId,
        sourceName: sourceName,
        entryId: entry.id,
        originalName: entry.name,
        version: entry.version,
        packageUrl: entry.workoutUrl,
        sha256: entry.workoutSha256,
        installedAt: DateTime.now(),
      ),
    );
    await _migrateReadableMusicPaths();
    await store.saveWorkouts(workouts);
    await store.saveInstalledBucketWorkouts(installedBucketWorkouts);
    await yamlFileStore?.replaceAll(workouts);
    notifyListeners();
    return true;
  }

  int _compareVersions(String left, String right) {
    final a = left.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    final b = right.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    for (
      var index = 0;
      index < (a.length > b.length ? a.length : b.length);
      index++
    ) {
      final av = index < a.length ? a[index] : 0;
      final bv = index < b.length ? b[index] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  Future<void> deleteWorkout(String id) async {
    workouts.removeWhere((w) => w.id == id);
    installedBucketWorkouts.removeWhere((item) => item.workoutId == id);
    workoutMusic.remove(id);
    await store.saveWorkouts(workouts);
    await store.saveWorkoutMusic(workoutMusic);
    await store.saveInstalledBucketWorkouts(installedBucketWorkouts);
    await yamlFileStore?.delete(id);
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
      createdAt: workout.updatedAt,
    );
  }

  Future<void> assignCoachRecording(CoachRecording recording) async {
    final workout = byId(recording.workoutId);
    if (workout == null) return;
    final draft = WorkoutDraft.fromWorkout(workout);
    final cueName = recording.scope == 'description'
        ? '${workout.name} introduction'
        : recording.stepKey == null
        ? 'recording'
        : _draftStepAt(draft.steps, recording.stepKey!)?.name ?? 'recording';
    final originalPath = recording.audioPath;
    final readablePath = await recordingFiles.renameForCue(
      originalPath,
      cueName,
    );
    final source = portableAudioSource(readablePath);
    if (recording.scope == 'description') {
      draft.recording = source;
    } else if (recording.stepKey != null) {
      final step = _draftStepAt(draft.steps, recording.stepKey!);
      if (step == null) return;
      step.recording = source;
      step.hasExplicitId = true;
    }
    try {
      await saveWorkout(_parseDraft(draft, workout));
    } catch (_) {
      if (readablePath != originalPath && await File(readablePath).exists()) {
        await File(readablePath).rename(originalPath);
      }
      rethrow;
    }
  }

  Future<CoachRecording?> removeCoachRecording({
    required String workoutId,
    required String scope,
    String? stepKey,
  }) async {
    final removed = coachRecordingFor(
      workoutId: workoutId,
      scope: scope,
      stepKey: stepKey,
    );
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
      duckingMode: music.ducking,
    );
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
    musicTracks.add(
      MusicTrack(
        id: 'personal-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        mood: 'Custom',
        source: imported.path,
        bundled: false,
        createdAt: DateTime.now(),
      ),
    );
    await store.saveMusicTracks(musicTracks);
    notifyListeners();
    return true;
  }

  Future<void> _refreshGeneratedMusicNames(
    List<MusicTrack> personalTracks,
  ) async {
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
    await yamlFileStore?.replaceAll(workouts);
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
