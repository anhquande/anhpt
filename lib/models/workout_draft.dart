import 'workout.dart';

sealed class WorkoutDraftNode {
  WorkoutDraftNode clone();
}

class StepDraft extends WorkoutDraftNode {
  String name;
  String duration;
  String guide;

  StepDraft({
    this.name = 'New Step',
    this.duration = '30s',
    this.guide = '',
  });

  @override
  StepDraft clone() => StepDraft(
        name: name,
        duration: duration,
        guide: guide,
      );
}

class RepeatDraft extends WorkoutDraftNode {
  int repeat;
  final List<WorkoutDraftNode> steps;

  RepeatDraft({
    this.repeat = 2,
    List<WorkoutDraftNode>? steps,
  }) : steps = steps ?? <WorkoutDraftNode>[];

  @override
  RepeatDraft clone() => RepeatDraft(
        repeat: repeat,
        steps: steps.map((e) => e.clone()).toList(),
      );
}

class WorkoutDraft {
  String name;
  String description;
  String startCountdown;
  String voiceLanguage;
  String voiceMode;
  String announceEvery;
  String countdownFrom;
  bool announceStepName;
  bool announceStart;
  bool announceFinish;
  String sound;
  String haptic;
  String ducking;
  final List<WorkoutDraftNode> steps;

  WorkoutDraft({
    this.name = 'New Workout',
    this.description = '',
    this.startCountdown = '3s',
    this.voiceLanguage = 'vi',
    this.voiceMode = 'combined',
    this.announceEvery = '10s',
    this.countdownFrom = '5s',
    this.announceStepName = true,
    this.announceStart = true,
    this.announceFinish = true,
    this.sound = 'beep',
    this.haptic = 'medium',
    this.ducking = 'medium',
    List<WorkoutDraftNode>? steps,
  }) : steps = steps ?? <WorkoutDraftNode>[];

  factory WorkoutDraft.fromWorkout(Workout workout) => WorkoutDraft(
        name: workout.name,
        description: workout.description,
        startCountdown: _duration(workout.startCountdown),
        voiceLanguage: workout.voice.language,
        voiceMode: workout.voice.mode,
        announceEvery: _duration(workout.voice.announceEvery),
        countdownFrom: _duration(workout.voice.countdownFrom),
        announceStepName: workout.voice.announceStepName,
        announceStart: workout.voice.announceStart,
        announceFinish: workout.voice.announceFinish,
        sound: workout.sound,
        haptic: workout.haptic,
        ducking: workout.ducking,
        steps: workout.steps.map(_node).toList(),
      );

  static WorkoutDraftNode _node(WorkoutNode node) {
    if (node is WorkoutStep) {
      return StepDraft(
        name: node.name,
        duration: _duration(node.duration),
        guide: node.guide ?? '',
      );
    }

    final repeat = node as RepeatGroup;
    return RepeatDraft(
      repeat: repeat.repeat,
      steps: repeat.steps.map(_node).toList(),
    );
  }

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final buffer = StringBuffer();
    if (hours > 0) buffer.write('${hours}h');
    if (minutes > 0) buffer.write('${minutes}m');
    if (seconds > 0 || buffer.isEmpty) buffer.write('${seconds}s');
    return buffer.toString();
  }
}
