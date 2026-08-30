import 'dart:async';

import '../core/session_engine.dart';
import '../models/workout.dart';
import 'audio_feedback_service.dart';

class VoiceGuideController {
  final Workout workout;
  final SessionEngine engine;
  final AudioFeedbackService audio;
  final String? descriptionRecordingPath;
  final Map<String, String> stepRecordingPaths;

  SessionStatus? _lastStatus;
  int _lastStepIndex = -1;
  int? _lastSpokenSecond;
  bool _started = false;
  bool _finished = false;
  bool _processing = false;
  bool _pending = false;
  bool _muted = false;
  int _generation = 0;
  bool _disposed = false;

  VoiceGuideController({
    required this.workout,
    required this.engine,
    required this.audio,
    this.descriptionRecordingPath,
    this.stepRecordingPaths = const {},
  });

  bool get muted => _muted;

  Future<void> initialize() async {
    await audio.configure(workout);
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed || _muted == muted) return;

    _muted = muted;
    _generation++;
    _lastSpokenSecond = null;

    if (muted) {
      await audio.cancelCurrentAudio();
      if (!_disposed &&
          engine.status == SessionStatus.running &&
          !engine.announcementComplete) {
        engine.completeAnnouncement();
      }
    }
  }

  Future<void> onEngineChanged() async {
    if (_disposed) return;
    if (_processing) {
      _pending = true;
      return;
    }

    _processing = true;
    try {
      do {
        _pending = false;
        await _processCurrentState();
      } while (_pending);
    } finally {
      _processing = false;
    }
  }

  Future<void> _processCurrentState() async {
    if (_disposed) return;
    final status = engine.status;
    final previousStatus = _lastStatus;
    _lastStatus = status;

    if (!_muted &&
        previousStatus == SessionStatus.running &&
        status == SessionStatus.paused) {
      await audio.stopSpeech();
      await audio.speak(audio.pausedPhrase(), interrupt: true);
    }

    if (!_muted &&
        previousStatus == SessionStatus.paused &&
        status == SessionStatus.running) {
      await audio.speak(
        audio.resumePhrase(engine.currentStep.name),
        interrupt: true,
      );
    }

    // A new step starts its timer immediately. In parallel we speak
    // the step name + guide. The engine advances only after both
    // the timer and this announcement have finished.
    if (status == SessionStatus.running && _lastStepIndex != engine.stepIndex) {
      _lastStepIndex = engine.stepIndex;
      _lastSpokenSecond = null;

      if (_muted) {
        await audio.playCue(workout.sound);
        if (!_disposed &&
            engine.status == SessionStatus.running &&
            !engine.announcementComplete) {
          engine.completeAnnouncement();
        }
        return;
      }

      final announcementGeneration = _generation;
      final announcementStepIndex = engine.stepIndex;
      final announcementStepId = engine.currentExecutableStep.step.id;

      try {
        if (!_started) {
          _started = true;
          if (workout.voice.announceStart) {
            final description = workout.description.trim();
            final recordingPlayed = descriptionRecordingPath != null &&
                await audio
                    .playLocalRecordingAndWait(descriptionRecordingPath!);
            if (!recordingPlayed) {
              final introParts = <String>[audio.startPhrase(workout.name)];
              if (description.isNotEmpty) {
                introParts.add(description);
              }
              await audio.speakAndWait(
                introParts.join('. '),
                interrupt: true,
              );
            }
          }
        }

        if (!_isCurrentAnnouncement(
          announcementGeneration,
          announcementStepIndex,
          announcementStepId,
        )) {
          return;
        }

        await audio.stopSpeech();
        await audio.playCue(workout.sound);
        if (!_isCurrentAnnouncement(
          announcementGeneration,
          announcementStepIndex,
          announcementStepId,
        )) {
          return;
        }

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

        final stepRecordingPath =
            stepRecordingPaths[engine.currentExecutableStep.step.id];
        final recordingPlayed = stepRecordingPath != null &&
            await audio.playLocalRecordingAndWait(stepRecordingPath);
        if (!_isCurrentAnnouncement(
          announcementGeneration,
          announcementStepIndex,
          announcementStepId,
        )) {
          return;
        }
        if (!recordingPlayed && parts.isNotEmpty) {
          await audio.speakAndWait(
            parts.join('. '),
            interrupt: true,
          );
        }
      } catch (e) {
        // Voice failure must never block progression permanently.
        // ignore: avoid_print
        print('Step announcement failed: $e');
      } finally {
        if (_isCurrentAnnouncement(
          announcementGeneration,
          announcementStepIndex,
          announcementStepId,
        )) {
          engine.completeAnnouncement();
        }
      }
      return;
    }

    // Timing voice starts only after the step announcement is finished,
    // so interval/final-countdown speech cannot cut off name/guide speech.
    if (!_muted &&
        status == SessionStatus.running &&
        engine.announcementComplete) {
      await _handleTimingVoice();
    }

    if (status == SessionStatus.completed && !_finished) {
      _finished = true;
      await audio.stopSpeech();
      await audio.playCue(workout.sound);
      if (!_muted && workout.voice.announceFinish) {
        await audio.speak(audio.finishPhrase(), interrupt: true);
      }
    }

    if (status == SessionStatus.incomplete) {
      await audio.stopSpeech();
    }
  }

  bool _isCurrentAnnouncement(
    int generation,
    int stepIndex,
    String stepId,
  ) {
    return !_disposed &&
        !_muted &&
        generation == _generation &&
        (engine.status == SessionStatus.running ||
            engine.status == SessionStatus.paused) &&
        engine.stepIndex == stepIndex &&
        engine.currentExecutableStep.step.id == stepId;
  }

  /// Invalidates awaited callbacks immediately. A paused step is replayed on
  /// resume so its announcement can never be inherited from stale work.
  Future<void> cancelCurrentWork({bool replayCurrentStep = false}) async {
    if (_disposed) return;
    _generation++;
    if (replayCurrentStep) {
      _lastStepIndex = -1;
      _lastSpokenSecond = null;
    }
    await audio.cancelCurrentAudio();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _pending = false;
    unawaited(audio.cancelCurrentAudio());
  }

  Future<void> _handleTimingVoice() async {
    if (!engine.currentStep.countdown) return;
    if (engine.timerFinished) return;

    const speechLeadMs = 200;
    final remainingMs = engine.remaining.inMilliseconds;
    final durationMs = engine.currentStep.duration.inMilliseconds;

    if (remainingMs <= 0) return;

    final adjustedRemainingMs = remainingMs - speechLeadMs;
    final remainingSec =
        adjustedRemainingMs <= 0 ? 0 : ((adjustedRemainingMs - 1) ~/ 1000) + 1;

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
