import 'dart:math';

import 'package:yaml/yaml.dart';

import '../core/duration_parser.dart';
import '../models/workout.dart';

class WorkoutValidationException implements Exception {
  final String message;
  const WorkoutValidationException(this.message);
  @override
  String toString() => message;
}

class WorkoutParser {
  static const _rootFields = {
    'version',
    'name',
    'description',
    'tags',
    'start_countdown',
    'voice',
    'feedback',
    'audio',
    'completion_action',
    'screen_off_after_start',
    'recording',
    'background_music',
    'exercises',
    'steps',
  };
  static const _voiceFields = {
    'language',
    'timing',
    'announce_step_name',
    'announce_start',
    'announce_finish',
  };
  static const _voiceTimingFields = {
    'elapsed_time',
    'interval',
    'interval_every',
    'final_countdown',
    'countdown_from',
  };
  static const _feedbackFields = {'sound', 'haptic'};
  static const _audioFields = {'ducking'};
  static const _stepFields = {
    'id',
    'name',
    'duration',
    'guide',
    'countdown',
    'recording',
    'exercise_id',
  };
  static const _repeatFields = {'repeat', 'steps'};
  static const _backgroundMusicFields = {
    'source',
    'name',
    'enabled',
    'volume',
    'ducking',
  };
  static const _exerciseFields = {'id', 'name', 'demo_media', 'demo_video'};

  static Workout parse(
    String yamlText, {
    required String id,
    required String defaultVoiceLanguage,
    bool favorite = false,
    DateTime? createdAt,
  }) {
    dynamic loaded;
    try {
      loaded = loadYaml(yamlText);
    } on YamlException catch (e) {
      throw WorkoutValidationException('YAML syntax error: ${e.message}');
    }
    if (loaded is! YamlMap) {
      throw const WorkoutValidationException('YAML root must be an object.');
    }
    final root = _map(loaded);
    _unknown(root, _rootFields, 'root');
    final version = root['version'];
    if (version != 1 && version != 2) {
      throw const WorkoutValidationException(
        'version is required and must be 1 or 2.',
      );
    }

    final name = _string(root['name'], 'name', 100);
    final description = root['description'] == null
        ? ''
        : _string(root['description'], 'description', 500, allowEmpty: true);
    final tags = _tags(root['tags']);
    final startCountdown = root['start_countdown'] == null
        ? const Duration(seconds: 3)
        : DurationParser.parseAllowZero(
            root['start_countdown'],
            field: 'start_countdown',
          );
    final voice = _voice(root['voice'], defaultVoiceLanguage);
    final (sound, haptic) = _feedback(root['feedback']);
    final ducking = _audio(root['audio']);
    final completionAction = (root['completion_action'] ?? 'none').toString();
    if (!{'none', 'shutdown_or_exit'}.contains(completionAction)) {
      throw const WorkoutValidationException(
        'completion_action must be none or shutdown_or_exit.',
      );
    }
    final screenOffAfterStart = root['screen_off_after_start'] == null
        ? null
        : DurationParser.parseAllowZero(
            root['screen_off_after_start'],
            field: 'screen_off_after_start',
          );
    if (screenOffAfterStart != null && screenOffAfterStart <= Duration.zero) {
      throw const WorkoutValidationException(
        'screen_off_after_start must be greater than 0s.',
      );
    }
    final recording = _recording(root['recording'], 'recording');
    final backgroundMusic = _backgroundMusic(root['background_music']);
    final exercises = _exercises(root['exercises']);

    final rawSteps = root['steps'];
    if (rawSteps is! YamlList || rawSteps.isEmpty) {
      throw const WorkoutValidationException(
        'Workout must contain at least one step.',
      );
    }
    final explicitIds = <String>{};
    _collectExplicitIds(rawSteps, explicitIds, 0);
    final steps = _nodes(rawSteps, 0, _StepIdAllocator(explicitIds));
    final exerciseIds = exercises.map((exercise) => exercise.id).toSet();
    void validateExerciseReferences(List<WorkoutNode> nodes) {
      for (final node in nodes) {
        if (node is WorkoutStep &&
            node.exerciseId != null &&
            !exerciseIds.contains(node.exerciseId)) {
          throw WorkoutValidationException(
            'Unknown exercise_id "${node.exerciseId}".',
          );
        }
        if (node is RepeatGroup) validateExerciseReferences(node.steps);
      }
    }

    validateExerciseReferences(steps);
    final now = DateTime.now();
    final workout = Workout(
      id: id,
      version: version as int,
      name: name,
      description: description,
      tags: tags,
      startCountdown: startCountdown,
      voice: voice,
      sound: sound,
      haptic: haptic,
      ducking: ducking,
      completionAction: completionAction,
      screenOffAfterStart: screenOffAfterStart,
      recording: recording,
      backgroundMusic: backgroundMusic,
      exercises: exercises,
      steps: steps,
      rawYaml: yamlText,
      favorite: favorite,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
    if (workout.totalDuration > const Duration(hours: 24)) {
      throw const WorkoutValidationException(
        'Total workout duration must not exceed 24 hours.',
      );
    }
    if (workout.effectiveStepCount > 100000) {
      throw const WorkoutValidationException(
        'Workout must not exceed 100,000 effective steps.',
      );
    }
    return workout;
  }

  static VoiceConfig _voice(Object? value, String defaultLanguage) {
    final map = value == null ? <String, dynamic>{} : _map(value);
    _unknown(map, _voiceFields, 'voice');
    final language = (map['language'] ?? defaultLanguage).toString();
    if (!{'vi', 'en'}.contains(language)) {
      throw const WorkoutValidationException(
        'voice.language must be vi or en.',
      );
    }

    final timing = map['timing'] == null
        ? <String, dynamic>{}
        : _map(map['timing']);
    _unknown(timing, _voiceTimingFields, 'voice.timing');
    final announceElapsedTime = _bool(
      timing['elapsed_time'],
      false,
      'voice.timing.elapsed_time',
    );
    final announceInterval = _bool(
      timing['interval'],
      true,
      'voice.timing.interval',
    );
    final announceFinalCountdown = _bool(
      timing['final_countdown'],
      true,
      'voice.timing.final_countdown',
    );
    final announceEvery = timing['interval_every'] == null
        ? const Duration(seconds: 10)
        : DurationParser.parse(
            timing['interval_every'],
            field: 'voice.timing.interval_every',
          );
    final countdownFrom = timing['countdown_from'] == null
        ? const Duration(seconds: 5)
        : DurationParser.parse(
            timing['countdown_from'],
            field: 'voice.timing.countdown_from',
          );

    return VoiceConfig(
      language: language,
      announceElapsedTime: announceElapsedTime,
      announceInterval: announceInterval,
      announceFinalCountdown: announceFinalCountdown,
      announceEvery: announceEvery,
      countdownFrom: countdownFrom,
      announceStepName: _bool(
        map['announce_step_name'],
        true,
        'voice.announce_step_name',
      ),
      announceStart: _bool(map['announce_start'], true, 'voice.announce_start'),
      announceFinish: _bool(
        map['announce_finish'],
        true,
        'voice.announce_finish',
      ),
    );
  }

  static (String, String) _feedback(Object? value) {
    final map = value == null ? <String, dynamic>{} : _map(value);
    _unknown(map, _feedbackFields, 'feedback');
    final sound = (map['sound'] ?? 'beep').toString();
    final haptic = (map['haptic'] ?? 'medium').toString();
    if (!{'beep', 'bell', 'click', 'none'}.contains(sound)) {
      throw const WorkoutValidationException(
        'feedback.sound must be beep, bell, click or none.',
      );
    }
    if (!{'off', 'light', 'medium', 'strong'}.contains(haptic)) {
      throw const WorkoutValidationException(
        'feedback.haptic must be off, light, medium or strong.',
      );
    }
    return (sound, haptic);
  }

  static String _audio(Object? value) {
    final map = value == null ? <String, dynamic>{} : _map(value);
    _unknown(map, _audioFields, 'audio');
    final ducking = (map['ducking'] ?? 'medium').toString();
    if (!{'off', 'low', 'medium', 'high'}.contains(ducking)) {
      throw const WorkoutValidationException(
        'audio.ducking must be off, low, medium or high.',
      );
    }
    return ducking;
  }

  static String? _recording(Object? value, String field) {
    if (value == null) return null;
    final source = _string(value, field, 500);
    _validateSource(source, field);
    return source;
  }

  static BackgroundMusicConfig? _backgroundMusic(Object? value) {
    if (value == null) return null;
    final map = _map(value);
    _unknown(map, _backgroundMusicFields, 'background_music');
    final source = _string(map['source'], 'background_music.source', 500);
    _validateSource(source, 'background_music.source');
    final name = map['name'] == null
        ? null
        : _string(map['name'], 'background_music.name', 100);
    final enabled = _bool(map['enabled'], true, 'background_music.enabled');
    final volumeValue = map['volume'] ?? .35;
    if (volumeValue is! num || volumeValue < 0 || volumeValue > 1) {
      throw const WorkoutValidationException(
        'background_music.volume must be a number from 0 to 1.',
      );
    }
    final ducking = (map['ducking'] ?? 'gentle').toString();
    if (!{'off', 'gentle', 'medium', 'high', 'very_high'}.contains(ducking)) {
      throw const WorkoutValidationException(
        'background_music.ducking must be off, gentle, medium, high or very_high.',
      );
    }
    return BackgroundMusicConfig(
      source: source,
      name: name,
      enabled: enabled,
      volume: volumeValue.toDouble(),
      ducking: ducking,
    );
  }

  static void _validateSource(String source, String field) {
    final normalized = source.replaceAll('\\', '/');
    final isAsset = normalized.startsWith('asset:');
    if (!isAsset &&
        (RegExp(r'^[A-Za-z]:/').hasMatch(normalized) ||
            normalized.startsWith('/') ||
            normalized.split('/').contains('..'))) {
      throw WorkoutValidationException(
        '$field must be an asset: reference or a safe relative path.',
      );
    }
  }

  static List<WorkoutNode> _nodes(
    YamlList list,
    int depth,
    _StepIdAllocator ids,
  ) {
    if (depth > 10) {
      throw const WorkoutValidationException(
        'Maximum repeat nesting depth is 10.',
      );
    }
    final out = <WorkoutNode>[];
    for (final item in list) {
      if (item is! YamlMap) {
        throw const WorkoutValidationException('Each step must be an object.');
      }
      final map = _map(item);
      if (map.containsKey('repeat')) {
        _unknown(map, _repeatFields, 'repeat step');
        final repeat = map['repeat'];
        if (repeat is! int || repeat < 1 || repeat > 10000) {
          throw const WorkoutValidationException(
            'repeat must be an integer from 1 to 10,000.',
          );
        }
        final children = map['steps'];
        if (children is! YamlList || children.isEmpty) {
          throw const WorkoutValidationException(
            'Repeat group steps must not be empty.',
          );
        }
        out.add(
          RepeatGroup(repeat: repeat, steps: _nodes(children, depth + 1, ids)),
        );
      } else {
        _unknown(map, _stepFields, 'timed step');
        final name = _string(map['name'], 'step.name', 100);
        final duration = map['duration'] == null
            ? Duration.zero
            : DurationParser.parseAllowZero(
                map['duration'],
                field: 'step.duration',
              );
        final guide = map['guide'] == null
            ? null
            : _string(map['guide'], 'step.guide', 500);
        final countdown = _bool(map['countdown'], true, 'step.countdown');
        final explicitId = map['id'] == null ? null : _stepId(map['id']);
        final recording = _recording(map['recording'], 'step.recording');
        final exerciseId = map['exercise_id'] == null
            ? null
            : _logicalId(map['exercise_id'], 'step.exercise_id');
        out.add(
          WorkoutStep(
            id: ids.allocate(name, explicitId),
            hasExplicitId: explicitId != null,
            name: name,
            duration: duration,
            guide: guide,
            countdown: countdown,
            recording: recording,
            exerciseId: exerciseId,
          ),
        );
      }
    }
    return out;
  }

  static void _collectExplicitIds(YamlList list, Set<String> ids, int depth) {
    if (depth > 10) {
      throw const WorkoutValidationException(
        'Maximum repeat nesting depth is 10.',
      );
    }
    for (final item in list) {
      if (item is! YamlMap) continue;
      final map = _map(item);
      if (map.containsKey('repeat')) {
        final children = map['steps'];
        if (children is YamlList) _collectExplicitIds(children, ids, depth + 1);
      } else if (map['id'] != null) {
        final id = _stepId(map['id']);
        if (!ids.add(id.toLowerCase())) {
          throw WorkoutValidationException('Duplicate explicit step.id "$id".');
        }
      }
    }
  }

  static String _stepId(Object? value) {
    final id = _string(value, 'step.id', 40);
    if (!RegExp(r'^[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*$').hasMatch(id)) {
      throw const WorkoutValidationException(
        'step.id must contain only letters, numbers and single hyphens.',
      );
    }
    return id;
  }

  static String _logicalId(Object? value, String field) {
    final id = _string(value, field, 80);
    if (!RegExp(r'^[a-zA-Z0-9]+(?:[-_][a-zA-Z0-9]+)*$').hasMatch(id)) {
      throw WorkoutValidationException(
        '$field must contain letters, numbers, hyphens or underscores.',
      );
    }
    return id;
  }

  static List<Exercise> _exercises(Object? value) {
    if (value == null) return const [];
    if (value is! YamlList) {
      throw const WorkoutValidationException('exercises must be a list.');
    }
    final result = <Exercise>[];
    final ids = <String>{};
    for (final item in value) {
      final map = _map(item);
      _unknown(map, _exerciseFields, 'exercise');
      final id = _logicalId(map['id'], 'exercise.id');
      if (!ids.add(id)) {
        throw WorkoutValidationException('Duplicate exercise.id "$id".');
      }
      if (map['demo_media'] != null && map['demo_video'] != null) {
        throw const WorkoutValidationException(
          'exercise must not contain both demo_media and demo_video.',
        );
      }
      final rawDemoMedia = map['demo_media'] ?? map['demo_video'];
      final demoMedia = rawDemoMedia == null
          ? null
          : _mediaReference(rawDemoMedia, 'exercise.demo_media');
      result.add(
        Exercise(
          id: id,
          name: _string(map['name'], 'exercise.name', 100),
          demoMediaId: demoMedia,
        ),
      );
    }
    return result;
  }

  static String _mediaReference(Object? value, String field) {
    final reference = _string(value, field, 500);
    if (reference.startsWith('sha256:')) {
      if (!RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(reference)) {
        throw WorkoutValidationException(
          '$field contains an invalid SHA-256 ID.',
        );
      }
      return reference.toLowerCase();
    }
    _validateSource(reference, field);
    return reference.replaceAll('\\', '/');
  }

  static List<String> _tags(Object? value) {
    if (value == null) return const [];
    if (value is! YamlList) {
      throw const WorkoutValidationException('tags must be a list.');
    }
    if (value.length > 20) {
      throw const WorkoutValidationException('Maximum 20 tags.');
    }
    return value.map((e) => _string(e, 'tag', 30)).toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! YamlMap) {
      throw const WorkoutValidationException('Expected an object/map.');
    }
    return {for (final e in value.entries) e.key.toString(): e.value};
  }

  static void _unknown(
    Map<String, dynamic> map,
    Set<String> allowed,
    String context,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw WorkoutValidationException('Unknown field "$key" in $context.');
      }
    }
  }

  static String _string(
    Object? value,
    String field,
    int max, {
    bool allowEmpty = false,
  }) {
    if (value is! String) {
      throw WorkoutValidationException('$field must be a string.');
    }
    final trimmed = value.trim();
    if (!allowEmpty && trimmed.isEmpty) {
      throw WorkoutValidationException('$field must not be empty.');
    }
    if (trimmed.length > max) {
      throw WorkoutValidationException(
        '$field must be at most $max characters.',
      );
    }
    return value;
  }

  static bool _bool(Object? value, bool fallback, String field) {
    if (value == null) return fallback;
    if (value is! bool) {
      throw WorkoutValidationException('$field must be true or false.');
    }
    return value;
  }

  static String slugifyStepName(String name) {
    const accents =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const plain =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var value = name.toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      value = value.replaceAll(accents[i], plain[i]);
    }
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    value = value.replaceAll(RegExp(r'^-+|-+$'), '');
    if (value.isEmpty) value = 'step';
    if (value.length > 40) {
      value = value.substring(0, 40).replaceFirst(RegExp(r'-+$'), '');
    }
    return value.isEmpty ? 'step' : value;
  }

  static String generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomA = Random().nextInt(1 << 30);
    final randomB = Random().nextInt(1 << 30);
    return '${now.toRadixString(16)}-${randomA.toRadixString(16)}-${randomB.toRadixString(16)}';
  }
}

class _StepIdAllocator {
  final Set<String> reserved;
  final Set<String> used = {};
  _StepIdAllocator(this.reserved);

  String allocate(String name, String? explicit) {
    if (explicit != null) {
      used.add(explicit.toLowerCase());
      return explicit;
    }
    final base = WorkoutParser.slugifyStepName(name);
    var candidate = base;
    var suffix = 2;
    while (reserved.contains(candidate.toLowerCase()) ||
        used.contains(candidate.toLowerCase())) {
      candidate = '$base-${suffix++}';
    }
    used.add(candidate.toLowerCase());
    return candidate;
  }
}
