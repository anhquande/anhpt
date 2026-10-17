import 'dart:math' as math;
import 'dart:ui';

import '../core/pose/body_pose.dart';
import 'pose_renderer.dart';

/// Minimal, camera-independent 2D avatar made of rounded limbs and a head.
///
/// Uses only canonical joints and the same orientation/crop/mirror projection
/// as the existing skeleton layer. No frames or identifiable pixels are drawn.
class StickmanPoseRenderer implements PoseRenderer {
  StickmanPoseRenderer({
    this.minConfidence = 0.4,
    this.color = const Color(0xFF80DEEA),
  }) : assert(minConfidence >= 0 && minConfidence <= 1);

  final double minConfidence;
  final Color color;

  bool _visible(PosePoint? point) =>
      point != null &&
      point.confidence >= minConfidence &&
      point.x.isFinite &&
      point.y.isFinite;

  @override
  void render({
    required Canvas canvas,
    required Size size,
    required BodyPose pose,
    required PosePointProjector transformPoint,
  }) {
    final limbPaint = Paint()
      ..color = color
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    Offset? at(BodyJoint joint) {
      final point = pose[joint];
      return _visible(point) ? transformPoint(point!) : null;
    }

    void join(Offset? a, Offset? b, Paint paint) {
      if (a == null || b == null) return;
      canvas.drawLine(a, b, paint);
    }

    Offset? midpoint(Offset? a, Offset? b) =>
        a == null || b == null ? null : Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    final leftShoulder = at(BodyJoint.leftShoulder);
    final rightShoulder = at(BodyJoint.rightShoulder);
    final leftHip = at(BodyJoint.leftHip);
    final rightHip = at(BodyJoint.rightHip);
    final shoulders = midpoint(leftShoulder, rightShoulder);
    final hips = midpoint(leftHip, rightHip);
    final neck = at(BodyJoint.neck) ?? shoulders;

    join(leftShoulder, rightShoulder, bodyPaint);
    join(shoulders, hips, bodyPaint);
    join(leftHip, rightHip, bodyPaint);
    join(leftShoulder, at(BodyJoint.leftElbow), limbPaint);
    join(at(BodyJoint.leftElbow), at(BodyJoint.leftWrist), limbPaint);
    join(rightShoulder, at(BodyJoint.rightElbow), limbPaint);
    join(at(BodyJoint.rightElbow), at(BodyJoint.rightWrist), limbPaint);
    join(leftHip, at(BodyJoint.leftKnee), limbPaint);
    join(at(BodyJoint.leftKnee), at(BodyJoint.leftAnkle), limbPaint);
    join(rightHip, at(BodyJoint.rightKnee), limbPaint);
    join(at(BodyJoint.rightKnee), at(BodyJoint.rightAnkle), limbPaint);

    final nose = at(BodyJoint.nose);
    final leftEar = at(BodyJoint.leftEar);
    final rightEar = at(BodyJoint.rightEar);
    final ears = midpoint(leftEar, rightEar);
    final headCenter = ears ?? nose;
    if (headCenter != null) {
      final shoulderWidth = leftShoulder != null && rightShoulder != null
          ? (leftShoulder - rightShoulder).distance
          : 0.0;
      final faceWidth = leftEar != null && rightEar != null
          ? (leftEar - rightEar).distance
          : 0.0;
      final radius = math.max(9.0, math.min(24.0,
          faceWidth > 0 ? faceWidth * .65 :
          shoulderWidth > 0 ? shoulderWidth * .28 : 13.0));
      final center = ears == null && nose != null
          ? Offset(nose.dx, nose.dy - radius * .28)
          : headCenter;
      canvas.drawCircle(center, radius, Paint()..color = color.withValues(alpha: .17));
      canvas.drawCircle(center, radius, limbPaint..strokeWidth = 4);
      if (neck != null) {
        final direction = neck - center;
        final distance = direction.distance;
        if (distance > radius) {
          join(center + direction * (radius / distance), neck, limbPaint);
        }
      }
    }
  }
}
