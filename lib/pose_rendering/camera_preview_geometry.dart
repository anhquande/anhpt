import 'dart:ui';

import 'package:flutter/painting.dart';

/// Authoritative presentation geometry for one camera preview surface.
///
/// [previewSourceSize] describes the already-oriented camera image that is
/// fitted into [viewportSize]. Pose coordinates are mapped through the same
/// source/destination rectangles, so renderer math cannot drift from preview
/// crop/scale behavior.
class CameraPreviewGeometry {
  factory CameraPreviewGeometry({
    required Size previewSourceSize,
    required Size viewportSize,
    required BoxFit fit,
    required bool mirrored,
  }) {
    _validateSize(previewSourceSize, 'previewSourceSize');
    _validateSize(viewportSize, 'viewportSize');

    final fitted = applyBoxFit(fit, previewSourceSize, viewportSize);
    final sourceBounds = Offset.zero & previewSourceSize;
    final viewportBounds = Offset.zero & viewportSize;
    final sourceRect = Alignment.center.inscribe(fitted.source, sourceBounds);
    final destinationRect =
        Alignment.center.inscribe(fitted.destination, viewportBounds);

    return CameraPreviewGeometry._(
      previewSourceSize: previewSourceSize,
      viewportSize: viewportSize,
      fit: fit,
      mirrored: mirrored,
      sourceRect: sourceRect,
      destinationRect: destinationRect,
    );
  }

  const CameraPreviewGeometry._({
    required this.previewSourceSize,
    required this.viewportSize,
    required this.fit,
    required this.mirrored,
    required this.sourceRect,
    required this.destinationRect,
  });

  final Size previewSourceSize;
  final Size viewportSize;
  final BoxFit fit;
  final bool mirrored;

  /// Visible/cropped source rectangle in oriented camera coordinates.
  final Rect sourceRect;

  /// Camera preview rectangle in local Flutter view coordinates.
  final Rect destinationRect;

  Offset get cropOffset => sourceRect.topLeft;

  double get scaleX => destinationRect.width / sourceRect.width;

  double get scaleY => destinationRect.height / sourceRect.height;

  /// Maps an already-oriented normalized point into local preview coordinates.
  ///
  /// Mirroring is intentionally the final presentation operation. It mirrors
  /// around the camera destination rectangle and never changes canonical pose
  /// data.
  Offset transformNormalizedPoint(Offset normalizedPoint) {
    final sourcePoint = Offset(
      normalizedPoint.dx * previewSourceSize.width,
      normalizedPoint.dy * previewSourceSize.height,
    );

    var x = destinationRect.left +
        (sourcePoint.dx - sourceRect.left) * scaleX;
    final y = destinationRect.top +
        (sourcePoint.dy - sourceRect.top) * scaleY;

    if (mirrored) {
      x = destinationRect.right - (x - destinationRect.left);
    }
    return Offset(x, y);
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
      other is CameraPreviewGeometry &&
      other.previewSourceSize == previewSourceSize &&
      other.viewportSize == viewportSize &&
      other.fit == fit &&
      other.mirrored == mirrored &&
      other.sourceRect == sourceRect &&
      other.destinationRect == destinationRect;

  @override
  int get hashCode => Object.hash(
        previewSourceSize,
        viewportSize,
        fit,
        mirrored,
        sourceRect,
        destinationRect,
      );
}
