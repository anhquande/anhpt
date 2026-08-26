import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/workout.dart';

enum SessionStatus {
  preparing,
  announcing,
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

  SessionEngine(this.workout)
      : status = workout.startCountdown > Duration.zero
            ? SessionStatus.preparing
            : SessionStatus.announcing {
    _steps = workout.expand();
    if (_steps.isEmpty) {
      throw StateError('Workout must contain at least one executable step.');
    }
  }

  ExecutableStep get currentExecutableStep => _steps[stepIndex];
  WorkoutStep get currentStep => currentExecutableStep.step;
  RepeatContext? get currentRepeat => currentExecutableStep.repeat;

  WorkoutStep? get nextStep {
    final nextIndex = stepIndex + 1;
    return nextIndex < _steps.length ? _steps[nextIndex].step : null;
  }

  int get totalEffectiveSteps => _steps.length;

  Duration get activeElapsed =>
      _activeElapsedBefore +
      (status == SessionStatus.running ? _activeWatch.elapsed : Duration.zero);

  Duration get stepElapsed =>
      _stepElapsedBefore +
      (status == SessionStatus.running ? _stepWatch.elapsed : Duration.zero);

  Duration get remaining {
    if (status == SessionStatus.preparing) {
      final r = workout.startCountdown - _prepareWatch.elapsed;
      return r.isNegative ? Duration.zero : r;
    }
    if (status == SessionStatus.announcing) {
      return currentStep.duration;
    }
    final r = currentStep.duration - stepElapsed;
    return r.isNegative ? Duration.zero : r;
  }

  double get progress {
    final totalMs = workout.totalDuration.inMilliseconds;
    if (totalMs <= 0) {
      return status == SessionStatus.completed ? 1.0 : 0.0;
    }
    return (activeElapsed.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void start() {
    if (_ticker != null) return;

    if (status == SessionStatus.preparing) {
      _prepareWatch.start();
    } else if (status == SessionStatus.announcing) {
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
        status = SessionStatus.announcing;
      }
      notifyListeners();
      return;
    }

    if (status != SessionStatus.running) return;

    if (stepElapsed >= currentStep.duration) {
      _activeElapsedBefore += currentStep.duration;
      _activeWatch
        ..stop()
        ..reset();
      _stepWatch
        ..stop()
        ..reset();
      _stepElapsedBefore = Duration.zero;

      if (stepIndex + 1 >= _steps.length) {
        _completeWorkout();
        return;
      }

      stepIndex++;
      status = SessionStatus.announcing;
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  /// Called by VoiceGuideController after the current step's
  /// name + guide announcement has fully finished.
  void completeAnnouncement() {
    if (status != SessionStatus.announcing) return;

    if (currentStep.duration <= Duration.zero) {
      if (stepIndex + 1 >= _steps.length) {
        _completeWorkout();
        return;
      }
      stepIndex++;
      status = SessionStatus.announcing;
      notifyListeners();
      return;
    }

    _stepElapsedBefore = Duration.zero;
    _activeWatch
      ..reset()
      ..start();
    _stepWatch
      ..reset()
      ..start();
    status = SessionStatus.running;
    notifyListeners();
  }

  void _completeWorkout() {
    _activeElapsedBefore = workout.totalDuration;
    _activeWatch.stop();
    _stepWatch.stop();
    status = SessionStatus.completed;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  void pause() {
    if (status != SessionStatus.running) return;

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
    _activeWatch.start();
    _stepWatch.start();
    notifyListeners();
  }

  void endEarly() {
    if (status == SessionStatus.completed || status == SessionStatus.incomplete) {
      return;
    }

    if (status == SessionStatus.running) {
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
    super.dispose();
  }
}
