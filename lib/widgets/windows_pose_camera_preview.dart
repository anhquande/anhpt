import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';

import '../app/workout_camera_preference.dart';
import '../camera/windows_pose_frame_adapter.dart';
import '../core/pose/pose.dart';
import '../pose_rendering/pose_rendering.dart';
import 'pose_performance_metrics.dart';

/// Windows camera surface that exposes raw UVC frames to the canonical pose
/// pipeline while rendering the same native stream through a Flutter Texture.
class WindowsPoseCameraPreview extends StatefulWidget {
  const WindowsPoseCameraPreview({
    super.key,
    required this.enabled,
    required this.facing,
    this.posePipeline,
    this.onErrorChanged,
    this.onPoseFeatures,
    this.camera,
  });

  /// Optional camera implementation for lifecycle regression tests.
  final UvcCamera? camera;

  final bool enabled;
  final WorkoutCameraFacing facing;
  final PosePipeline? posePipeline;
  final ValueChanged<String?>? onErrorChanged;
  final ValueChanged<PoseFeatures>? onPoseFeatures;

  @override
  State<WindowsPoseCameraPreview> createState() =>
      _WindowsPoseCameraPreviewState();
}

class _WindowsPoseCameraPreviewState extends State<WindowsPoseCameraPreview>
    with WidgetsBindingObserver {
  late final UvcCamera _camera = widget.camera ?? UvcCamera();
  Future<void> _operations = Future<void>.value();
  final SkeletonPoseRenderer _poseRenderer = SkeletonPoseRenderer();

  List<UvcUsbDevice> _devices = const [];
  UvcUsbDevice? _selectedDevice;
  UvcCameraMode? _mode;
  int? _textureId;
  PosePipeline? _activePipeline;
  Timer? _frameTimer;
  Timer? _diagnosticsTimer;
  StreamSubscription<PosePipelineResult>? _poseResultSubscription;
  final PosePerformanceMetrics _metrics = PosePerformanceMetrics();
  final ValueNotifier<int> _metricsRefresh = ValueNotifier<int>(0);
  bool _showDiagnostics = false;
  String _diagnosticsState = 'closed';
  void _traceDiagnostics(String action) {
    debugPrint('[PoseDiagnostics] $action; generation=$_generation; '
        'mounted=$mounted; cameraEnabled=${widget.enabled}; '
        'mode=${_poseViewMode.name}; state=$_diagnosticsState');
  }

  DialogRoute<void>? _diagnosticsRoute;
  int _lastFrameSequence = -1;
  int _generation = 0;
  Completer<void>? _initializationCancelled;
  bool _loading = false;
  String? _error;
  PoseViewMode _poseViewMode = PoseViewMode.camera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant WindowsPoseCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        unawaited(_initialize());
      } else {
        unawaited(_teardown());
      }
      return;
    }
    if (widget.enabled &&
        (oldWidget.facing != widget.facing ||
            !identical(oldWidget.posePipeline, widget.posePipeline))) {
      unawaited(_initialize(preferred: _selectedDevice));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _traceDiagnostics('app lifecycle: ${state.name}');
    if (!widget.enabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_teardown());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initialize(preferred: _selectedDevice));
    }
  }

  // Invalidate synchronously; serialize the entire transaction, not just the
  // native calls. A stale transaction must release its handles before reopening.
  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.catchError((Object error, StackTrace stack) {
      debugPrint('Windows camera lifecycle failed: $error');
    });
    return _operations;
  }

  bool _isCurrent(int generation) =>
      mounted && widget.enabled && generation == _generation;

  int _invalidate() {
    _traceDiagnostics('camera invalidated');
    ++_generation;
    final cancelled = _initializationCancelled;
    _initializationCancelled = null;
    if (cancelled != null && !cancelled.isCompleted) cancelled.complete();
    _frameTimer?.cancel();
    _frameTimer = null;
    _hideDiagnosticsOverlay();
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;
    unawaited(_poseResultSubscription?.cancel());
    _poseResultSubscription = null;
    _metrics.reset();
    return _generation;
  }

  Future<void> _initialize({UvcUsbDevice? preferred}) {
    final generation = _invalidate();
    return _enqueue(() => _initializeCamera(generation, preferred));
  }

  Future<void> _initializeCamera(
    int generation,
    UvcUsbDevice? preferred,
  ) async {
    if (!_isCurrent(generation)) return;
    final cancelled = Completer<void>();
    _initializationCancelled = cancelled;
    setState(() => _loading = true);
    _setError(null);

    try {
      await _releaseCamera();
      if (!mounted || generation != _generation || !widget.enabled) return;

      final devices = await _camera.listUsbDevices();
      if (!_isCurrent(generation)) return;
      if (devices.isEmpty) {
        throw StateError('No Windows webcam was found.');
      }
      final selected = _selectDevice(devices, preferred);

      await _camera.openUsbDevice(selected.deviceId);
      if (!mounted || generation != _generation || !widget.enabled) return;

      final textureId = await _camera.createPreviewTexture();
      _textureId = textureId;
      if (!_isCurrent(generation)) return;
      final previewResult = await _camera.startPreviewAuto(
        preference: UvcAutoPreviewPreference.reliability,
      );
      if (!_isCurrent(generation)) return;
      final mode = previewResult.mode;
      if (!previewResult.success || mode == null) {
        throw StateError(
          'Windows webcam opened but no working preview mode was found.',
        );
      }
      await _camera.attachPreviewTexture(
        textureId,
        width: mode.width,
        height: mode.height,
      );

      if (!mounted || generation != _generation || !widget.enabled) {
        return;
      }

      // Retain native handles before estimator initialization so the catch path
      // can always release the texture/device if first-run model setup fails.
      _devices = devices;
      _selectedDevice = selected;
      _textureId = textureId;
      _mode = mode;

      final pipeline = widget.posePipeline;
      if (pipeline != null) {
        _activePipeline = pipeline;
        await Future.any([pipeline.start(), cancelled.future]);
        if (!_isCurrent(generation)) return;
        if (!pipeline.isRunning) {
          throw StateError(
            'Windows pose model could not start. '
            'The first run requires internet access to download MoveNet.',
          );
        }
      }

      if (!_isCurrent(generation)) return;
      _lastFrameSequence = -1;
      _metrics.reset();
      if (pipeline != null) {
        _poseResultSubscription = pipeline.results.listen(_metrics.receivedPose);
        _diagnosticsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_isCurrent(generation)) return;
          _metrics.tick(DateTime.now());
          _metricsRefresh.value++;
        });
      }
      _startFramePump();
      setState(() {});
    } catch (error) {
      if (mounted && generation == _generation) {
        _setError('Windows camera/pose could not start: $error');
      }
      await _releaseCamera();
    } finally {
      if (!_isCurrent(generation)) await _releaseCamera();
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  UvcUsbDevice _selectDevice(
    List<UvcUsbDevice> devices,
    UvcUsbDevice? preferred,
  ) {
    if (preferred != null) {
      for (final device in devices) {
        if (device.deviceId == preferred.deviceId) return device;
      }
    }
    return devices.first;
  }

  void _startFramePump() {
    _frameTimer?.cancel();
    final pipeline = widget.posePipeline;
    if (pipeline == null) return;
    _frameTimer = Timer.periodic(
      pipeline.config.minimumFrameInterval,
      (_) => _submitLatestFrame(),
    );
  }

  void _submitLatestFrame() {
    final pipeline = widget.posePipeline;
    if (!mounted || pipeline == null || !pipeline.isRunning) return;
    try {
      final frame = _camera.copyLatestFrame();
      if (frame == null || frame.sequence == _lastFrameSequence) return;
      _lastFrameSequence = frame.sequence;
      final capturedAt = DateTime.now();
      _metrics.sampledFrame(capturedAt);
      pipeline.submit(
        WindowsPoseFrameAdapter.fromPreviewFrame(
          frame: frame,
          cameraFacing: widget.facing == WorkoutCameraFacing.front
              ? PoseCameraFacing.front
              : PoseCameraFacing.back,
          timestamp: capturedAt,
        ),
      );
    } catch (error) {
      debugPrint('Windows pose frame capture failed: $error');
    }
  }

  Future<void> _selectCamera(UvcUsbDevice device) async {
    if (device.deviceId == _selectedDevice?.deviceId) return;
    await _initialize(preferred: device);
  }

  Future<void> _teardown() {
    _invalidate();
    return _enqueue(() async {
      await _releaseCamera();
      if (mounted) {
        setState(() {
          _devices = const [];
          _selectedDevice = null;
          _loading = false;
        });
      }
    });
  }

  Future<void> _releaseCamera() async {
    _traceDiagnostics('camera release');
    _frameTimer?.cancel();
    _frameTimer = null;
    _hideDiagnosticsOverlay();
    _lastFrameSequence = -1;
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;
    await _poseResultSubscription?.cancel();
    _poseResultSubscription = null;
    _metrics.reset();
    // Stop accepting frames now, but release native capture independently of
    // slow model initialization/inference. The pipeline drains before reuse.
    final poseStopped = _activePipeline?.stop();
    _activePipeline = null;
    try {
      await _camera.stopPreview();
    } catch (_) {
      // Safe during partial initialization or after a device disconnect.
    }

    final textureId = _textureId;
    _textureId = null;
    _mode = null;
    if (textureId != null) {
      try {
        await _camera.disposePreviewTexture(textureId);
      } catch (_) {
        // Texture may already be invalid after a device disconnect.
      }
    }

    try {
      await _camera.closeUsbDevice();
    } catch (_) {
      // Safe if no device was fully opened.
    }

    await poseStopped;
  }

  void _setError(String? value) {
    if (_error == value) return;
    _error = value;
    widget.onErrorChanged?.call(value);
    if (mounted) setState(() {});
  }

  IconData _poseViewIcon(PoseViewMode mode) => switch (mode) {
    PoseViewMode.camera => Icons.videocam_outlined,
    PoseViewMode.skeleton => Icons.accessibility_new_rounded,
    PoseViewMode.cameraWithSkeleton => Icons.layers_outlined,
    PoseViewMode.stickman => Icons.account_circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 36),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _initialize,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final textureId = _textureId;
    final mode = _mode;
    if (_loading || textureId == null || mode == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final preview = Texture(textureId: textureId);
    final cameraView = widget.facing == WorkoutCameraFacing.front
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),
            child: preview,
          )
        : preview;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: mode.width / mode.height,
              child: ClipRect(
                child: RealtimePoseView(
                  camera: cameraView,
                  results: widget.posePipeline?.results,
                  errors: widget.posePipeline?.errors,
                  capabilities: widget.posePipeline?.estimator.capabilities,
                  trackingRequirements: PoseTrackingRequirements.upperBody(),
                  trackingStatusDebounce:
                      RealtimePoseView.defaultTrackingStatusDebounce,
                  onPoseFeatures: widget.onPoseFeatures,
                  mode: _poseViewMode,
                  renderer: _poseRenderer,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(24),
            child: PopupMenuButton<PoseViewMode>(
              tooltip: 'Pose view',
              initialValue: _poseViewMode,
              icon: Icon(_poseViewIcon(_poseViewMode)),
              onSelected: (mode) {
                if (mode != PoseViewMode.stickman) _hideDiagnosticsOverlay();
                setState(() => _poseViewMode = mode);
              },
              itemBuilder: (_) => [
                for (final mode in PoseViewMode.values)
                  PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(_poseViewIcon(mode)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(mode.label)),
                        if (mode == _poseViewMode)
                          const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(Icons.check_rounded),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_poseViewMode == PoseViewMode.stickman)
          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton.filledTonal(
              key: const ValueKey('windows-pose-performance-toggle'),
              tooltip: _showDiagnostics ? 'Hide pose diagnostics' : 'Show pose diagnostics',
              icon: Icon(_showDiagnostics ? Icons.close_rounded : Icons.speed_rounded),
              onPressed: _toggleDiagnosticsOverlay,
            ),
          ),
        if (_devices.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(24),
              child: PopupMenuButton<UvcUsbDevice>(
                tooltip: 'Choose camera',
                icon: const Icon(Icons.cameraswitch_outlined),
                onSelected: _selectCamera,
                itemBuilder: (_) => [
                  for (final device in _devices)
                    PopupMenuItem(
                      value: device,
                      child: Text(device.displayName),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Use a Navigator-managed route instead of a manually inserted root
  // OverlayEntry. The route is independent of camera viewport dimensions,
  // including workout split and picture-in-picture layouts.
  void _toggleDiagnosticsOverlay() {
    _traceDiagnostics('toggle pressed');
    if (_diagnosticsRoute != null) {
      _hideDiagnosticsOverlay();
      if (mounted) setState(() {});
      return;
    }
    _diagnosticsState = 'opening';
    final navigator = Navigator.of(context, rootNavigator: true);
    late final DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        key: const ValueKey('windows-pose-performance-dialog'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _metricsRefresh,
                  builder: (context, _, __) => _buildDiagnostics(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _hideDiagnosticsOverlay,
                  child: const Text('Close diagnostics'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _diagnosticsRoute = route;
    _showDiagnostics = true;
    _traceDiagnostics('pushing dialog route');
    setState(() {});
    unawaited(navigator.push(route).whenComplete(() {
      _traceDiagnostics('dialog route completed');
      if (!identical(_diagnosticsRoute, route)) return;
      _diagnosticsRoute = null;
      _showDiagnostics = false;
      _diagnosticsState = 'closed';
      if (mounted) setState(() {});
    }));
    _diagnosticsState = 'open';
    _traceDiagnostics('dialog route pushed');
  }

  void _hideDiagnosticsOverlay() {
    _traceDiagnostics('dialog hide requested');
    final route = _diagnosticsRoute;
    _diagnosticsRoute = null;
    _showDiagnostics = false;
    _diagnosticsState = 'closed';
    if (route != null && route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  Widget _buildDiagnostics() {
    final diagnostics = widget.posePipeline?.diagnostics;
    final age = _metrics.frameAge(DateTime.now());
    final duration = diagnostics?.lastInferenceDuration;
    return DecoratedBox(
      key: const ValueKey('windows-pose-performance-overlay'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('POSE PERFORMANCE', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Sampled: ${_metrics.sampledFps.toStringAsFixed(1)} FPS'),
              Text('Pose: ${(diagnostics?.effectivePoseFps ?? 0).toStringAsFixed(1)} FPS'),
              Text('Estimate: ${duration == null ? "--" : duration.inMilliseconds.toString()} ms'),
              Text('Frame age: ${age == null ? "--" : age.inMilliseconds.toString()} ms'),
              Text('Dropped: ${diagnostics?.droppedFrameCount ?? 0}'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _traceDiagnostics('widget dispose');
    _invalidate();
    _metricsRefresh.dispose();
    // Queue outside synchronous widget disposal; never race an open/attach.
    unawaited(_enqueue(_disposeCamera));
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    try {
      await _releaseCamera();
    } finally {
      await _camera.dispose();
    }
  }
}
