import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/pose/pose.dart';

/// Converts camera-plugin frames into AnhPT's canonical [PoseFrame].
///
/// This adapter performs no estimator-specific preprocessing. It preserves the
/// source image layout and camera metadata needed by downstream pose code.
class PoseCameraFrameAdapter {
  PoseCameraFrameAdapter._();

  static const Map<DeviceOrientation, int> _orientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Chooses the camera package's most useful canonical streaming format for
  /// each supported mobile platform.
  ///
  /// Android CameraX can emit NV21 directly and iOS camera streams emit BGRA.
  /// Desktop currently falls back to unknown because the bundled Windows
  /// implementation does not expose image streaming.
  static ImageFormatGroup preferredImageFormatGroup(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.android => ImageFormatGroup.nv21,
        TargetPlatform.iOS => ImageFormatGroup.bgra8888,
        _ => ImageFormatGroup.unknown,
      };

  static PoseFrame fromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    required TargetPlatform platform,
    DateTime? timestamp,
  }) {
    return PoseFrame(
      width: image.width,
      height: image.height,
      rotationDegrees: rotationDegreesFor(
        camera: camera,
        deviceOrientation: deviceOrientation,
        platform: platform,
      ),
      format: _poseFormat(image.format.group),
      planes: [
        for (final plane in image.planes)
          PoseFramePlane(
            bytes: plane.bytes,
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel,
          ),
      ],
      // The camera package materializes streamed plane bytes as Dart
      // Uint8Lists. Retaining those lists therefore does not retain a native
      // CameraImage/CameraX object and needs no extra copy in this adapter.
      // A future camera backend exposing borrowed native memory must copy at
      // this boundary before submitting frames asynchronously.
      timestamp: timestamp ?? DateTime.now(),
      isMirrored: false,
      cameraFacing: cameraFacingFor(camera.lensDirection),
    );
  }

  /// Clockwise rotation needed to interpret the raw image upright.
  ///
  /// Android combines sensor orientation with current device orientation and
  /// lens direction. iOS already reports frames in the sensor orientation used
  /// by the camera plugin's image stream contract.
  static int rotationDegreesFor({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    required TargetPlatform platform,
  }) {
    final sensorOrientation = camera.sensorOrientation % 360;
    if (platform != TargetPlatform.android) {
      return _normalizeRightAngle(sensorOrientation);
    }

    final deviceDegrees = _orientationDegrees[deviceOrientation] ?? 0;
    final rotation = camera.lensDirection == CameraLensDirection.front
        ? sensorOrientation + deviceDegrees
        : sensorOrientation - deviceDegrees;
    return _normalizeRightAngle(rotation);
  }

  static PoseCameraFacing cameraFacingFor(CameraLensDirection direction) =>
      switch (direction) {
        CameraLensDirection.front => PoseCameraFacing.front,
        CameraLensDirection.back => PoseCameraFacing.back,
        CameraLensDirection.external => PoseCameraFacing.external,
      };

  static PoseFrameFormat _poseFormat(ImageFormatGroup format) => switch (format) {
        ImageFormatGroup.yuv420 => PoseFrameFormat.yuv420,
        ImageFormatGroup.nv21 => PoseFrameFormat.nv21,
        ImageFormatGroup.bgra8888 => PoseFrameFormat.bgra8888,
        ImageFormatGroup.jpeg => PoseFrameFormat.jpeg,
        _ => PoseFrameFormat.unknown,
      };

  static int _normalizeRightAngle(int degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    if (normalized == 0 ||
        normalized == 90 ||
        normalized == 180 ||
        normalized == 270) {
      return normalized;
    }
    throw ArgumentError.value(
      degrees,
      'degrees',
      'Camera rotation must resolve to 0, 90, 180 or 270 degrees.',
    );
  }
}
