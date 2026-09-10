import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/pose/pose.dart';
import 'camera_preview_geometry.dart';
import 'pose_painter.dart';
import 'pose_renderer.dart';
import 'pose_view_mode.dart';
import 'pose_view_transform.dart';
import 'primary_pose_selector.dart';

/// Presentation widget that consumes PR4 pipeline results and paints one pose.
///
/// It never invokes an estimator. Camera ownership remains outside this widget.
/// The enclosing workout camera already establishes the native camera aspect
/// ratio, so the default inner fit is [BoxFit.fill]. Tests and alternate camera
/// surfaces may choose another fit explicitly.
class RealtimePoseView extends StatefulWidget {
  const RealtimePoseView({
    super.key,
    required this.camera,
    required this.results,
    required this.mode,
    required this.renderer,
    this.primaryPoseSelector,
    this.previewFit = BoxFit.fill,
    this.debugConfig = const PoseRenderDebugConfig(),
  });

  final Widget camera;
  final Stream<PosePipelineResult>? results;
  final PoseViewMode mode;
  final PoseRenderer renderer;
  final PrimaryPoseSelector? primaryPoseSelector;
  final BoxFit previewFit;
  final PoseRenderDebugConfig debugConfig;

  @override
  State<RealtimePoseView> createState() => _RealtimePoseViewState();
}

class _RealtimePoseViewState extends State<RealtimePoseView> {
  StreamSubscription<PosePipelineResult>? _subscription;
  BodyPose? _pose;
  PoseFrameMetadata? _frame;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.results);
  }

  @override
  void didUpdateWidget(covariant RealtimePoseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.results, widget.results)) {
      _subscribe(widget.results);
    }
  }

  void _subscribe(Stream<PosePipelineResult>? results) {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _pose = null;
    _frame = null;
    if (results != null) {
      _subscription = results.listen(_onResult);
    }
  }

  void _onResult(PosePipelineResult result) {
    if (!mounted) return;
    final selector = widget.primaryPoseSelector ?? selectPrimaryPose;
    setState(() {
      _pose = selector(result.poses);
      _frame = result.frame;
    });
  }

  bool _mirrorForVisiblePreview(PoseFrameMetadata frame) =>
      frame.cameraFacing == PoseCameraFacing.front && !frame.isMirrored;

  CameraPreviewGeometry _previewGeometry(Size viewportSize) {
    final frame = _frame;
    if (frame == null) {
      return CameraPreviewGeometry(
        previewSourceSize: viewportSize,
        viewportSize: viewportSize,
        fit: BoxFit.fill,
        mirrored: false,
      );
    }

    final sourceSize = Size(
      frame.width.toDouble(),
      frame.height.toDouble(),
    );
    final orientedSourceSize = PoseViewTransform.orientedSourceSizeFor(
      sourceSize,
      frame.rotationDegrees,
    );
    return CameraPreviewGeometry(
      previewSourceSize: orientedSourceSize,
      viewportSize: viewportSize,
      fit: widget.previewFit,
      mirrored: _mirrorForVisiblePreview(frame),
    );
  }

  PoseViewTransform? _viewTransform(CameraPreviewGeometry geometry) {
    final frame = _frame;
    if (frame == null) return null;
    return PoseViewTransform(
      sourceSize: Size(frame.width.toDouble(), frame.height.toDouble()),
      rotationDegrees: frame.rotationDegrees,
      previewGeometry: geometry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite ||
            !height.isFinite ||
            width <= 0 ||
            height <= 0) {
          return const SizedBox.shrink();
        }

        final viewportSize = Size(width, height);
        final geometry = _previewGeometry(viewportSize);
        final viewTransform = _viewTransform(geometry);
        final pose = _pose;

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(
              key: ValueKey('pose-view-background'),
              color: Colors.black,
            ),
            if (widget.mode.showsCamera)
              Positioned.fromRect(
                rect: geometry.destinationRect,
                child: KeyedSubtree(
                  key: const ValueKey('pose-camera-layer'),
                  child: widget.camera,
                ),
              ),
            if (widget.mode.showsSkeleton &&
                pose != null &&
                viewTransform != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('pose-skeleton-layer'),
                    painter: PosePainter(
                      pose: pose,
                      renderer: widget.renderer,
                      viewTransform: viewTransform,
                      debugConfig: widget.debugConfig,
                    ),
                  ),
                ),
              ),
            if (widget.mode == PoseViewMode.skeleton && pose == null)
              const Center(
                key: ValueKey('pose-skeleton-empty-state'),
                child: Icon(
                  Icons.accessibility_new_rounded,
                  color: Colors.white24,
                  size: 48,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
