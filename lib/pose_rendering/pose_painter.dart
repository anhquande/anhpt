import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/pose/body_pose.dart';
import 'pose_renderer.dart';
import 'pose_view_transform.dart';

/// Thin Flutter adapter around a reusable [PoseRenderer].
class PosePainter extends CustomPainter {
  PosePainter({
    required this.pose,
    required this.renderer,
    this.viewTransform = const PoseViewTransform(),
  });

  final BodyPose? pose;
  final PoseRenderer renderer;
  final PoseViewTransform viewTransform;

  @override
  void paint(Canvas canvas, Size size) {
    final currentPose = pose;
    if (currentPose == null) return;

    canvas.save();
    try {
      viewTransform.applyToCanvas(canvas, size);
      renderer.render(canvas: canvas, size: size, pose: currentPose);
    } finally {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      !identical(oldDelegate.pose, pose) ||
      !identical(oldDelegate.renderer, renderer) ||
      oldDelegate.viewTransform != viewTransform;
}
