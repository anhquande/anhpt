import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/workout.dart';

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

  SessionEngine(this.workout)
      : status = workout.startCountdown > Duration.zero
            ? SessionStatus.preparing
            : SessionStatus.running {
    _steps = workout.expand();

    if (_steps.isEmpty) {
      throw StateError(
        'Workout must contain at least one executable step.',
      );
    }
  }

  /// Current executable item including repeat context.
  ExecutableStep get currentExecutableStep => _steps[stepIndex];

  /// Current real workout step.
  ///
  /// UI and voice code should normally use this getter.
  WorkoutStep get currentStep => currentExecutableStep.step;

  /// Repeat context for the current step.
  ///
  /// Null means the current step is not inside an
  /// announceable inner repeat.
  RepeatContext? get currentRepeat => currentExecutableStep.repeat;

  /// Next real workout step, if any.
  WorkoutStep? get nextStep {
    final nextIndex = stepIndex + 1;

    if (nextIndex >= _steps.length) {
      return null;
    }

    return _steps[nextIndex].step;
  }

  int get totalEffectiveSteps => _steps.length;

  Duration get activeElapsed {
    return _activeElapsedBefore +
        (status == SessionStatus.running
            ? _activeWatch.elapsed
            : Duration.zero);
  }

  Duration get stepElapsed {
    return _stepElapsedBefore +
        (status == SessionStatus.running ? _stepWatch.elapsed : Duration.zero);
  }

  Duration get remaining {
    if (status == SessionStatus.preparing) {
      final remaining = workout.startCountdown - _prepareWatch.elapsed;

      return remaining.isNegative ? Duration.zero : remaining;
    }

    final remaining = currentStep.duration - stepElapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get progress {
    final totalMs = workout.totalDuration.inMilliseconds;

    if (totalMs <= 0) {
      return 0;
    }

    return (activeElapsed.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void start() {
    if (_ticker != null) {
      return;
    }

    if (status == SessionStatus.preparing) {
      _prepareWatch.start();
    } else if (status == SessionStatus.running) {
      _activeWatch.start();
      _stepWatch.start();
    }

    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _evaluate(),
    );
  }

  void _evaluate() {
    if (status == SessionStatus.preparing) {
      _evaluatePreparing();
      return;
    }

    if (status != SessionStatus.running) {
      return;
    }

    _evaluateRunning();
  }

  void _evaluatePreparing() {
    if (_prepareWatch.elapsed >= workout.startCountdown) {
      _prepareWatch.stop();

      status = SessionStatus.running;

      _activeWatch
        ..reset()
        ..start();

      _stepWatch
        ..reset()
        ..start();

      _stepElapsedBefore = Duration.zero;
    }

    notifyListeners();
  }

  void _evaluateRunning() {
    /*
     * Using while instead of if is intentional.
     *
     * If the UI/thread stalls for a moment and more than
     * one step has theoretically passed, the engine can
     * catch up rather than becoming permanently delayed.
     */
    while (stepElapsed >= currentStep.duration) {
      final overflow = stepElapsed - currentStep.duration;

      _activeElapsedBefore += currentStep.duration;

      _activeWatch
        ..reset()
        ..start();

      final isLastStep = stepIndex + 1 >= _steps.length;

      if (isLastStep) {
        _completeWorkout();
        return;
      }

      stepIndex++;

      /*
       * Preserve timing overflow when a scheduler tick
       * occurs slightly after the exact step boundary.
       */
      _stepElapsedBefore = overflow;

      _stepWatch
        ..reset()
        ..start();
    }

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
    if (status != SessionStatus.running) {
      return;
    }

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
    if (status != SessionStatus.paused) {
      return;
    }

    status = SessionStatus.running;

    _activeWatch.start();
    _stepWatch.start();

    notifyListeners();
  }

  void endEarly() {
    if (status == SessionStatus.completed ||
        status == SessionStatus.incomplete) {
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
