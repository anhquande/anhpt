import 'dart:ui';

import '../core/pose/body_pose.dart';
import 'pose_renderer.dart';

/// One engine-independent connection between two canonical body joints.
class PoseBone {
  const PoseBone(this.start, this.end);

  final BodyJoint start;
  final BodyJoint end;

  @override
  bool operator ==(Object other) =>
      other is PoseBone && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// AnhPT-owned skeleton topology.
///
/// Concrete pose engines only map landmarks to [BodyJoint]. They never define
/// which canonical joints AnhPT connects for visualization.
const canonicalSkeletonBones = <PoseBone>[
  PoseBone(BodyJoint.nose, BodyJoint.leftEye),
  PoseBone(BodyJoint.nose, BodyJoint.rightEye),
  PoseBone(BodyJoint.leftEye, BodyJoint.leftEar),
  PoseBone(BodyJoint.rightEye, BodyJoint.rightEar),
  PoseBone(BodyJoint.nose, BodyJoint.neck),
  PoseBone(BodyJoint.neck, BodyJoint.leftShoulder),
  PoseBone(BodyJoint.neck, BodyJoint.rightShoulder),
  PoseBone(BodyJoint.leftShoulder, BodyJoint.rightShoulder),
  PoseBone(BodyJoint.leftShoulder, BodyJoint.leftElbow),
  PoseBone(BodyJoint.leftElbow, BodyJoint.leftWrist),
  PoseBone(BodyJoint.rightShoulder, BodyJoint.rightElbow),
  PoseBone(BodyJoint.rightElbow, BodyJoint.rightWrist),
  PoseBone(BodyJoint.leftShoulder, BodyJoint.leftHip),
  PoseBone(BodyJoint.rightShoulder, BodyJoint.rightHip),
  PoseBone(BodyJoint.leftHip, BodyJoint.rightHip),
  PoseBone(BodyJoint.leftHip, BodyJoint.leftKnee),
  PoseBone(BodyJoint.leftKnee, BodyJoint.leftAnkle),
  PoseBone(BodyJoint.rightHip, BodyJoint.rightKnee),
  PoseBone(BodyJoint.rightKnee, BodyJoint.rightAnkle),
  PoseBone(BodyJoint.leftAnkle, BodyJoint.leftHeel),
  PoseBone(BodyJoint.leftHeel, BodyJoint.leftFootIndex),
  PoseBone(BodyJoint.leftAnkle, BodyJoint.leftFootIndex),
  PoseBone(BodyJoint.rightAnkle, BodyJoint.rightHeel),
  PoseBone(BodyJoint.rightHeel, BodyJoint.rightFootIndex),
  PoseBone(BodyJoint.rightAnkle, BodyJoint.rightFootIndex),
];

class SkeletonRenderConfig {
  const SkeletonRenderConfig({
    this.jointRadius = 4.0,
    this.boneStrokeWidth = 3.0,
    this.minJointConfidence = 0.4,
    this.jointColor = const Color(0xFFFFD54F),
    this.boneColor = const Color(0xE6FFFFFF),
  })  : assert(jointRadius > 0),
        assert(boneStrokeWidth > 0),
        assert(minJointConfidence >= 0 && minJointConfidence <= 1);

  final double jointRadius;
  final double boneStrokeWidth;
  final double minJointConfidence;
  final Color jointColor;
  final Color boneColor;
}

Offset normalizedPosePointToOffset(PosePoint point, Size size) =>
    Offset(point.x * size.width, point.y * size.height);

/// Lightweight skeleton renderer for canonical [BodyPose] values.
class SkeletonPoseRenderer implements PoseRenderer {
  SkeletonPoseRenderer({this.config = const SkeletonRenderConfig()})
      : _jointPaint = Paint(),
        _bonePaint = Paint() {
    _jointPaint
      ..style = PaintingStyle.fill
      ..color = config.jointColor;
    _bonePaint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = config.boneStrokeWidth
      ..color = config.boneColor;
  }

  final SkeletonRenderConfig config;
  final Paint _jointPaint;
  final Paint _bonePaint;

  List<PoseBone> get topology => canonicalSkeletonBones;

  bool jointIsRenderable(PosePoint? point) =>
      point != null && point.confidence >= config.minJointConfidence;

  bool boneIsRenderable(BodyPose pose, PoseBone bone) =>
      jointIsRenderable(pose[bone.start]) && jointIsRenderable(pose[bone.end]);

  @override
  void render({
    required Canvas canvas,
    required Size size,
    required BodyPose pose,
  }) {
    for (final bone in canonicalSkeletonBones) {
      final start = pose[bone.start];
      final end = pose[bone.end];
      if (!jointIsRenderable(start) || !jointIsRenderable(end)) continue;
      canvas.drawLine(
        normalizedPosePointToOffset(start!, size),
        normalizedPosePointToOffset(end!, size),
        _bonePaint,
      );
    }

    for (final point in pose.joints.values) {
      if (!jointIsRenderable(point)) continue;
      canvas.drawCircle(
        normalizedPosePointToOffset(point, size),
        config.jointRadius,
        _jointPaint,
      );
    }
  }
}
