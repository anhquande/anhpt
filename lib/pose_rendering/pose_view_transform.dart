import 'dart:ui';

/// Presentation-only transform applied after pose estimation.
///
/// Canonical [BodyPose] coordinates are never mutated. PR6 can extend or
/// replace this transform to account for rotation/crop/aspect-ratio details
/// without changing pose renderers.
class PoseViewTransform {
  const PoseViewTransform({this.mirrorHorizontally = false});

  final bool mirrorHorizontally;

  void applyToCanvas(Canvas canvas, Size size) {
    if (!mirrorHorizontally) return;
    canvas.translate(size.width, 0);
    canvas.scale(-1.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is PoseViewTransform &&
      other.mirrorHorizontally == mirrorHorizontally;

  @override
  int get hashCode => mirrorHorizontally.hashCode;
}
