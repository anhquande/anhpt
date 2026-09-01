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
    final camera = WorkoutCameraPreview(
      enabled: cameraEnabled,
      onErrorChanged: onCameraErrorChanged,
    );
    final demo = demonstration;

    if (!cameraEnabled) return demo ?? const SizedBox.shrink();
    if (demo == null) return _frame(camera);

    return switch (layout) {
      WorkoutCameraLayout.split => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _frame(demo)),
            const SizedBox(width: 8),
            Expanded(child: _frame(camera)),
          ],
        ),
      WorkoutCameraLayout.pictureInPicture => Stack(
          fit: StackFit.expand,
          children: [
            _frame(demo),
            Positioned(
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
          ],
        ),
      WorkoutCameraLayout.overlay => Stack(
          fit: StackFit.expand,
          children: [
            _frame(demo),
            Opacity(opacity: .48, child: _frame(camera)),
          ],
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
