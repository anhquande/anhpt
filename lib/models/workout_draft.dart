import 'workout.dart';

sealed class WorkoutDraftNode {
  WorkoutDraftNode clone();
}

class StepDraft extends WorkoutDraftNode {
  String id;
  bool hasExplicitId;
  String name;
  String duration;
  String guide;
  bool countdown;
  String recording;
  String exerciseId;

  StepDraft({
    this.id = '',
    this.hasExplicitId = false,
    this.name = 'New Step',
    this.duration = '30s',
    this.guide = '',
    this.countdown = true,
    this.recording = '',
    this.exerciseId = '',
  });

  @override
  StepDraft clone() => StepDraft(
        id: '',
        hasExplicitId: false,
        name: name,
        duration: duration,
        guide: guide,
        countdown: countdown,
        recording: '',
        exerciseId: exerciseId,
      );
}

class RepeatDraft extends WorkoutDraftNode {
  int repeat;
  final List<WorkoutDraftNode> steps;

  RepeatDraft({this.repeat = 2, List<WorkoutDraftNode>? steps})
      : steps = steps ?? <WorkoutDraftNode>[];

  @override
  RepeatDraft clone() => RepeatDraft(
        repeat: repeat,
        steps: steps.map((e) => e.clone()).toList(),
      );
}

class WorkoutDraft {
  String name;
  String description;
  List<String> tags;
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
  String completionAction;
  String recording;
  String backgroundMusicSource;
  String backgroundMusicName;
  bool backgroundMusicEnabled;
  double backgroundMusicVolume;
  String backgroundMusicDucking;
  final List<WorkoutDraftNode> steps;
  final List<Exercise> exercises;

  WorkoutDraft({
    this.name = 'New Workout',
    this.description = '',
    List<String>? tags,
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
    this.completionAction = 'none',
    this.recording = '',
    this.backgroundMusicSource = '',
    this.backgroundMusicName = '',
    this.backgroundMusicEnabled = true,
    this.backgroundMusicVolume = .35,
    this.backgroundMusicDucking = 'gentle',
    List<WorkoutDraftNode>? steps,
    List<Exercise>? exercises,
  })  : tags = tags ?? <String>[],
        steps = steps ?? <WorkoutDraftNode>[],
        exercises = exercises ?? <Exercise>[];

  factory WorkoutDraft.fromWorkout(Workout workout) => WorkoutDraft(
        name: workout.name,
        description: workout.description,
        tags: List<String>.from(workout.tags),
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
        completionAction: workout.completionAction,
        recording: workout.recording ?? '',
        backgroundMusicSource: workout.backgroundMusic?.source ?? '',
        backgroundMusicName: workout.backgroundMusic?.name ?? '',
        backgroundMusicEnabled: workout.backgroundMusic?.enabled ?? true,
        backgroundMusicVolume: workout.backgroundMusic?.volume ?? .35,
        backgroundMusicDucking: workout.backgroundMusic?.ducking ?? 'gentle',
        steps: workout.steps.map(_node).toList(),
        exercises: List<Exercise>.from(workout.exercises),
      );

  static WorkoutDraftNode _node(WorkoutNode node) {
    if (node is WorkoutStep) {
      return StepDraft(
        id: node.id,
        hasExplicitId: node.hasExplicitId,
        name: node.name,
        duration:
            node.duration == Duration.zero ? '' : _duration(node.duration),
        guide: node.guide ?? '',
        countdown: node.countdown,
        recording: node.recording ?? '',
        exerciseId: node.exerciseId ?? '',
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
