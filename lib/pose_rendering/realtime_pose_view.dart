import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/pose/pose.dart';
import 'camera_preview_geometry.dart';
import 'pose_painter.dart';
import 'pose_renderer.dart';
import 'pose_view_mode.dart';
import 'pose_view_transform.dart';

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
    this.errors,
    this.capabilities,
    this.trackingRequirements,
    this.trackingConfig,
    this.previewFit = BoxFit.fill,
    this.debugConfig = const PoseRenderDebugConfig(),
  });

  final Widget camera;
  final Stream<PosePipelineResult>? results;
  final Stream<PosePipelineError>? errors;
  final PoseEstimatorCapabilities? capabilities;
  final PoseTrackingRequirements? trackingRequirements;
  final PoseTrackingConfig? trackingConfig;
  final PoseViewMode mode;
  final PoseRenderer renderer;
  final BoxFit previewFit;
  final PoseRenderDebugConfig debugConfig;

  @override
  State<RealtimePoseView> createState() => _RealtimePoseViewState();
}

class _RealtimePoseViewState extends State<RealtimePoseView> {
  static final PoseEstimatorCapabilities _fallbackCapabilities =
      PoseEstimatorCapabilities(supportedJoints: BodyJoint.values.toSet());

  StreamSubscription<PosePipelineResult>? _subscription;
  StreamSubscription<PosePipelineError>? _errorSubscription;
  late PoseTrackingEvaluator _trackingEvaluator;
  PoseTrackingEvaluation? _trackingEvaluation;
  BodyPose? _pose;
  PoseFrameMetadata? _frame;

  PoseEstimatorCapabilities get _capabilities =>
      widget.capabilities ?? _fallbackCapabilities;

  @override
  void initState() {
    super.initState();
    _resetTrackingEvaluator();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant RealtimePoseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final trackingInputsChanged =
        !identical(oldWidget.capabilities, widget.capabilities) ||
            !identical(
              oldWidget.trackingRequirements,
              widget.trackingRequirements,
            ) ||
            !identical(oldWidget.trackingConfig, widget.trackingConfig);
    final streamsChanged = !identical(oldWidget.results, widget.results) ||
        !identical(oldWidget.errors, widget.errors);

    if (trackingInputsChanged) {
      _resetTrackingEvaluator();
      _trackingEvaluation = null;
      _pose = null;
      _frame = null;
    }
    if (streamsChanged) {
      _subscribe();
    }
  }

  void _resetTrackingEvaluator() {
    _trackingEvaluator = PoseTrackingEvaluator(
      requirements: widget.trackingRequirements,
      config: widget.trackingConfig,
    );
  }

  void _subscribe() {
    unawaited(_subscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    _subscription = null;
    _errorSubscription = null;
    _trackingEvaluator.reset();
    _trackingEvaluation = null;
    _pose = null;
    _frame = null;

    final results = widget.results;
    if (results != null) {
      _subscription = results.listen(_onResult);
    }
    final errors = widget.errors;
    if (errors != null) {
      _errorSubscription = errors.listen(_onError);
    }
  }

  void _onResult(PosePipelineResult result) {
    if (!mounted) return;
    final evaluation = _trackingEvaluator.evaluate(
      poses: result.poses,
      capabilities: _capabilities,
      timestamp: result.frame.timestamp,
    );
    setState(() {
      _trackingEvaluation = evaluation;
      _frame = result.frame;
      final nextPose = evaluation.primaryPose;
      if (nextPose != null) {
        _pose = nextPose;
      } else if (evaluation.state == PoseTrackingState.noPerson ||
          evaluation.state == PoseTrackingState.lostTracking) {
        _pose = null;
      }
      // During a brief invalid observation that is still inside hysteresis,
      // keep the previous pose only in this presentation layer. Canonical
      // BodyPose data is never mutated or synthesized.
    });
  }

  void _onError(PosePipelineError error) {
    if (!mounted || error.stage != PosePipelineErrorStage.inference) return;
    final evaluation = _trackingEvaluator.evaluateInferenceError(
      capabilities: _capabilities,
      timestamp: error.frameTimestamp ?? DateTime.now(),
    );
    setState(() {
      _trackingEvaluation = evaluation;
      if (evaluation.state == PoseTrackingState.noPerson ||
          evaluation.state == PoseTrackingState.lostTracking) {
        _pose = null;
      }
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

  String? _trackingMessage(PoseTrackingEvaluation? evaluation) {
    if (evaluation == null) return null;
    if (evaluation.hasCapabilityMismatch) {
      return 'Pose model does not support all required joints';
    }
    return switch (evaluation.state) {
      PoseTrackingState.noPerson => 'Move into camera view',
      PoseTrackingState.partialBody => 'Make sure your full body is visible',
      PoseTrackingState.initializing => 'Hold still',
      PoseTrackingState.ready => 'Ready',
      PoseTrackingState.tracking => null,
      PoseTrackingState.lostTracking => 'Tracking lost',
    };
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
        final trackingMessage = _trackingMessage(_trackingEvaluation);

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
            if (trackingMessage != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      key: const ValueKey('pose-tracking-status'),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          trackingMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ),
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
    unawaited(_errorSubscription?.cancel());
    _subscription = null;
    _errorSubscription = null;
    super.dispose();
  }
}
