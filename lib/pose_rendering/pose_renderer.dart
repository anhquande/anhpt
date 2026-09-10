import 'dart:ui';

import '../core/pose/body_pose.dart';

typedef PosePointProjector = Offset Function(PosePoint point);

/// Engine-independent API for presenting canonical AnhPT pose data.
///
/// Coordinate projection is supplied by the view layer so renderers never
/// duplicate camera rotation, crop, scale, or mirror calculations.
abstract interface class PoseRenderer {
  void render({
    required Canvas canvas,
    required Size size,
    required BodyPose pose,
    required PosePointProjector transformPoint,
  });
}
