import 'dart:async';
import 'dart:collection';

import 'body_pose.dart';
import 'pose_estimator.dart';
import 'pose_frame.dart';

/// Runtime configuration for realtime pose processing.
class PosePipelineConfig {
  PosePipelineConfig({this.targetFps = 15.0}) {
    if (!targetFps.isFinite || targetFps <= 0) {
      throw ArgumentError.value(targetFps, 'targetFps', 'Must be finite and > 0.');
    }
  }

  final double targetFps;

  Duration get minimumFrameInterval => Duration(
        microseconds: (Duration.microsecondsPerSecond / targetFps)
            .round()
            .clamp(1, 1 << 31)
            .toInt(),
      );
}

/// Safe frame metadata retained with a pipeline result.
///
/// Raw image planes are deliberately not retained so camera buffers can be
/// released independently of downstream consumers such as PR5's renderer.
class PoseFrameMetadata {
  const PoseFrameMetadata({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.format,
    required this.timestamp,
    required this.isMirrored,
    required this.cameraFacing,
  });

  factory PoseFrameMetadata.fromFrame(PoseFrame frame) => PoseFrameMetadata(
        width: frame.width,
        height: frame.height,
        rotationDegrees: frame.rotationDegrees,
        format: frame.format,
        timestamp: frame.timestamp,
        isMirrored: frame.isMirrored,
        cameraFacing: frame.cameraFacing,
      );

  final int width;
  final int height;
  final int rotationDegrees;
  final PoseFrameFormat format;
  final DateTime timestamp;
  final bool isMirrored;
  final PoseCameraFacing cameraFacing;
}

/// One successful realtime pose inference.
class PosePipelineResult {
  PosePipelineResult({
    required this.frame,
    required List<BodyPose> poses,
    required this.inferenceDuration,
  }) : poses = UnmodifiableListView<BodyPose>(List<BodyPose>.from(poses));

  final PoseFrameMetadata frame;
  final List<BodyPose> poses;
  final Duration inferenceDuration;
}

enum PosePipelineErrorStage { initialization, inference, disposal }

/// A non-fatal error produced by the realtime pose pipeline.
class PosePipelineError {
  const PosePipelineError({
    required this.stage,
    required this.error,
    required this.stackTrace,
    this.frameTimestamp,
  });

  final PosePipelineErrorStage stage;
  final Object error;
  final StackTrace stackTrace;
  final DateTime? frameTimestamp;
}

/// Lightweight aggregate diagnostics for the current pipeline session.
class PosePipelineDiagnostics {
  const PosePipelineDiagnostics({
    required this.processedFrameCount,
    required this.droppedFrameCount,
    required this.failedFrameCount,
    required this.effectivePoseFps,
    this.lastInferenceDuration,
  });

  final int processedFrameCount;
  final int droppedFrameCount;
  final int failedFrameCount;
  final double effectivePoseFps;
  final Duration? lastInferenceDuration;
}

/// Coordinates bounded realtime frame processing for any [PoseEstimator].
///
/// The pipeline never knows which concrete pose engine is behind [estimator].
/// It permits at most one active inference and one pending frame. While an
/// inference is running, newer submissions replace the pending frame so stale
/// work is discarded and latency stays bounded.
class PosePipeline {
  PosePipeline({
    required this.estimator,
    PosePipelineConfig? config,
  }) : config = config ?? PosePipelineConfig();

  final PoseEstimator estimator;
  final PosePipelineConfig config;

  final StreamController<PosePipelineResult> _resultsController =
      StreamController<PosePipelineResult>.broadcast();
  final StreamController<PosePipelineError> _errorsController =
      StreamController<PosePipelineError>.broadcast();

  bool _running = false;
  bool _disposed = false;
  bool _processing = false;
  int _generation = 0;
  Future<void>? _startFuture;
  Future<void>? _processingFuture;
  PoseFrame? _pendingFrame;
  DateTime? _lastInferenceFrameTimestamp;
  DateTime? _firstProcessedTimestamp;
  DateTime? _lastProcessedTimestamp;
  int _processedFrameCount = 0;
  int _droppedFrameCount = 0;
  int _failedFrameCount = 0;
  Duration? _lastInferenceDuration;

  Stream<PosePipelineResult> get results => _resultsController.stream;
  Stream<PosePipelineError> get errors => _errorsController.stream;
  bool get isRunning => _running;
  bool get isDisposed => _disposed;

  PosePipelineDiagnostics get diagnostics => PosePipelineDiagnostics(
        processedFrameCount: _processedFrameCount,
        droppedFrameCount: _droppedFrameCount,
        failedFrameCount: _failedFrameCount,
        effectivePoseFps: _effectivePoseFps,
        lastInferenceDuration: _lastInferenceDuration,
      );

  Future<void> start() {
    if (_disposed) {
      return Future<void>.error(StateError('PosePipeline has been disposed.'));
    }
    if (_running) return Future<void>.value();

    final existingStart = _startFuture;
    if (existingStart != null) return existingStart;

    final generation = ++_generation;
    _resetSessionState();
    late final Future<void> startFuture;
    startFuture = _initializeForStart(generation).whenComplete(() {
      if (identical(_startFuture, startFuture)) {
        _startFuture = null;
      }
    });
    _startFuture = startFuture;
    return startFuture;
  }

  Future<void> _initializeForStart(int generation) async {
    try {
      if (!estimator.isInitialized) {
        await estimator.initialize();
      }
    } catch (error, stackTrace) {
      if (!_disposed && generation == _generation) {
        _emitError(
          PosePipelineError(
            stage: PosePipelineErrorStage.initialization,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
      return;
    }

    if (_disposed || generation != _generation) return;
    _running = true;
  }

  Future<void> stop() async {
    final startFuture = _startFuture;
    if (!_running && !_processing && startFuture == null) {
      _pendingFrame = null;
      return;
    }

    _running = false;
    ++_generation;
    if (_pendingFrame != null) {
      _droppedFrameCount++;
      _pendingFrame = null;
    }

    if (startFuture != null) {
      await startFuture;
    }

    final processing = _processingFuture;
    if (processing != null) {
      await processing;
    }
  }

  /// Submits one camera frame without allowing an unbounded work queue.
  ///
  /// Submissions while inference is busy replace the single pending frame.
  /// Frames that arrive sooner than [PosePipelineConfig.targetFps] allows are
  /// dropped according to their capture timestamps.
  void submit(PoseFrame frame) {
    if (!_running || _disposed) return;

    if (_processing) {
      if (_pendingFrame != null) {
        _droppedFrameCount++;
      }
      _pendingFrame = frame;
      return;
    }

    if (!_passesThrottle(frame)) {
      _droppedFrameCount++;
      return;
    }

    _startProcessing(frame);
  }

  void _startProcessing(PoseFrame frame) {
    _processing = true;
    _lastInferenceFrameTimestamp = frame.timestamp;
    final generation = _generation;
    final future = _processLoop(frame, generation);
    _processingFuture = future;
    unawaited(future);
  }

  Future<void> _processLoop(PoseFrame firstFrame, int generation) async {
    var frame = firstFrame;
    try {
      while (_running && !_disposed && generation == _generation) {
        final stopwatch = Stopwatch()..start();
        List<BodyPose>? poses;
        try {
          poses = await estimator.estimate(frame);
        } catch (error, stackTrace) {
          if (_running && !_disposed && generation == _generation) {
            _failedFrameCount++;
            _emitError(
              PosePipelineError(
                stage: PosePipelineErrorStage.inference,
                error: error,
                stackTrace: stackTrace,
                frameTimestamp: frame.timestamp,
              ),
            );
          }
        } finally {
          stopwatch.stop();
        }

        if (!_running || _disposed || generation != _generation) break;

        _processedFrameCount++;
        _lastInferenceDuration = stopwatch.elapsed;
        _firstProcessedTimestamp ??= frame.timestamp;
        _lastProcessedTimestamp = frame.timestamp;

        if (poses != null && !_resultsController.isClosed) {
          _resultsController.add(
            PosePipelineResult(
              frame: PoseFrameMetadata.fromFrame(frame),
              poses: poses,
              inferenceDuration: stopwatch.elapsed,
            ),
          );
        }

        final next = _pendingFrame;
        _pendingFrame = null;
        if (next == null) break;

        if (!_passesThrottle(next)) {
          _droppedFrameCount++;
          break;
        }

        _lastInferenceFrameTimestamp = next.timestamp;
        frame = next;
      }
    } finally {
      if (generation == _generation || !_running || _disposed) {
        _processing = false;
        _processingFuture = null;
      }
    }
  }

  bool _passesThrottle(PoseFrame frame) {
    final previous = _lastInferenceFrameTimestamp;
    if (previous == null) return true;
    final delta = frame.timestamp.difference(previous);
    return delta >= config.minimumFrameInterval;
  }

  double get _effectivePoseFps {
    if (_processedFrameCount < 2) return 0;
    final first = _firstProcessedTimestamp;
    final last = _lastProcessedTimestamp;
    if (first == null || last == null) return 0;
    final elapsedMicros = last.difference(first).inMicroseconds;
    if (elapsedMicros <= 0) return 0;
    return (_processedFrameCount - 1) * Duration.microsecondsPerSecond /
        elapsedMicros;
  }

  void _resetSessionState() {
    _pendingFrame = null;
    _lastInferenceFrameTimestamp = null;
    _firstProcessedTimestamp = null;
    _lastProcessedTimestamp = null;
    _processedFrameCount = 0;
    _droppedFrameCount = 0;
    _failedFrameCount = 0;
    _lastInferenceDuration = null;
  }

  void _emitError(PosePipelineError error) {
    if (!_errorsController.isClosed) {
      _errorsController.add(error);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    ++_generation;
    try {
      if (estimator.isInitialized) {
        await estimator.dispose();
      }
    } catch (error, stackTrace) {
      _emitError(
        PosePipelineError(
          stage: PosePipelineErrorStage.disposal,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
    await _resultsController.close();
    await _errorsController.close();
  }
}
