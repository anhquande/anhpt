# Pose preview coordinate transform

PR6 keeps canonical `BodyPose` data independent from camera presentation.
Renderers must not mirror, rotate, crop, or otherwise rewrite pose coordinates.

## Coordinate spaces

The view pipeline is explicit:

```text
BodyPose normalized source coordinates
        ↓
raw source image coordinates / frame metadata
        ↓
frame rotation (0°, 90°, 180°, 270°)
        ↓
oriented normalized camera coordinates
        ↓
CameraPreviewGeometry fit + centered source crop
        ↓
optional presentation-only horizontal mirror
        ↓
local Flutter camera viewport coordinates
```

`PoseViewTransform` owns source-size and rotation math.
`CameraPreviewGeometry` owns preview fit, crop, destination bounds, and mirroring.
`SkeletonPoseRenderer` receives only a point projector and therefore contains no
camera, platform, or pose-engine special cases.

## Current workout camera layout

`WorkoutCameraPreview` already centers the camera inside an `AspectRatio` that
matches the controller preview. `RealtimePoseView` therefore receives the
actual local camera surface, including Picture-in-Picture or responsive sizes.
Its production default is `BoxFit.fill` for that already-fitted inner surface.
`CameraPreviewGeometry` also supports `contain` and `cover` for camera surfaces
that own fitting themselves; both paths use the same source and destination
rectangles for camera placement and pose projection.

The geometry is rebuilt from current layout constraints, so window resizing,
orientation changes, and PiP size changes cannot reuse a stale viewport size.

## Rotation and mirroring

Quarter-turn rotation comes only from `PoseFrameMetadata.rotationDegrees`.
Screen width/height is never used to guess rotation.

The existing AnhPT camera surface explicitly mirrors its front-camera preview.
The pose view reproduces that presentation mirror only after rotation and
fit/crop. Canonical `BodyPose` objects are never mutated, so future exercise
analysis continues to receive the original coordinates.

Estimator adapters remain responsible for converting engine-native landmark
conventions into AnhPT canonical normalized coordinates before creating a
`BodyPose`. View code must not compensate for an engine by name or type.

## Platform notes

- Android and iOS consume the rotation/facing metadata produced by the existing
  camera frame adapter; PR6 does not add a second camera pipeline.
- Windows keeps camera preview and responsive geometry support. The current
  camera plugin path does not provide the live image stream required by the
  pose estimator, so live skeleton inference remains unavailable there until
  that camera limitation is addressed separately.
- If a physical-device overlay is still wrong, diagnose rotation, mirror,
  preview fit/crop, source coordinate convention, then estimator-adapter
  mapping. Do not add unexplained pixel offsets.

## Debug rendering

`PoseRenderDebugConfig` is disabled by default. It can optionally draw viewport
and preview bounds, center lines, and canonical joint coordinates to isolate
mapping errors without adding a developer settings screen.
