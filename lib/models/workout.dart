sealed class WorkoutNode {
  const WorkoutNode();
  Map<String, dynamic> toJson();
}

class Exercise {
  final String id;
  final String name;
  final String? demoMediaId;

  const Exercise({required this.id, required this.name, this.demoMediaId});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'demoMediaId': demoMediaId,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        demoMediaId:
            json['demoMediaId'] as String? ?? json['demoVideoId'] as String?,
      );
}

class WorkoutStep extends WorkoutNode {
  final String id;
  final bool hasExplicitId;
  final String name;
  final Duration duration;
  final String? guide;
  final bool countdown;
  final String? recording;
  final String? exerciseId;

  const WorkoutStep({
    required this.id,
    this.hasExplicitId = false,
    required this.name,
    required this.duration,
    this.guide,
    this.countdown = true,
    this.recording,
    this.exerciseId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'step',
        'id': id,
        'hasExplicitId': hasExplicitId,
        'name': name,
        'durationMs': duration.inMilliseconds,
        'guide': guide,
        'countdown': countdown,
        'recording': recording,
        'exerciseId': exerciseId,
      };

  static WorkoutStep fromJson(Map<String, dynamic> j) => WorkoutStep(
        id: j['id'] as String? ?? '',
        hasExplicitId: j['hasExplicitId'] as bool? ?? false,
        name: j['name'] as String,
        duration: Duration(milliseconds: j['durationMs'] as int),
        guide: j['guide'] as String?,
        countdown: j['countdown'] as bool? ?? true,
        recording: j['recording'] as String?,
        exerciseId: j['exerciseId'] as String?,
      );
}

class BackgroundMusicConfig {
  final String source;
  final String? name;
  final bool enabled;
  final double volume;
  final String ducking;

  const BackgroundMusicConfig({
    required this.source,
    this.name,
    this.enabled = true,
    this.volume = .35,
    this.ducking = 'gentle',
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'name': name,
        'enabled': enabled,
        'volume': volume,
        'ducking': ducking,
      };

  static BackgroundMusicConfig fromJson(Map<String, dynamic> json) =>
      BackgroundMusicConfig(
        source: json['source'] as String,
        name: json['name'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        volume: (json['volume'] as num?)?.toDouble() ?? .35,
        ducking: json['ducking'] as String? ?? 'gentle',
      );
}

class RepeatContext {
  final int index;
  final int total;
  final bool isFirstStepOfRound;

  const RepeatContext({
    required this.index,
    required this.total,
    required this.isFirstStepOfRound,
  });
}

class ExecutableStep {
  final WorkoutStep step;
  final String stepKey;
  final RepeatContext? repeat;

  const ExecutableStep({
    required this.step,
    required this.stepKey,
    this.repeat,
  });
}

class RepeatGroup extends WorkoutNode {
  final int repeat;
  final List<WorkoutNode> steps;
  const RepeatGroup({required this.repeat, required this.steps});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'repeat',
        'repeat': repeat,
        'steps': steps.map((e) => e.toJson()).toList(),
      };

  static RepeatGroup fromJson(Map<String, dynamic> j) => RepeatGroup(
        repeat: j['repeat'] as int,
        steps: (j['steps'] as List)
            .map(
                (e) => workoutNodeFromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

WorkoutNode workoutNodeFromJson(Map<String, dynamic> j) {
  return switch (j['type']) {
    'step' => WorkoutStep.fromJson(j),
    'repeat' => RepeatGroup.fromJson(j),
    _ => throw FormatException('Unknown node type: ${j['type']}'),
  };
}

class VoiceConfig {
  final String language;
  final String mode;
  final Duration announceEvery;
  final Duration countdownFrom;
  final bool announceStepName;
  final bool announceStart;
  final bool announceFinish;

  const VoiceConfig({
    required this.language,
    required this.mode,
    required this.announceEvery,
    required this.countdownFrom,
    required this.announceStepName,
    required this.announceStart,
    required this.announceFinish,
  });

  Map<String, dynamic> toJson() => {
        'language': language,
        'mode': mode,
        'announceEveryMs': announceEvery.inMilliseconds,
        'countdownFromMs': countdownFrom.inMilliseconds,
        'announceStepName': announceStepName,
        'announceStart': announceStart,
        'announceFinish': announceFinish,
      };

  static VoiceConfig fromJson(Map<String, dynamic> j) => VoiceConfig(
        language: j['language'] as String,
        mode: j['mode'] as String,
        announceEvery: Duration(milliseconds: j['announceEveryMs'] as int),
        countdownFrom: Duration(milliseconds: j['countdownFromMs'] as int),
        announceStepName: j['announceStepName'] as bool,
        announceStart: j['announceStart'] as bool,
        announceFinish: j['announceFinish'] as bool,
      );
}

class Workout {
  final String id;
  final int version;
  final String name;
  final String description;
  final List<String> tags;
  final Duration startCountdown;
  final VoiceConfig voice;
  final String sound;
  final String haptic;
  final String ducking;
  final String completionAction;
  final Duration? screenOffAfterStart;
  final String? recording;
  final BackgroundMusicConfig? backgroundMusic;
  final List<Exercise> exercises;
  final List<WorkoutNode> steps;
  final String rawYaml;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  const Workout(
      {required this.id,
      required this.version,
      required this.name,
      required this.description,
      required this.tags,
      required this.startCountdown,
      required this.voice,
      required this.sound,
      required this.haptic,
      required this.ducking,
      this.completionAction = 'none',
      this.screenOffAfterStart,
      this.recording,
      this.backgroundMusic,
      this.exercises = const [],
      required this.steps,
      required this.rawYaml,
      required this.favorite,
      required this.createdAt,
      required this.updatedAt,
      this.lastUsedAt});

  Duration get totalDuration => _sum(steps);
  int get effectiveStepCount => _count(steps);

  List<ExecutableStep> expand() {
    final result = <ExecutableStep>[];
    bool containsNestedRepeat(RepeatGroup group) =>
        group.steps.any((node) => node is RepeatGroup);

    void walk(List<WorkoutNode> nodes,
        {RepeatContext? activeRepeat, String path = ''}) {
      for (var nodeIndex = 0; nodeIndex < nodes.length; nodeIndex++) {
        final node = nodes[nodeIndex];
        final nodePath = path.isEmpty ? '$nodeIndex' : '$path.$nodeIndex';
        if (node is WorkoutStep) {
          result.add(ExecutableStep(
              step: node, stepKey: nodePath, repeat: activeRepeat));
          if (activeRepeat != null && activeRepeat.isFirstStepOfRound) {
            activeRepeat = RepeatContext(
                index: activeRepeat.index,
                total: activeRepeat.total,
                isFirstStepOfRound: false);
          }
        }
        if (node is RepeatGroup) {
          final hasNested = containsNestedRepeat(node);
          for (var round = 1; round <= node.repeat; round++) {
            final context = hasNested
                ? null
                : RepeatContext(
                    index: round, total: node.repeat, isFirstStepOfRound: true);
            walk(node.steps, activeRepeat: context, path: nodePath);
          }
        }
      }
    }

    walk(steps);
    return result;
  }

  Workout copyWith({
    bool? favorite,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    String? recording,
    bool clearRecording = false,
    BackgroundMusicConfig? backgroundMusic,
    bool clearBackgroundMusic = false,
    List<WorkoutNode>? steps,
    List<Exercise>? exercises,
    String? rawYaml,
    int? version,
    Duration? screenOffAfterStart,
    bool clearScreenOffAfterStart = false,
  }) =>
      Workout(
        id: id,
        version: version ?? this.version,
        name: name,
        description: description,
        tags: tags,
        startCountdown: startCountdown,
        voice: voice,
        sound: sound,
        haptic: haptic,
        ducking: ducking,
        completionAction: completionAction,
        screenOffAfterStart: clearScreenOffAfterStart
            ? null
            : screenOffAfterStart ?? this.screenOffAfterStart,
        recording: clearRecording ? null : recording ?? this.recording,
        backgroundMusic: clearBackgroundMusic
            ? null
            : backgroundMusic ?? this.backgroundMusic,
        exercises: exercises ?? this.exercises,
        steps: steps ?? this.steps,
        rawYaml: rawYaml ?? this.rawYaml,
        favorite: favorite ?? this.favorite,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'name': name,
        'description': description,
        'tags': tags,
        'startCountdownMs': startCountdown.inMilliseconds,
        'voice': voice.toJson(),
        'sound': sound,
        'haptic': haptic,
        'ducking': ducking,
        'completionAction': completionAction,
        'screenOffAfterStartMs': screenOffAfterStart?.inMilliseconds,
        'recording': recording,
        'backgroundMusic': backgroundMusic?.toJson(),
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        'rawYaml': rawYaml,
        'favorite': favorite,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  static Workout fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String,
        version: j['version'] as int,
        name: j['name'] as String,
        description: j['description'] as String,
        tags: (j['tags'] as List).cast<String>(),
        startCountdown: Duration(milliseconds: j['startCountdownMs'] as int),
        voice:
            VoiceConfig.fromJson(Map<String, dynamic>.from(j['voice'] as Map)),
        sound: j['sound'] as String,
        haptic: j['haptic'] as String,
        ducking: j['ducking'] as String,
        completionAction: j['completionAction'] as String? ?? 'none',
        screenOffAfterStart: j['screenOffAfterStartMs'] == null
            ? null
            : Duration(milliseconds: j['screenOffAfterStartMs'] as int),
        recording: j['recording'] as String?,
        backgroundMusic: j['backgroundMusic'] == null
            ? null
            : BackgroundMusicConfig.fromJson(
                Map<String, dynamic>.from(j['backgroundMusic'] as Map)),
        exercises: (j['exercises'] as List? ?? const [])
            .map((value) =>
                Exercise.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList(),
        steps: (j['steps'] as List)
            .map(
                (e) => workoutNodeFromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rawYaml: j['rawYaml'] as String,
        favorite: j['favorite'] as bool,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        lastUsedAt: j['lastUsedAt'] == null
            ? null
            : DateTime.parse(j['lastUsedAt'] as String),
      );

  static Duration _sum(List<WorkoutNode> nodes) {
    var total = Duration.zero;
    for (final n in nodes) {
      if (n is WorkoutStep) total += n.duration;
      if (n is RepeatGroup) total += _sum(n.steps) * n.repeat;
    }
    return total;
  }

  static int _count(List<WorkoutNode> nodes) {
    var total = 0;
    for (final n in nodes) {
      if (n is WorkoutStep) total += 1;
      if (n is RepeatGroup) total += _count(n.steps) * n.repeat;
    }
    return total;
  }
}
