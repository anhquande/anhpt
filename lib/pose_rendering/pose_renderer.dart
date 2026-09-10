import 'dart:ui';

import '../core/pose/body_pose.dart';

/// Engine-independent API for presenting canonical AnhPT pose data.
abstract interface class PoseRenderer {
  void render({
    required Canvas canvas,
    required Size size,
    required BodyPose pose,
  });
}
