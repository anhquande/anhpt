import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/workout.dart';
import '../models/workout_video_settings.dart';

enum SessionStatus {
  preparing,
  running,
  paused,
  completed,
  incomplete,
}

class SessionEngine extends ChangeNotifier {
  final Workout workout;
  late final List<ExecutableStep> _steps;

  SessionStatus status;
  int stepIndex = 0;

  Timer? _ticker;
  final Stopwatch _prepareWatch = Stopwatch();
  final Stopwatch _stepWatch = Stopwatch();
  final Stopwatch _activeWatch = Stopwatch();

  Duration _stepElapsedBefore = Duration.zero;
  Duration _activeElapsedBefore = Duration.zero;

  bool _announcementComplete = false;
  bool _timerFinished = false;

  SessionEngine(this.workout)
      : status = workout.startCountdown > Duration.zero
            ? SessionStatus.preparing
            : SessionStatus.running {
    WorkoutVideoRuntime.current = WorkoutVideoSettings.fromYaml(workout.rawYaml);
    _steps = workout.expand();
    if (_steps.isEmpty) {
      throw StateError('Workout must contain at least one executable step.');
    }
  }

  ExecutableStep get currentExecutableStep => _steps[stepIndex];
  WorkoutStep get currentStep => currentExecutableStep.step;
  RepeatContext? get currentRepeat => currentExecutableStep.repeat;

  WorkoutStep? get previousStep {
    final previousIndex = stepIndex - 1;
    return previousIndex >= 0 ? _steps[previousIndex].step : null;
  }

  WorkoutStep? get nextStep {
    final nextIndex = stepIndex + 1;
    return nextIndex < _steps.length ? _steps[nextIndex].step : null;
  }

  int get totalEffectiveSteps => _steps.length;
  bool get canGoPrevious => stepIndex > 0;
  bool get canGoNext => stepIndex + 1 < _steps.length;

  bool get announcementComplete => _announcementComplete;
  bool get timerFinished => _timerFinished;
  bool get waitingForAnnouncement => _timerFinished && !_announcementComplete;

  Duration get activeElapsed =>
      _activeElapsedBefore +
      (status == SessionStatus.running && !_timerFinished
          ? _activeWatch.elapsed
          : Duration.zero);

  Duration get stepElapsed =>
      _stepElapsedBefore +
      (status == SessionStatus.running && !_timerFinished
          ? _stepWatch.elapsed
          : Duration.zero);

  Duration get workoutPositionElapsed {
    var elapsed = Duration.zero;
    for (var index = 0; index < stepIndex; index++) {
      elapsed += _steps[index].step.duration;
    }
    if (status != SessionStatus.preparing) {
      elapsed += stepElapsed;
    }
    if (elapsed > workout.totalDuration) return workout.totalDuration;
    return elapsed;
  }

  Duration get remaining {
    if (status == SessionStatus.preparing) {
      final r = workout.startCountdown - _prepareWatch.elapsed;
      return r.isNegative ? Duration.zero : r;
    }

    if (_timerFinished) return Duration.zero;

    final r = currentStep.duration - stepElapsed;
    return r.isNegative ? Duration.zero : r;
  }

  double get progress {
    final totalMs = workout.totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      return status == SessionStatus.completed ? 1.0 : 0.0;
    }
    return (workoutPositionElapsed.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void start() {
    if (_ticker != null) return;

    if (status == SessionStatus.preparing) {
      _prepareWatch.start();
    } else if (status == SessionStatus.running) {
      _startCurrentStepTimer();
      notifyListeners();
    }

    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _evaluate(),
    );
  }

  void _evaluate() {
    if (status == SessionStatus.preparing) {
      if (_prepareWatch.elapsed >= workout.startCountdown) {
        _prepareWatch.stop();
        status = SessionStatus.running;
        _startCurrentStepTimer();
      }
      notifyListeners();
      return;
    }

    if (status != SessionStatus.running) return;

    if (!_timerFinished && stepElapsed >= currentStep.duration) {
      _finishCurrentStepTimer();
    }

    if (_timerFinished && _announcementComplete) {
      _advanceOrComplete();
      return;
    }

    notifyListeners();
  }

  void _startCurrentStepTimer() {
    _announcementComplete = false;
    _timerFinished = false;
    _stepElapsedBefore = Duration.zero;

    if (currentStep.duration <= Duration.zero) {
      _timerFinished = true;
      return;
    }

    _activeWatch
      ..reset()
      ..start();
    _stepWatch
      ..reset()
      ..start();
  }

  void _finishCurrentStepTimer() {
    if (_timerFinished) return;

    _timerFinished = true;
    _activeElapsedBefore += _activeWatch.elapsed;
    _stepElapsedBefore = currentStep.duration;

    _activeWatch
      ..stop()
      ..reset();
    _stepWatch
      ..stop()
      ..reset();
  }

  /// Called by VoiceGuideController after the current step's
  /// name + guide announcement has fully finished.
  void completeAnnouncement() {
    if (status == SessionStatus.completed ||
        status == SessionStatus.incomplete) {
      return;
    }

    if (_announcementComplete) return;

    _announcementComplete = true;

    if (_timerFinished && status == SessionStatus.running) {
      _advanceOrComplete();
      return;
    }

    notifyListeners();
  }

  void _advanceOrComplete() {
    if (!_timerFinished || !_announcementComplete) return;

    if (stepIndex + 1 >= _steps.length) {
      _completeWorkout();
      return;
    }

    stepIndex++;
    _startCurrentStepTimer();
    notifyListeners();
  }

  void _completeWorkout() {
    _activeWatch.stop();
    _stepWatch.stop();
    status = SessionStatus.completed;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  bool goToNextStep() => jumpToStep(stepIndex + 1);

  bool goToPreviousStep() => jumpToStep(stepIndex - 1);

  bool jumpToStep(int index) {
    if (status == SessionStatus.preparing ||
        status == SessionStatus.completed ||
        status == SessionStatus.incomplete ||
        index < 0 ||
        index >= _steps.length ||
        index == stepIndex) {
      return false;
    }

    final wasRunning = status == SessionStatus.running;
    final timerWasActive = wasRunning && _ticker != null && !_timerFinished;
    if (timerWasActive) {
      _activeElapsedBefore += _activeWatch.elapsed;
    }

    _activeWatch
      ..stop()
      ..reset();
    _stepWatch
      ..stop()
      ..reset();

    stepIndex = index;
    _announcementComplete = false;
    _stepElapsedBefore = Duration.zero;
    _timerFinished = currentStep.duration <= Duration.zero;

    if (timerWasActive && !_timerFinished) {
      _activeWatch.start();
      _stepWatch.start();
    }

    notifyListeners();
    return true;
  }

  void pause() {
    if (status != SessionStatus.running || _timerFinished) return;

    _activeElapsedBefore += _activeWatch.elapsed;
    _stepElapsedBefore += _stepWatch.elapsed;

    _activeWatch
      ..stop()
      ..reset();
    _stepWatch
      ..stop()
      ..reset();

    status = SessionStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (status != SessionStatus.paused) return;

    status = SessionStatus.running;
    if (!_timerFinished) {
      _activeWatch.start();
      _stepWatch.start();
    }
    notifyListeners();
  }

  void endEarly() {
    if (status == SessionStatus.completed ||
        status == SessionStatus.incomplete) {
      return;
    }

    if (status == SessionStatus.running && !_timerFinished) {
      _activeElapsedBefore += _activeWatch.elapsed;
      _stepElapsedBefore += _stepWatch.elapsed;
    }

    _activeWatch.stop();
    _stepWatch.stop();
    _prepareWatch.stop();
    _ticker?.cancel();
    _ticker = null;
    status = SessionStatus.incomplete;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _prepareWatch.stop();
    _stepWatch.stop();
    _activeWatch.stop();
    WorkoutVideoRuntime.current = null;
    super.dispose();
  }
}
