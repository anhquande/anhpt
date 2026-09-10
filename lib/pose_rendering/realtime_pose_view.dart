import 'dart:async';

import 'package:flutter/material.dart';

import '../core/pose/pose.dart';
import 'pose_painter.dart';
import 'pose_renderer.dart';
import 'pose_view_mode.dart';
import 'pose_view_transform.dart';
import 'primary_pose_selector.dart';

/// Presentation widget that consumes PR4 pipeline results and paints one pose.
///
/// It never invokes an estimator. Camera ownership remains outside this widget.
class RealtimePoseView extends StatefulWidget {
  const RealtimePoseView({
    super.key,
    required this.camera,
    required this.results,
    required this.mode,
    required this.renderer,
    this.primaryPoseSelector,
  });

  final Widget camera;
  final Stream<PosePipelineResult>? results;
  final PoseViewMode mode;
  final PoseRenderer renderer;
  final PrimaryPoseSelector? primaryPoseSelector;

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

  PoseViewTransform get _viewTransform {
    final frame = _frame;
    final mirrorForFrontPreview = frame != null &&
        frame.cameraFacing == PoseCameraFacing.front &&
        !frame.isMirrored;
    return PoseViewTransform(mirrorHorizontally: mirrorForFrontPreview);
  }

  @override
  Widget build(BuildContext context) {
    final pose = _pose;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(
          key: ValueKey('pose-view-background'),
          color: Colors.black,
        ),
        if (widget.mode.showsCamera)
          KeyedSubtree(
            key: const ValueKey('pose-camera-layer'),
            child: widget.camera,
          ),
        if (widget.mode.showsSkeleton && pose != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('pose-skeleton-layer'),
                painter: PosePainter(
                  pose: pose,
                  renderer: widget.renderer,
                  viewTransform: _viewTransform,
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
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
