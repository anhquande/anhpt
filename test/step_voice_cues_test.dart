import 'package:flutter_test/flutter_test.dart';

import 'package:anhpt/core/session_engine.dart';
import 'package:anhpt/models/workout.dart';
import 'package:anhpt/models/workout_draft.dart';
import 'package:anhpt/services/workout_parser.dart';
import 'package:anhpt/services/workout_serializer.dart';

void main() {
  const baseYaml = '''
version: 2
name: Coach cues
start_countdown: 0s
voice:
  language: en
  timing:
    elapsed_time: false
    interval: false
    final_countdown: false
steps:
  - name: Plank
    duration: 30s
    voice_cues:
      announce_next: true
      get_ready: true
      countdown: true
      halfway: true
      remaining_time: 7
      completion: true
  - name: Rest
    duration: 10s
''';

  test('parser reads per-step voice cues and leaves omitted cues disabled', () {
    final workout = WorkoutParser.parse(
      baseYaml,
      id: 'coach-cues',
      defaultVoiceLanguage: 'en',
    );

    final first = workout.steps.first as WorkoutStep;
    final second = workout.steps[1] as WorkoutStep;

    expect(first.voiceCues.announceNext, isTrue);
    expect(first.voiceCues.getReady, isTrue);
    expect(first.voiceCues.startCountdown, isTrue);
    expect(first.voiceCues.halfway, isTrue);
    expect(first.voiceCues.remainingTimeSeconds, 7);
    expect(first.voiceCues.completion, isTrue);
    expect(first.voiceCues.hasPreStartCue, isTrue);

    expect(second.voiceCues.hasAny, isFalse);
    expect(second.voiceCues.remainingTimeSeconds, 0);
  });

  test('remaining_time accepts zero and rejects negative or non-integer values', () {
    final zero = baseYaml.replaceFirst('remaining_time: 7', 'remaining_time: 0');
    final parsed = WorkoutParser.parse(
      zero,
      id: 'remaining-zero',
      defaultVoiceLanguage: 'en',
    );
    expect(
      (parsed.steps.first as WorkoutStep).voiceCues.remainingTimeSeconds,
      0,
    );

    expect(
      () => WorkoutParser.parse(
        baseYaml.replaceFirst('remaining_time: 7', 'remaining_time: -1'),
        id: 'remaining-negative',
        defaultVoiceLanguage: 'en',
      ),
      throwsA(isA<WorkoutValidationException>()),
    );
    expect(
      () => WorkoutParser.parse(
        baseYaml.replaceFirst('remaining_time: 7', 'remaining_time: 7.5'),
        id: 'remaining-float',
        defaultVoiceLanguage: 'en',
      ),
      throwsA(isA<WorkoutValidationException>()),
    );
  });

  test('draft serializer round-trips voice cues', () {
    final workout = WorkoutParser.parse(
      baseYaml,
      id: 'round-trip',
      defaultVoiceLanguage: 'en',
    );
    final yaml = WorkoutSerializer.toYaml(WorkoutDraft.fromWorkout(workout));

    expect(yaml, contains('voice_cues:'));
    expect(yaml, contains('announce_next: true'));
    expect(yaml, contains('get_ready: true'));
    expect(yaml, contains('countdown: true'));
    expect(yaml, contains('halfway: true'));
    expect(yaml, contains('remaining_time: 7'));
    expect(yaml, contains('completion: true'));

    final reparsed = WorkoutParser.parse(
      yaml,
      id: 'round-trip-2',
      defaultVoiceLanguage: 'en',
    );
    final cues = (reparsed.steps.first as WorkoutStep).voiceCues;
    expect(cues.remainingTimeSeconds, 7);
    expect(cues.completion, isTrue);
  });

  test('pre-start cues hold the timer until protected announcement completes', () {
    final workout = WorkoutParser.parse(
      baseYaml,
      id: 'pre-start',
      defaultVoiceLanguage: 'en',
    );
    final engine = SessionEngine(workout);
    addTearDown(engine.dispose);

    engine.start();
    expect(engine.status, SessionStatus.running);
    expect(engine.stepTimerStarted, isFalse);
    expect(engine.remaining, const Duration(seconds: 30));

    engine.completeAnnouncement();
    expect(engine.announcementComplete, isTrue);
    expect(engine.stepTimerStarted, isTrue);
  });

  test('completion cue gates transition until Voice Coach releases it', () {
    final workout = Workout(
      id: 'completion-gate',
      version: 2,
      name: 'Completion gate',
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
      haptic: 'off',
      ducking: 'off',
      steps: const [
        WorkoutStep(
          id: 'instant',
          name: 'Instant',
          duration: Duration.zero,
          voiceCues: StepVoiceCues(completion: true),
        ),
        WorkoutStep(
          id: 'next',
          name: 'Next',
          duration: Duration(seconds: 1),
        ),
      ],
      rawYaml: '',
      favorite: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final engine = SessionEngine(workout);
    addTearDown(engine.dispose);

    engine.start();
    expect(engine.timerFinished, isTrue);
    engine.completeAnnouncement();

    expect(engine.stepIndex, 0);
    expect(engine.waitingForTransitionCue, isTrue);

    engine.completeTransitionCue();
    expect(engine.stepIndex, 1);
  });
}
