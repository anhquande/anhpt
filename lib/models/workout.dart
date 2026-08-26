sealed class WorkoutNode {
  const WorkoutNode();
  Map<String, dynamic> toJson();
}

class WorkoutStep extends WorkoutNode {
  final String name;
  final Duration duration;
  final String? guide;
  final bool countdown;

  const WorkoutStep({
    required this.name,
    required this.duration,
    this.guide,
    this.countdown = true,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'step',
        'name': name,
        'durationMs': duration.inMilliseconds,
        'guide': guide,
        'countdown': countdown,
      };

  static WorkoutStep fromJson(Map<String, dynamic> j) => WorkoutStep(
        name: j['name'] as String,
        duration: Duration(milliseconds: j['durationMs'] as int),
        guide: j['guide'] as String?,
        countdown: j['countdown'] as bool? ?? true,
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
  final RepeatContext? repeat;

  const ExecutableStep({
    required this.step,
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
            .map((e) => workoutNodeFromJson(Map<String, dynamic>.from(e as Map)))
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
  final List<WorkoutNode> steps;
  final String rawYaml;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  const Workout({required this.id, required this.version, required this.name, required this.description, required this.tags, required this.startCountdown, required this.voice, required this.sound, required this.haptic, required this.ducking, required this.steps, required this.rawYaml, required this.favorite, required this.createdAt, required this.updatedAt, this.lastUsedAt});

  Duration get totalDuration => _sum(steps);
  int get effectiveStepCount => _count(steps);

  List<ExecutableStep> expand() {
    final result = <ExecutableStep>[];
    bool containsNestedRepeat(RepeatGroup group) => group.steps.any((node) => node is RepeatGroup);

    void walk(List<WorkoutNode> nodes, {RepeatContext? activeRepeat}) {
      for (final node in nodes) {
        if (node is WorkoutStep) {
          result.add(ExecutableStep(step: node, repeat: activeRepeat));
          if (activeRepeat != null && activeRepeat.isFirstStepOfRound) {
            activeRepeat = RepeatContext(index: activeRepeat.index, total: activeRepeat.total, isFirstStepOfRound: false);
          }
        }
        if (node is RepeatGroup) {
          final hasNested = containsNestedRepeat(node);
          for (var round = 1; round <= node.repeat; round++) {
            final context = hasNested ? null : RepeatContext(index: round, total: node.repeat, isFirstStepOfRound: true);
            walk(node.steps, activeRepeat: context);
          }
        }
      }
    }

    walk(steps);
    return result;
  }

  Workout copyWith({bool? favorite, DateTime? updatedAt, DateTime? lastUsedAt}) => Workout(
        id: id, version: version, name: name, description: description, tags: tags,
        startCountdown: startCountdown, voice: voice, sound: sound, haptic: haptic,
        ducking: ducking, steps: steps, rawYaml: rawYaml,
        favorite: favorite ?? this.favorite, createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt, lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'version': version, 'name': name, 'description': description,
        'tags': tags, 'startCountdownMs': startCountdown.inMilliseconds,
        'voice': voice.toJson(), 'sound': sound, 'haptic': haptic, 'ducking': ducking,
        'steps': steps.map((e) => e.toJson()).toList(), 'rawYaml': rawYaml,
        'favorite': favorite, 'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(), 'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  static Workout fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String, version: j['version'] as int, name: j['name'] as String,
        description: j['description'] as String, tags: (j['tags'] as List).cast<String>(),
        startCountdown: Duration(milliseconds: j['startCountdownMs'] as int),
        voice: VoiceConfig.fromJson(Map<String, dynamic>.from(j['voice'] as Map)),
        sound: j['sound'] as String, haptic: j['haptic'] as String, ducking: j['ducking'] as String,
        steps: (j['steps'] as List).map((e) => workoutNodeFromJson(Map<String, dynamic>.from(e as Map))).toList(),
        rawYaml: j['rawYaml'] as String, favorite: j['favorite'] as bool,
        createdAt: DateTime.parse(j['createdAt'] as String), updatedAt: DateTime.parse(j['updatedAt'] as String),
        lastUsedAt: j['lastUsedAt'] == null ? null : DateTime.parse(j['lastUsedAt'] as String),
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
