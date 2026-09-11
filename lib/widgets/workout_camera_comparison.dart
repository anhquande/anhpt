import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/workout_camera_preference.dart';
import '../core/pose/pose.dart';
import '../models/workout_video_settings.dart';
import '../pose_estimators/default_pose_estimator.dart';
import 'windows_pose_camera_preview.dart';
import 'workout_camera_preview.dart';

class WorkoutCameraComparison extends StatefulWidget {
  final bool cameraEnabled;
  final bool demonstrationEnabled;
  final WorkoutCameraLayout layout;
  final WorkoutCameraFacing? cameraFacing;
  final PosePipeline? posePipeline;
  final Widget? demonstration;
  final ValueChanged<String?>? onCameraErrorChanged;

  const WorkoutCameraComparison({
    super.key,
    required this.cameraEnabled,
    this.demonstrationEnabled = true,
    required this.layout,
    this.cameraFacing,
    this.posePipeline,
    this.demonstration,
    this.onCameraErrorChanged,
  });

  @override
  State<WorkoutCameraComparison> createState() =>
      _WorkoutCameraComparisonState();
}

class _WorkoutCameraComparisonState extends State<WorkoutCameraComparison> {
  final GlobalKey _cameraKey = GlobalKey(debugLabel: 'workout-camera-preview');
  PosePipeline? _ownedPosePipeline;

  PosePipeline get _posePipeline => widget.posePipeline ??
      (_ownedPosePipeline ??=
          PosePipeline(estimator: createDefaultPoseEstimator()));

  @override
  Widget build(BuildContext context) {
    final demo = widget.demonstration ?? _defaultDemonstration(context);
    if (!widget.cameraEnabled) return demo;

    final configuredFacing = WorkoutVideoRuntime.current?.camera == 'back'
        ? WorkoutCameraFacing.back
        : WorkoutCameraFacing.front;
    final facing = widget.cameraFacing ?? configuredFacing;
    final camera = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? WindowsPoseCameraPreview(
            key: _cameraKey,
            enabled: true,
            facing: facing,
            posePipeline: _posePipeline,
            onErrorChanged: widget.onCameraErrorChanged,
          )
        : WorkoutCameraPreview(
            key: _cameraKey,
            enabled: true,
            facing: facing,
            posePipeline: _posePipeline,
            onErrorChanged: widget.onCameraErrorChanged,
          );

    if (!widget.demonstrationEnabled) {
      return _frame(camera);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildDemo(widget.layout, demo),
        _buildCamera(widget.layout, camera),
      ],
    );
  }

  Widget _buildDemo(WorkoutCameraLayout layout, Widget demo) {
    return switch (layout) {
      WorkoutCameraLayout.split => Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: .5,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _frame(demo),
            ),
          ),
        ),
      WorkoutCameraLayout.pictureInPicture || WorkoutCameraLayout.overlay =>
        _frame(demo),
      WorkoutCameraLayout.cameraPictureInPicture => Positioned(
          right: 10,
          bottom: 10,
          width: 150,
          height: 112,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: _frame(demo),
          ),
        ),
    };
  }

  Widget _buildCamera(WorkoutCameraLayout layout, Widget camera) {
    return switch (layout) {
      WorkoutCameraLayout.split => Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: .5,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: _frame(camera),
            ),
          ),
        ),
      WorkoutCameraLayout.pictureInPicture => Positioned(
          right: 10,
          bottom: 10,
          width: 150,
          height: 112,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: camera,
          ),
        ),
      WorkoutCameraLayout.cameraPictureInPicture => _frame(camera),
      WorkoutCameraLayout.overlay => Opacity(
          opacity: .48,
          child: _frame(camera),
        ),
    };
  }

  Widget _defaultDemonstration(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                size: 48,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'No demonstration for this step',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Colors.black,
          child: child,
        ),
      );

  @override
  void dispose() {
    final ownedPipeline = _ownedPosePipeline;
    _ownedPosePipeline = null;
    if (ownedPipeline != null) {
      unawaited(ownedPipeline.dispose());
    }
    super.dispose();
  }
}
