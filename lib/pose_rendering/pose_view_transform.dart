import 'dart:ui';

import '../core/pose/body_pose.dart';
import 'camera_preview_geometry.dart';

/// Presentation-only mapping from canonical source coordinates to camera view.
///
/// Transformation order is intentionally centralized here:
///
/// canonical normalized source
///   -> frame rotation (0/90/180/270)
///   -> oriented normalized preview coordinates
///   -> preview fit/crop
///   -> optional presentation mirror
///   -> local Flutter coordinates
///
/// The input [PosePoint] is never mutated or replaced.
class PoseViewTransform {
  PoseViewTransform({
    required this.sourceSize,
    required this.rotationDegrees,
    required this.previewGeometry,
  }) {
    _validateSize(sourceSize, 'sourceSize');
    _validateRotation(rotationDegrees);
  }

  final Size sourceSize;
  final int rotationDegrees;
  final CameraPreviewGeometry previewGeometry;

  Size get orientedSourceSize =>
      orientedSourceSizeFor(sourceSize, rotationDegrees);

  Offset transformPoint(PosePoint point) {
    final oriented = rotateNormalizedPoint(
      Offset(point.x, point.y),
      rotationDegrees,
    );
    return previewGeometry.transformNormalizedPoint(oriented);
  }

  static Size orientedSourceSizeFor(Size sourceSize, int rotationDegrees) {
    _validateSize(sourceSize, 'sourceSize');
    _validateRotation(rotationDegrees);
    return rotationDegrees == 90 || rotationDegrees == 270
        ? Size(sourceSize.height, sourceSize.width)
        : sourceSize;
  }

  static Offset rotateNormalizedPoint(Offset point, int rotationDegrees) {
    _validateRotation(rotationDegrees);
    return switch (rotationDegrees) {
      0 => point,
      90 => Offset(1 - point.dy, point.dx),
      180 => Offset(1 - point.dx, 1 - point.dy),
      270 => Offset(point.dy, 1 - point.dx),
      _ => throw StateError('Unreachable rotation validation branch.'),
    };
  }

  static void _validateRotation(int rotationDegrees) {
    if (rotationDegrees != 0 &&
        rotationDegrees != 90 &&
        rotationDegrees != 180 &&
        rotationDegrees != 270) {
      throw ArgumentError.value(
        rotationDegrees,
        'rotationDegrees',
        'Expected 0, 90, 180 or 270.',
      );
    }
  }

  static void _validateSize(Size size, String name) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      throw ArgumentError.value(
        size,
        name,
        'Expected finite, positive dimensions.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PoseViewTransform &&
      other.sourceSize == sourceSize &&
      other.rotationDegrees == rotationDegrees &&
      other.previewGeometry == previewGeometry;

  @override
  int get hashCode => Object.hash(
        sourceSize,
        rotationDegrees,
        previewGeometry,
      );
}
