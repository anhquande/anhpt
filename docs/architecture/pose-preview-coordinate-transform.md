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

## Tracking profile updates

Parent timer/analysis rebuilds can construct fresh tracking requirement objects
with unchanged joint sets and confidence thresholds. RealtimePoseView compares
these values rather than object identity, preserving the displayed pose, EMA
history, feature history and tracking guidance between inference frames. A real
change to required joints or either confidence threshold still resets tracking.
This prevents Windows Stickman 2D from alternating between the avatar and the
empty-state icon on ordinary Player updates. Confidence filtering and genuine
tracking loss continue to apply.

Controller stream getters can also return equal but non-identical wrappers.
Subscription changes use stream equality, matching Flutter StreamBuilder, so
ordinary parent rebuilds do not resubscribe and clear the displayed pose. A
new source still cancels the old subscription and clears stale pose data.

## Stickman joint dropouts

The avatar has a presentation-only per-joint 300 ms hold at the renderer's 0.4
confidence threshold. A briefly missing/uncertain landmark reuses its most recent
confident position instead of immediately removing every connected limb. Each
joint expires independently; uncertain observations do not renew its lifetime.
Only joints explicitly missing/uncertain in the latest observation use this
300 ms expiry. Confident joints must not expire while awaiting the next result:
CPU inference can take longer than 300 ms. A separate two-second stream-silence
timer clears the avatar when inference genuinely stalls. This avoids whole-avatar
blanking at low but healthy inference rates, while keeping stale data bounded.
Stream/profile/mode changes and disposal clear this presentation history.
Canonical EMA, raw tracking confidence and exercise feature extraction never
consume held landmarks. Real sustained loss still removes the corresponding
limbs rather than displaying an indefinitely frozen avatar.
