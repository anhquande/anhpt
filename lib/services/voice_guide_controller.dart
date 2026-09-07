import 'dart:async';

import '../core/session_engine.dart';
import '../models/workout.dart';
import 'audio_feedback_service.dart';

class VoiceGuideController {
  static const _coachCueMinSpacingMs = 3500;
  static const _announceNextLeadSeconds = 5;
  static const _minimumAnnounceNextDurationSeconds = 12;
  static const _minimumHalfwayDurationMs = 8000;

  final Workout workout;
  final SessionEngine engine;
  final AudioFeedbackService audio;
  final String? descriptionRecordingPath;
  final Map<String, String> stepRecordingPaths;

  SessionStatus? _lastStatus;
  int _lastStepIndex = -1;
  int _cueStepIndex = -1;
  int? _lastSpokenSecond;
  int? _lastTimedSpeechElapsedMs;
  bool _lastTimedSpeechWasCustom = false;
  bool _halfwaySpoken = false;
  bool _remainingTimeSpoken = false;
  bool _nextSpoken = false;
  bool _completionSpoken = false;
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
      if (!_disposed && engine.waitingForTransitionCue) {
        engine.completeTransitionCue();
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

    if (status == SessionStatus.running && _cueStepIndex != engine.stepIndex) {
      _cueStepIndex = engine.stepIndex;
      _resetStepCueState();
    }

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

    // A new step normally starts its timer immediately while the protected
    // step announcement plays. If get-ready/start-countdown is enabled, the
    // engine intentionally holds the timer until this announcement finishes.
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
            final recordingPlayed =
                descriptionRecordingPath != null &&
                await audio.playLocalRecordingAndWait(
                  descriptionRecordingPath!,
                );
            if (!recordingPlayed) {
              final introParts = <String>[audio.startPhrase(workout.name)];
              if (description.isNotEmpty) {
                introParts.add(description);
              }
              await audio.speakAndWait(introParts.join('. '), interrupt: true);
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
        final recordingPlayed =
            stepRecordingPath != null &&
            await audio.playLocalRecordingAndWait(stepRecordingPath);
        if (!_isCurrentAnnouncement(
          announcementGeneration,
          announcementStepIndex,
          announcementStepId,
        )) {
          return;
        }
        if (!recordingPlayed && parts.isNotEmpty) {
          await audio.speakAndWait(parts.join('. '), interrupt: true);
        }

        if (!_isCurrentAnnouncement(
          announcementGeneration,
          announcementStepIndex,
          announcementStepId,
        )) {
          return;
        }

        // Pre-start cues are only played before the timer begins. A paused
        // step that is replayed on resume already has a running timer and must
        // not receive another get-ready/countdown sequence.
        if (!engine.stepTimerStarted &&
            step.duration > Duration.zero &&
            step.voiceCues.hasPreStartCue) {
          final preStartParts = <String>[];
          if (step.voiceCues.getReady) {
            preStartParts.add(audio.getReadyPhrase());
          }
          if (step.voiceCues.startCountdown) {
            preStartParts.add(audio.startCountdownPhrase());
          }
          if (preStartParts.isNotEmpty) {
            await audio.speakAndWait(
              preStartParts.join('. '),
              interrupt: true,
            );
          }
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

    if (_muted && engine.waitingForTransitionCue) {
      engine.completeTransitionCue();
      return;
    }

    // Timing voice starts only after the protected announcement is finished.
    if (!_muted &&
        status == SessionStatus.running &&
        engine.announcementComplete &&
        !engine.timerFinished) {
      await _handleTimingVoice();
    }

    if (status == SessionStatus.running && engine.waitingForTransitionCue) {
      await _handleCompletionCue();
      return;
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

  void _resetStepCueState() {
    _halfwaySpoken = false;
    _remainingTimeSpoken = false;
    _nextSpoken = false;
    _completionSpoken = false;
    _lastTimedSpeechElapsedMs = null;
    _lastTimedSpeechWasCustom = false;
  }

  bool _isCurrentAnnouncement(int generation, int stepIndex, String stepId) {
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

  Future<void> _handleCompletionCue() async {
    if (_completionSpoken || !engine.currentStep.voiceCues.completion) {
      if (engine.waitingForTransitionCue) engine.completeTransitionCue();
      return;
    }

    _completionSpoken = true;
    final generation = _generation;
    final stepIndex = engine.stepIndex;
    final stepId = engine.currentStep.id;
    final elapsedMs = engine.currentStep.duration.inMilliseconds;

    try {
      // The final workout already has its own finish phrase. On intermediate
      // steps, suppress a completion word if another timed cue was spoken too
      // recently, rather than stacking TTS back-to-back.
      if (!_muted &&
          engine.nextStep != null &&
          _canSpeakCustomCue(elapsedMs)) {
        _markTimedSpeech(elapsedMs, custom: true);
        await audio.speakAndWait(audio.stepCompletePhrase(), interrupt: true);
      }
    } catch (_) {
      // Completion speech is optional; transition must always be released.
    } finally {
      if (!_disposed &&
          generation == _generation &&
          engine.status == SessionStatus.running &&
          engine.stepIndex == stepIndex &&
          engine.currentStep.id == stepId &&
          engine.waitingForTransitionCue) {
        engine.completeTransitionCue();
      }
    }
  }

  bool _canSpeakCustomCue(int elapsedMs) {
    final previous = _lastTimedSpeechElapsedMs;
    return previous == null || elapsedMs - previous >= _coachCueMinSpacingMs;
  }

  bool _legacyTimingBlockedByCustomCue(int elapsedMs) {
    final previous = _lastTimedSpeechElapsedMs;
    return _lastTimedSpeechWasCustom &&
        previous != null &&
        elapsedMs - previous < _coachCueMinSpacingMs;
  }

  void _markTimedSpeech(int elapsedMs, {required bool custom}) {
    _lastTimedSpeechElapsedMs = elapsedMs;
    _lastTimedSpeechWasCustom = custom;
  }

  Future<void> _handleTimingVoice() async {
    if (engine.timerFinished || !engine.stepTimerStarted) return;

    const speechLeadMs = 200;
    final step = engine.currentStep;
    final cues = step.voiceCues;
    final remainingMs = engine.remaining.inMilliseconds;
    final durationMs = step.duration.inMilliseconds;

    if (remainingMs <= 0) return;

    final adjustedRemainingMs = remainingMs - speechLeadMs;
    final remainingSec = adjustedRemainingMs <= 0
        ? 0
        : ((adjustedRemainingMs - 1) ~/ 1000) + 1;

    final elapsedMs = durationMs - remainingMs + speechLeadMs;
    final elapsedSec = elapsedMs <= 0 ? 0 : elapsedMs ~/ 1000;

    final configuredRemaining = cues.remainingTimeSeconds;
    if (!_remainingTimeSpoken &&
        configuredRemaining > 0 &&
        configuredRemaining < step.duration.inSeconds &&
        remainingSec <= configuredRemaining) {
      _remainingTimeSpoken = true;
      if (_canSpeakCustomCue(elapsedMs)) {
        _markTimedSpeech(elapsedMs, custom: true);
        await audio.speak(
          audio.remainingPhrase(configuredRemaining),
          interrupt: true,
        );
        return;
      }
    }

    if (!_nextSpoken &&
        cues.announceNext &&
        engine.nextStep != null &&
        step.duration.inSeconds >= _minimumAnnounceNextDurationSeconds &&
        remainingSec <= _announceNextLeadSeconds) {
      _nextSpoken = true;
      if (_canSpeakCustomCue(elapsedMs)) {
        _markTimedSpeech(elapsedMs, custom: true);
        await audio.speak(
          audio.nextPhrase(engine.nextStep!.name),
          interrupt: true,
        );
        return;
      }
    }

    if (!_halfwaySpoken &&
        cues.halfway &&
        durationMs >= _minimumHalfwayDurationMs &&
        elapsedMs >= durationMs ~/ 2) {
      _halfwaySpoken = true;
      if (_canSpeakCustomCue(elapsedMs)) {
        _markTimedSpeech(elapsedMs, custom: true);
        await audio.speak(audio.halfwayPhrase(), interrupt: true);
        return;
      }
    }

    // Legacy timing remains supported per existing workout configuration.
    if (!step.countdown) return;
    if (_lastSpokenSecond == remainingSec) return;
    if (_legacyTimingBlockedByCustomCue(elapsedMs)) return;

    final countdownFrom = workout.voice.countdownFrom.inSeconds;
    final interval = workout.voice.announceEvery.inSeconds;
    final inEnding = remainingSec > 0 && remainingSec <= countdownFrom;

    if (workout.voice.announceFinalCountdown && inEnding) {
      _lastSpokenSecond = remainingSec;
      _markTimedSpeech(elapsedMs, custom: false);
      await audio.speak('$remainingSec', interrupt: true);
      return;
    }

    if (workout.voice.announceInterval &&
        remainingSec > 0 &&
        interval > 0 &&
        remainingSec < step.duration.inSeconds &&
        remainingSec % interval == 0) {
      _lastSpokenSecond = remainingSec;
      _markTimedSpeech(elapsedMs, custom: false);
      await audio.speak(audio.remainingPhrase(remainingSec));
      return;
    }

    if (workout.voice.announceElapsedTime && elapsedSec > 0) {
      final spokenElapsedKey = -elapsedSec;
      if (_lastSpokenSecond != spokenElapsedKey) {
        _lastSpokenSecond = spokenElapsedKey;
        _markTimedSpeech(elapsedMs, custom: false);
        await audio.speak('$elapsedSec', interrupt: true);
      }
    }
  }
}
