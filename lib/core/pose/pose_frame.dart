import 'dart:collection';
import 'dart:typed_data';

/// Pixel layout of a [PoseFrame].
///
/// This describes image memory only. It is intentionally independent from any
/// camera plugin or pose-estimation engine.
enum PoseFrameFormat {
  yuv420,
  nv21,
  bgra8888,
  rgba8888,
  jpeg,
  unknown,
}

/// One memory plane belonging to a [PoseFrame].
///
/// [bytes] is treated as read-only borrowed memory. Producers may reuse the
/// underlying buffer after pose estimation for the frame has completed, so
/// consumers must not mutate it or retain it beyond the estimation call.
class PoseFramePlane {
  const PoseFramePlane({
    required this.bytes,
    this.bytesPerRow,
    this.bytesPerPixel,
  })  : assert(bytesPerRow == null || bytesPerRow > 0),
        assert(bytesPerPixel == null || bytesPerPixel > 0);

  final Uint8List bytes;
  final int? bytesPerRow;
  final int? bytesPerPixel;
}

/// Engine- and camera-independent image frame used as pose-estimator input.
///
/// The frame carries only normalized image metadata and raw image planes.
/// Camera adapters are responsible for mapping platform/plugin frame objects
/// into this representation.
class PoseFrame {
  PoseFrame({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.format,
    required List<PoseFramePlane> planes,
    required this.timestamp,
    this.isMirrored = false,
  })  : assert(width > 0),
        assert(height > 0),
        assert(
          rotationDegrees == 0 ||
              rotationDegrees == 90 ||
              rotationDegrees == 180 ||
              rotationDegrees == 270,
        ),
        assert(planes.isNotEmpty),
        planes = UnmodifiableListView<PoseFramePlane>(
          List<PoseFramePlane>.from(planes),
        );

  final int width;
  final int height;

  /// Clockwise rotation required to interpret the image as upright.
  final int rotationDegrees;

  final PoseFrameFormat format;
  final List<PoseFramePlane> planes;

  /// Capture timestamp supplied by the frame producer.
  final DateTime timestamp;

  /// Whether the image content is horizontally mirrored.
  final bool isMirrored;

  bool get isPortraitAfterRotation =>
      rotationDegrees == 90 || rotationDegrees == 270
          ? width > height
          : height > width;
}
