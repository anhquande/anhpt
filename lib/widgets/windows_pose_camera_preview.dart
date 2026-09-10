import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';

import '../app/workout_camera_preference.dart';
import '../camera/windows_pose_frame_adapter.dart';
import '../core/pose/pose.dart';
import '../pose_rendering/pose_rendering.dart';

/// Windows camera surface that exposes raw UVC frames to the canonical pose
/// pipeline while rendering the same native stream through a Flutter Texture.
class WindowsPoseCameraPreview extends StatefulWidget {
  const WindowsPoseCameraPreview({
    super.key,
    required this.enabled,
    required this.facing,
    this.posePipeline,
    this.onErrorChanged,
  });

  final bool enabled;
  final WorkoutCameraFacing facing;
  final PosePipeline? posePipeline;
  final ValueChanged<String?>? onErrorChanged;

  @override
  State<WindowsPoseCameraPreview> createState() =>
      _WindowsPoseCameraPreviewState();
}

class _WindowsPoseCameraPreviewState extends State<WindowsPoseCameraPreview>
    with WidgetsBindingObserver {
  final UvcCamera _camera = UvcCamera();
  final SkeletonPoseRenderer _poseRenderer = SkeletonPoseRenderer();

  List<UvcUsbDevice> _devices = const [];
  UvcUsbDevice? _selectedDevice;
  UvcCameraMode? _mode;
  int? _textureId;
  Timer? _frameTimer;
  int _lastFrameSequence = -1;
  int _generation = 0;
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
    if (!widget.enabled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_teardown());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initialize(preferred: _selectedDevice));
    }
  }

  Future<void> _initialize({UvcUsbDevice? preferred}) async {
    if (!widget.enabled || _loading) return;
    final generation = ++_generation;
    setState(() => _loading = true);
    _setError(null);

    try {
      await _teardown(invalidateGeneration: false);
      if (!mounted || generation != _generation || !widget.enabled) return;

      final devices = await _camera.listUsbDevices();
      if (devices.isEmpty) {
        throw StateError('No Windows webcam was found.');
      }
      final selected = _selectDevice(devices, preferred);

      await _camera.openUsbDevice(selected.deviceId);
      if (!mounted || generation != _generation || !widget.enabled) return;

      final textureId = await _camera.createPreviewTexture();
      final previewResult = await _camera.startPreviewAuto(
        preference: UvcAutoPreviewPreference.reliability,
      );
      final mode = previewResult.mode;
      if (!previewResult.success || mode == null) {
        await _camera.disposePreviewTexture(textureId);
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
        await _camera.stopPreview();
        await _camera.disposePreviewTexture(textureId);
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
        await pipeline.start();
        if (!pipeline.isRunning) {
          throw StateError(
            'Windows pose model could not start. '
            'The first run requires internet access to download MoveNet.',
          );
        }
      }

      _lastFrameSequence = -1;
      _startFramePump();
      setState(() {});
    } catch (error) {
      if (mounted && generation == _generation) {
        _setError('Windows camera/pose could not start: $error');
      }
      await _teardown(invalidateGeneration: false);
    } finally {
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
      pipeline.submit(
        WindowsPoseFrameAdapter.fromPreviewFrame(
          frame: frame,
          cameraFacing: widget.facing == WorkoutCameraFacing.front
              ? PoseCameraFacing.front
              : PoseCameraFacing.back,
          timestamp: DateTime.now(),
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

  Future<void> _teardown({bool invalidateGeneration = true}) async {
    if (invalidateGeneration) ++_generation;
    _frameTimer?.cancel();
    _frameTimer = null;
    _lastFrameSequence = -1;

    await widget.posePipeline?.stop();

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

    if (mounted && invalidateGeneration) {
      setState(() {
        _devices = const [];
        _selectedDevice = null;
        _loading = false;
      });
    }
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
        if (_devices.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _frameTimer?.cancel();
    _frameTimer = null;
    unawaited(_disposeCamera());
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    await _teardown(invalidateGeneration: false);
    await _camera.dispose();
  }
}
