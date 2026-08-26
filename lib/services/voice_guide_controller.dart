import '../core/session_engine.dart';
import '../models/workout.dart';
import 'audio_feedback_service.dart';

class VoiceGuideController {
  final Workout workout;
  final SessionEngine engine;
  final AudioFeedbackService audio;

  SessionStatus? _lastStatus;
  int _lastStepIndex = -1;
  int? _lastSpokenSecond;
  bool _started = false;
  bool _finished = false;
  bool _speakingStepGuide = false;

  VoiceGuideController({
    required this.workout,
    required this.engine,
    required this.audio,
  });

  Future<void> initialize() async {
    await audio.configure(workout);
  }

  Future<void> onEngineChanged() async {
    final status = engine.status;

    if (status == SessionStatus.running && !_started) {
      _started = true;
      if (workout.voice.announceStart) {
        await audio.speak(audio.startPhrase(workout.name), interrupt: true);
      }
    }

    if (_lastStatus == SessionStatus.running && status == SessionStatus.paused) {
      await audio.stopSpeech();
      await audio.speak(audio.pausedPhrase(), interrupt: true);
    }

    if (_lastStatus == SessionStatus.paused && status == SessionStatus.running) {
      await audio.speak(
        audio.resumePhrase(engine.currentStep.name),
        interrupt: true,
      );
    }

    if (status == SessionStatus.running && _lastStepIndex != engine.stepIndex) {
      _lastStepIndex = engine.stepIndex;
      _lastSpokenSecond = null;
      _speakingStepGuide = true;

      try {
        await audio.stopSpeech();
        await audio.playCue(workout.sound);

        final step = engine.currentStep;
        final repeat = engine.currentRepeat;
        final guide = step.guide?.trim();
        final parts = <String>[];

        if (workout.voice.announceStepName) {
          if (repeat != null && repeat.isFirstStepOfRound) {
            if (workout.voice.language == 'vi') {
              parts.add('${step.name} lần thứ ${repeat.index}');
            } else {
              parts.add('${step.name}, round ${repeat.index}');
            }
          } else {
            parts.add(step.name);
          }
        }

        if (guide != null && guide.isNotEmpty) {
          parts.add(guide);
        }

        if (parts.isNotEmpty) {
          await audio.speak(parts.join('. '), interrupt: true);
        }
      } finally {
        _speakingStepGuide = false;
      }
    }

    if (status == SessionStatus.running) {
      await _handleTimingVoice();
    }

    if (status == SessionStatus.completed && !_finished) {
      _finished = true;
      await audio.stopSpeech();
      await audio.playCue(workout.sound);
      if (workout.voice.announceFinish) {
        await audio.speak(audio.finishPhrase(), interrupt: true);
      }
    }

    if (status == SessionStatus.incomplete) {
      await audio.stopSpeech();
    }

    _lastStatus = status;
  }

  Future<void> _handleTimingVoice() async {
    // Per-step switch. false disables ALL voice timing for this step,
    // while step name, guide and transition cue still work normally.
    if (!engine.currentStep.countdown) {
      return;
    }

    const speechLeadMs = 200;
    final remainingMs = engine.remaining.inMilliseconds;
    final durationMs = engine.currentStep.duration.inMilliseconds;

    if (remainingMs <= 0) return;

    final adjustedRemainingMs = remainingMs - speechLeadMs;
    final remainingSec = adjustedRemainingMs <= 0
        ? 0
        : ((adjustedRemainingMs - 1) ~/ 1000) + 1;

    final elapsedMs = durationMs - remainingMs + speechLeadMs;
    final elapsedSec = elapsedMs <= 0 ? 0 : elapsedMs ~/ 1000;

    if (_lastSpokenSecond == remainingSec) return;

    final mode = workout.voice.mode;
    final countdownFrom = workout.voice.countdownFrom.inSeconds;
    final interval = workout.voice.announceEvery.inSeconds;
    final inEnding = remainingSec > 0 && remainingSec <= countdownFrom;
    final shouldEnding = (mode == 'ending' || mode == 'combined') && inEnding;

    if (shouldEnding) {
      _lastSpokenSecond = remainingSec;
      await audio.speak('$remainingSec', interrupt: true);
      return;
    }

    if (mode == 'interval' || mode == 'combined') {
      if (remainingSec > 0 &&
          interval > 0 &&
          remainingSec < engine.currentStep.duration.inSeconds &&
          remainingSec % interval == 0) {
        _lastSpokenSecond = remainingSec;
        await audio.speak(audio.remainingPhrase(remainingSec));
      }
      return;
    }

    if (mode == 'continuous' && elapsedSec > 0) {
      final spokenElapsedKey = -elapsedSec;
      if (_lastSpokenSecond != spokenElapsedKey) {
        _lastSpokenSecond = spokenElapsedKey;
        await audio.speak('$elapsedSec', interrupt: true);
      }
    }
  }
}
