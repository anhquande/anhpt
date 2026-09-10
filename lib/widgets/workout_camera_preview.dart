import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/workout_camera_preference.dart';
import '../camera/pose_camera_frame_adapter.dart';
import '../core/pose/pose.dart';
import '../pose_rendering/pose_rendering.dart';

class WorkoutCameraPreview extends StatefulWidget {
  final bool enabled;
  final WorkoutCameraFacing facing;
  final PosePipeline? posePipeline;
  final ValueChanged<String?>? onErrorChanged;

  const WorkoutCameraPreview({
    super.key,
    required this.enabled,
    this.facing = WorkoutCameraFacing.front,
    this.posePipeline,
    this.onErrorChanged,
  });

  @override
  State<WorkoutCameraPreview> createState() => _WorkoutCameraPreviewState();
}

class _WorkoutCameraPreviewState extends State<WorkoutCameraPreview>
    with WidgetsBindingObserver {
  static const _cameraDiscoveryTimeout = Duration(seconds: 8);
  static const _cameraInitializationTimeout = Duration(seconds: 10);
  static const _cameraDisposeTimeout = Duration(seconds: 2);
  static const _retryDelay = Duration(milliseconds: 300);
  static const _poseErrorLogInterval = Duration(seconds: 5);

  final SkeletonPoseRenderer _poseRenderer = SkeletonPoseRenderer();
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  bool _loading = false;
  String? _error;
  int _generation = 0;
  DateTime? _lastPoseErrorLogAt;
  PoseViewMode _poseViewMode = PoseViewMode.camera;

  bool get _platformSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      unawaited(_initialize());
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        unawaited(_initialize());
      } else {
        unawaited(_disposeController());
        _setError(null);
      }
      return;
    }
    if (widget.enabled && oldWidget.facing != widget.facing) {
      unawaited(_initialize());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_disposeController());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initialize(preferred: _selectedCamera));
    }
  }

  Future<void> _initialize({CameraDescription? preferred}) async {
    if (!_platformSupported || !widget.enabled || _loading) return;
    final generation = ++_generation;
    if (mounted) setState(() => _loading = true);
    _setError(null);

    try {
      final cameras = await availableCameras().timeout(_cameraDiscoveryTimeout);
      if (!mounted || generation != _generation || !widget.enabled) return;
      if (cameras.isEmpty) {
        _setError('No camera was found on this device.');
        return;
      }

      final chosen = _chooseCamera(cameras, preferred: preferred);
      await _openCameraWithRecovery(chosen, generation: generation);
      if (!mounted || generation != _generation || !widget.enabled) return;
      setState(() {
        _cameras = cameras;
        _selectedCamera = chosen;
      });
    } on TimeoutException {
      if (!mounted || generation != _generation) return;
      _setError('Camera took too long to start. Please try again.');
    } on CameraException catch (error) {
      if (!mounted || generation != _generation) return;
      _setError(_cameraErrorMessage(error));
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _setError('Camera is unavailable: $error');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openCameraWithRecovery(
    CameraDescription camera, {
    required int generation,
  }) async {
    try {
      await _openCamera(camera, generation: generation);
    } on TimeoutException {
      if (!mounted || generation != _generation || !widget.enabled) rethrow;
      await _disposeControllerForRetry(generation);
      if (!mounted || generation != _generation || !widget.enabled) return;
      await Future<void>.delayed(_retryDelay);
      if (!mounted || generation != _generation || !widget.enabled) return;
      await _openCamera(camera, generation: generation);
    }
  }

  CameraDescription _chooseCamera(
    List<CameraDescription> cameras, {
    CameraDescription? preferred,
  }) {
    if (preferred != null) {
      for (final camera in cameras) {
        if (camera.name == preferred.name) return camera;
      }
    }
    final requestedDirection = widget.facing == WorkoutCameraFacing.front
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    for (final camera in cameras) {
      if (camera.lensDirection == requestedDirection) return camera;
    }
    return cameras.first;
  }

  Future<void> _openCamera(
    CameraDescription camera, {
    required int generation,
  }) async {
    final oldController = _controller;
    _controller = null;
    await _disposeSafely(oldController);

    if (!mounted || generation != _generation || !widget.enabled) return;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: PoseCameraFrameAdapter.preferredImageFormatGroup(
        defaultTargetPlatform,
      ),
    );
    try {
      await controller.initialize().timeout(_cameraInitializationTimeout);
    } catch (_) {
      await _disposeSafely(controller);
      rethrow;
    }
    if (!mounted || generation != _generation || !widget.enabled) {
      await _disposeSafely(controller);
      return;
    }
    setState(() => _controller = controller);
    unawaited(
      _startPoseProcessing(
        controller,
        camera,
        generation: generation,
      ),
    );
  }

  Future<void> _startPoseProcessing(
    CameraController controller,
    CameraDescription camera, {
    required int generation,
  }) async {
    final pipeline = widget.posePipeline;
    if (pipeline == null || !controller.supportsImageStreaming()) return;

    await pipeline.start();
    if (!mounted ||
        generation != _generation ||
        !widget.enabled ||
        _controller != controller ||
        !pipeline.isRunning) {
      await pipeline.stop();
      return;
    }

    try {
      await controller.startImageStream((image) {
        if (!mounted ||
            generation != _generation ||
            !widget.enabled ||
            _controller != controller ||
            !pipeline.isRunning) {
          return;
        }
        try {
          final frame = PoseCameraFrameAdapter.fromCameraImage(
            image: image,
            camera: camera,
            deviceOrientation: controller.value.deviceOrientation,
            platform: defaultTargetPlatform,
            // The camera plugin does not expose a cross-platform hardware
            // capture timestamp, so callback delivery time is the canonical
            // capture timestamp for this adapter.
            timestamp: DateTime.now(),
          );
          pipeline.submit(frame);
        } catch (error) {
          _logPoseError('Could not adapt camera frame for pose processing: $error');
        }
      });
    } catch (error) {
      _logPoseError('Pose image streaming is unavailable: $error');
      await pipeline.stop();
    }
  }

  Future<void> _stopPoseProcessing(CameraController? controller) async {
    if (controller != null &&
        controller.value.isInitialized &&
        controller.supportsImageStreaming() &&
        controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream().timeout(_cameraDisposeTimeout);
      } on TimeoutException {
        _logPoseError('Stopping the pose image stream timed out.');
      } catch (error) {
        _logPoseError('Stopping the pose image stream failed: $error');
      }
    }
    await widget.posePipeline?.stop();
  }

  void _logPoseError(String message) {
    final now = DateTime.now();
    final previous = _lastPoseErrorLogAt;
    if (previous != null && now.difference(previous) < _poseErrorLogInterval) {
      return;
    }
    _lastPoseErrorLogAt = now;
    debugPrint(message);
  }

  Future<void> _disposeSafely(CameraController? controller) async {
    await _stopPoseProcessing(controller);
    if (controller == null) return;
    try {
      await controller.dispose().timeout(_cameraDisposeTimeout);
    } on TimeoutException {
      debugPrint('Camera controller dispose timed out.');
    } catch (error) {
      debugPrint('Camera controller dispose failed: $error');
    }
  }

  Future<void> _disposeControllerForRetry(int generation) async {
    final controller = _controller;
    _controller = null;
    await _disposeSafely(controller);
    if (mounted && generation == _generation) setState(() {});
  }

  Future<void> _selectCamera(CameraDescription camera) async {
    if (_selectedCamera?.name == camera.name) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _selectedCamera = camera;
    });
    _setError(null);
    try {
      await _openCameraWithRecovery(camera, generation: generation);
    } on TimeoutException {
      _setError('Camera took too long to start. Please try again.');
    } on CameraException catch (error) {
      _setError(_cameraErrorMessage(error));
    } catch (error) {
      _setError('Could not open camera: $error');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _disposeController() async {
    ++_generation;
    final controller = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await _disposeSafely(controller);
  }

  void _setError(String? value) {
    if (_error == value) return;
    _error = value;
    widget.onErrorChanged?.call(value);
    if (mounted) setState(() {});
  }

  String _cameraErrorMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted') {
      return 'Camera access was denied. Enable camera access in system settings.';
    }
    return 'Camera could not start: ${error.description ?? error.code}';
  }

  double _previewAspectRatio(
    double reportedAspectRatio,
    Orientation orientation,
  ) {
    final safeRatio = reportedAspectRatio.isFinite && reportedAspectRatio > 0
        ? reportedAspectRatio
        : 4 / 3;
    if (orientation == Orientation.portrait && safeRatio > 1) {
      return 1 / safeRatio;
    }
    if (orientation == Orientation.landscape && safeRatio < 1) {
      return 1 / safeRatio;
    }
    return safeRatio;
  }

  IconData _poseViewIcon(PoseViewMode mode) => switch (mode) {
        PoseViewMode.camera => Icons.videocam_outlined,
        PoseViewMode.skeleton => Icons.accessibility_new_rounded,
        PoseViewMode.cameraWithSkeleton => Icons.layers_outlined,
      };

  @override
  Widget build(BuildContext context) {
    if (!_platformSupported) {
      return const Center(child: Text('Workout camera is not supported here.'));
    }
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

    final controller = _controller;
    if (_loading || controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewAspectRatio = _previewAspectRatio(
      controller.value.aspectRatio,
      MediaQuery.orientationOf(context),
    );
    final preview = CameraPreview(controller);
    final cameraView = _selectedCamera?.lensDirection == CameraLensDirection.front
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
              aspectRatio: previewAspectRatio,
              child: ClipRect(
                child: RealtimePoseView(
                  camera: cameraView,
                  results: widget.posePipeline?.results,
                  errors: widget.posePipeline?.errors,
                  capabilities: widget.posePipeline?.estimator.capabilities,
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
              onSelected: (mode) => setState(() => _poseViewMode = mode),
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
        if (_cameras.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(24),
              child: PopupMenuButton<CameraDescription>(
                tooltip: 'Choose camera',
                icon: const Icon(Icons.cameraswitch_outlined),
                onSelected: _selectCamera,
                itemBuilder: (_) => [
                  for (var index = 0; index < _cameras.length; index++)
                    PopupMenuItem(
                      value: _cameras[index],
                      child: Text(_cameraLabel(_cameras[index], index)),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _cameraLabel(CameraDescription camera, int index) {
    final direction = switch (camera.lensDirection) {
      CameraLensDirection.front => 'Front',
      CameraLensDirection.back => 'Back',
      CameraLensDirection.external => 'External',
    };
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return '${index + 1}. ${camera.name}';
    }
    return '$direction camera';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    final controller = _controller;
    _controller = null;
    unawaited(_disposeSafely(controller));
    super.dispose();
  }
}
