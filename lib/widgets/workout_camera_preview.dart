import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WorkoutCameraPreview extends StatefulWidget {
  final bool enabled;
  final ValueChanged<String?>? onErrorChanged;

  const WorkoutCameraPreview({
    super.key,
    required this.enabled,
    this.onErrorChanged,
  });

  @override
  State<WorkoutCameraPreview> createState() => _WorkoutCameraPreviewState();
}

class _WorkoutCameraPreviewState extends State<WorkoutCameraPreview>
    with WidgetsBindingObserver {
  static const _cameraDiscoveryTimeout = Duration(seconds: 8);
  static const _cameraInitializationTimeout = Duration(seconds: 10);
  static const _retryDelay = Duration(milliseconds: 300);

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _selectedCamera;
  bool _loading = false;
  String? _error;
  int _generation = 0;

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
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      unawaited(_initialize());
    } else {
      unawaited(_disposeController());
      _setError(null);
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

      // Some camera drivers/plugins can stall on the first open. Explicitly
      // release the stalled controller, then retry once. This mirrors the
      // manual off/on sequence that previously made the camera start.
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
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) return camera;
    }
    return cameras.first;
  }

  Future<void> _openCamera(
    CameraDescription camera, {
    required int generation,
  }) async {
    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    if (!mounted || generation != _generation || !widget.enabled) return;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize().timeout(_cameraInitializationTimeout);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    if (!mounted || generation != _generation || !widget.enabled) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  Future<void> _disposeControllerForRetry(int generation) async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
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
    await controller?.dispose();
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

    // camera reports the sensor/preview ratio independently from the current
    // screen orientation on some platforms. Normalize it before constraining
    // CameraPreview, otherwise a landscape ratio gets forced into portrait and
    // the image appears stretched.
    if (orientation == Orientation.portrait && safeRatio > 1) {
      return 1 / safeRatio;
    }
    if (orientation == Orientation.landscape && safeRatio < 1) {
      return 1 / safeRatio;
    }
    return safeRatio;
  }

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

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: previewAspectRatio,
              child: ClipRect(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(-1, 1, 1),
                  child: CameraPreview(controller),
                ),
              ),
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
    unawaited(controller?.dispose());
    super.dispose();
  }
}
