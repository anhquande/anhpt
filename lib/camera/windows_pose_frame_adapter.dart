import 'package:flutter_ffi_uvc/flutter_ffi_uvc.dart';

import '../core/pose/pose.dart';

/// Converts Windows UVC preview frames into AnhPT's canonical [PoseFrame].
///
/// The UVC package copies the latest native frame into an owned Dart
/// [Uint8List], so the resulting bytes remain valid while [PosePipeline]
/// processes the frame asynchronously.
class WindowsPoseFrameAdapter {
  WindowsPoseFrameAdapter._();

  static PoseFrame fromPreviewFrame({
    required UvcPreviewFrame frame,
    required PoseCameraFacing cameraFacing,
    DateTime? timestamp,
  }) {
    return PoseFrame(
      width: frame.width,
      height: frame.height,
      rotationDegrees: 0,
      format: PoseFrameFormat.rgba8888,
      planes: [
        PoseFramePlane(
          bytes: frame.rgbaBytes,
          bytesPerRow: frame.width * 4,
          bytesPerPixel: 4,
        ),
      ],
      timestamp: timestamp ?? DateTime.now(),
      isMirrored: false,
      cameraFacing: cameraFacing,
    );
  }
}
