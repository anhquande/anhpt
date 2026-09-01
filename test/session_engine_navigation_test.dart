import 'package:flutter_test/flutter_test.dart';

import 'package:anhpt/core/session_engine.dart';
import 'package:anhpt/models/workout.dart';

void main() {
  Workout workoutWith(List<WorkoutNode> steps) => Workout(
        id: 'navigation-test',
        version: 1,
        name: 'Navigation test',
        description: '',
        tags: const [],
        startCountdown: Duration.zero,
        voice: const VoiceConfig(
          language: 'en',
          announceElapsedTime: false,
          announceInterval: false,
          announceFinalCountdown: false,
          announceEvery: Duration.zero,
          countdownFrom: Duration.zero,
          announceStepName: false,
          announceStart: false,
          announceFinish: false,
        ),
        sound: 'none',
        haptic: 'none',
        ducking: 'off',
        steps: steps,
        rawYaml: '',
        favorite: false,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  const first = WorkoutStep(
    id: 'first',
    name: 'First',
    duration: Duration(seconds: 10),
  );
  const second = WorkoutStep(
    id: 'second',
    name: 'Second',
    duration: Duration(seconds: 20),
  );
  const third = WorkoutStep(
    id: 'third',
    name: 'Third',
    duration: Duration(seconds: 30),
  );

  int workoutPositionMs(SessionEngine engine) =>
      engine.workoutPositionElapsed.inMilliseconds;

  test('manual navigation moves one resolved step and updates timeline progress', () {
    final engine = SessionEngine(workoutWith(const [first, second, third]));
    addTearDown(engine.dispose);

    expect(engine.stepIndex, 0);
    expect(engine.previousStep, isNull);
    expect(engine.nextStep?.id, 'second');
    expect(workoutPositionMs(engine), 0);
    expect(engine.progress, 0);

    expect(engine.goToNextStep(), isTrue);
    expect(engine.stepIndex, 1);
    expect(engine.currentStep.id, 'second');
    expect(engine.previousStep?.id, 'first');
    expect(workoutPositionMs(engine), 10000);
    expect(engine.progress, closeTo(1 / 6, 0.0001));

    expect(engine.goToPreviousStep(), isTrue);
    expect(engine.stepIndex, 0);
    expect(workoutPositionMs(engine), 0);
    expect(engine.goToPreviousStep(), isFalse);
  });

  test('manual navigation follows expanded repeat order', () {
    final engine = SessionEngine(
      workoutWith(const [
        RepeatGroup(repeat: 2, steps: [first, second]),
        third,
      ]),
    );
    addTearDown(engine.dispose);

    expect(engine.totalEffectiveSteps, 5);
    expect(engine.currentStep.id, 'first');

    expect(engine.goToNextStep(), isTrue);
    expect(engine.currentStep.id, 'second');
    expect(workoutPositionMs(engine), 10000);

    expect(engine.goToNextStep(), isTrue);
    expect(engine.currentStep.id, 'first');
    expect(workoutPositionMs(engine), 30000);

    expect(engine.goToNextStep(), isTrue);
    expect(engine.currentStep.id, 'second');
    expect(workoutPositionMs(engine), 40000);

    expect(engine.goToNextStep(), isTrue);
    expect(engine.currentStep.id, 'third');
    expect(workoutPositionMs(engine), 60000);
    expect(engine.goToNextStep(), isFalse);
  });

  test('navigation is disabled while preparing', () {
    final workout = workoutWith(const [first, second]).copyWith();
    final preparingWorkout = Workout(
      id: workout.id,
      version: workout.version,
      name: workout.name,
      description: workout.description,
      tags: workout.tags,
      startCountdown: const Duration(seconds: 3),
      voice: workout.voice,
      sound: workout.sound,
      haptic: workout.haptic,
      ducking: workout.ducking,
      completionAction: workout.completionAction,
      exercises: workout.exercises,
      steps: workout.steps,
      rawYaml: workout.rawYaml,
      favorite: workout.favorite,
      createdAt: workout.createdAt,
      updatedAt: workout.updatedAt,
    );
    final engine = SessionEngine(preparingWorkout);
    addTearDown(engine.dispose);

    expect(engine.status, SessionStatus.preparing);
    expect(engine.goToNextStep(), isFalse);
    expect(engine.stepIndex, 0);
  });
}
