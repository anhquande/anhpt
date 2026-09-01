import 'package:flutter/material.dart';

import '../app/workout_camera_preference.dart';
import 'workout_camera_preview.dart';

class WorkoutCameraComparison extends StatelessWidget {
  final bool cameraEnabled;
  final WorkoutCameraLayout layout;
  final Widget? demonstration;
  final ValueChanged<String?>? onCameraErrorChanged;

  const WorkoutCameraComparison({
    super.key,
    required this.cameraEnabled,
    required this.layout,
    this.demonstration,
    this.onCameraErrorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final demo = demonstration;
    if (!cameraEnabled) return demo ?? const SizedBox.shrink();

    // Keep the camera as the same child in the same Stack for every step/layout.
    // This prevents its State (and CameraController) from being disposed when a
    // step gains/loses demonstration media or when the layout changes.
    final camera = WorkoutCameraPreview(
      enabled: cameraEnabled,
      onErrorChanged: onCameraErrorChanged,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (demo != null) _buildDemo(layout, demo),
        _buildCamera(layout, camera, hasDemo: demo != null),
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
    };
  }

  Widget _buildCamera(
    WorkoutCameraLayout layout,
    Widget camera, {
    required bool hasDemo,
  }) {
    if (!hasDemo) return _frame(camera);

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
      WorkoutCameraLayout.overlay => Opacity(
          opacity: .48,
          child: _frame(camera),
        ),
    };
  }

  Widget _frame(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: Colors.black,
          child: child,
        ),
      );
}
