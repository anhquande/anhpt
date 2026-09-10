import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../core/pose/body_pose.dart';
import 'pose_renderer.dart';
import 'pose_view_transform.dart';

class PoseRenderDebugConfig {
  const PoseRenderDebugConfig({
    this.showBounds = false,
    this.showCenterLines = false,
    this.showJointCoordinates = false,
  });

  final bool showBounds;
  final bool showCenterLines;
  final bool showJointCoordinates;

  bool get enabled =>
      showBounds || showCenterLines || showJointCoordinates;

  @override
  bool operator ==(Object other) =>
      other is PoseRenderDebugConfig &&
      other.showBounds == showBounds &&
      other.showCenterLines == showCenterLines &&
      other.showJointCoordinates == showJointCoordinates;

  @override
  int get hashCode => Object.hash(
        showBounds,
        showCenterLines,
        showJointCoordinates,
      );
}

/// Thin Flutter adapter around a reusable [PoseRenderer].
class PosePainter extends CustomPainter {
  PosePainter({
    required this.pose,
    required this.renderer,
    required this.viewTransform,
    this.debugConfig = const PoseRenderDebugConfig(),
  });

  final BodyPose? pose;
  final PoseRenderer renderer;
  final PoseViewTransform viewTransform;
  final PoseRenderDebugConfig debugConfig;

  @override
  void paint(Canvas canvas, Size size) {
    final currentPose = pose;
    if (currentPose == null) return;

    renderer.render(
      canvas: canvas,
      size: size,
      pose: currentPose,
      transformPoint: viewTransform.transformPoint,
    );

    if (debugConfig.enabled) {
      _paintDebug(canvas, size, currentPose);
    }
  }

  void _paintDebug(Canvas canvas, Size size, BodyPose currentPose) {
    final viewportPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFF00FF);
    final previewPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF00E5FF);

    if (debugConfig.showBounds) {
      canvas.drawRect((Offset.zero & size).deflate(.5), viewportPaint);
      canvas.drawRect(
        viewTransform.previewGeometry.destinationRect.deflate(.5),
        previewPaint,
      );
    }

    if (debugConfig.showCenterLines) {
      final rect = viewTransform.previewGeometry.destinationRect;
      canvas.drawLine(
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        previewPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        previewPaint,
      );
    }

    if (debugConfig.showJointCoordinates) {
      for (final entry in currentPose.joints.entries) {
        final point = entry.value;
        final viewPoint = viewTransform.transformPoint(point);
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${entry.key.name} '
                '(${point.x.toStringAsFixed(2)}, '
                '${point.y.toStringAsFixed(2)})',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 9,
              backgroundColor: Color(0x99000000),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 150);
        textPainter.paint(canvas, viewPoint + const Offset(5, 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      !identical(oldDelegate.pose, pose) ||
      !identical(oldDelegate.renderer, renderer) ||
      oldDelegate.viewTransform != viewTransform ||
      oldDelegate.debugConfig != debugConfig;
}
