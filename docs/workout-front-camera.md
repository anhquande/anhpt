# Workout Camera

Status: implementation in progress  
Date: 2026-09-10

## Goal

During a workout, AnhPT can show the exerciser's live camera image together with the exercise demonstration. This acts as a mirror so the user can visually compare posture and movement with the instructor.

AnhPT can also process the same live camera session through the engine-independent pose pipeline and visualize the resulting canonical `BodyPose` as a diagnostic skeleton. Pose visualization is local presentation only; it does not change `SessionEngine` or workout YAML semantics.

## Decisions from product discussion

1. On Android and iOS, AnhPT prefers the front-facing camera.
2. On Windows, AnhPT supports built-in and USB webcams. If multiple cameras are available, the user can switch between them while the workout is running.
3. A persistent preference controls whether the camera starts automatically when a workout begins. The user can still turn it on or off during the workout.
4. The workout camera does not record or save camera video. Where image streaming is supported, the existing camera session may also feed the pose pipeline; no second camera is opened.
5. Camera preview remains available even when the current step has no demonstration media.
6. The selected comparison layout remains visually stable across all workout steps. If a step has no demonstration media, AnhPT renders a default demonstration placeholder in the demonstration slot instead of removing that slot or changing the layout.
7. Four comparison layouts are supported:
   - Split: demonstration and user camera side by side.
   - Demo main / Camera PiP: demonstration is primary and the user's camera appears as a compact secondary view.
   - Camera main / Demo PiP: the user's live camera is primary and the demonstration appears as a compact secondary view.
   - Overlay: user camera and demonstration share the same area, with transparency used to make posture comparison easier.
8. The camera preview behaves like a mirror by default because that is the most natural feedback for exercising in front of a screen.
9. Once enabled, the workout camera should remain active continuously across step and layout changes until the user explicitly turns it off, the workout ends, or the app lifecycle requires the camera resource to be released.
10. Camera preview preserves the camera's native aspect ratio; it should never be stretched to fill a differently-shaped container. Letterboxing is preferred over distortion.
11. Pose rendering consumes only AnhPT canonical `BodyPose`, `PosePoint`, and `BodyJoint` values. Concrete estimator landmarks never reach the rendering layer.

## Player UX

The workout player exposes a camera toggle. Turning the camera on requests camera permission when necessary. A denied or unavailable camera must not interrupt workout timing, voice guidance, demonstration playback, music, pause/resume, or workout completion.

When the camera is on, a layout control lets the user choose Split, Demo main / Camera PiP, Camera main / Demo PiP, or Overlay without restarting the workout. The same layout is kept when the workout advances to another step. If that step has no demonstration media, the demonstration slot shows a default placeholder labeled `No demonstration for this step`. When a later step has media again, that media replaces the placeholder in the same slot without changing the selected layout.

When more than one camera is detected, the live preview exposes a camera switch menu. Windows camera labels use the device names reported by the operating system so built-in and USB webcams can be distinguished.

### Pose visualization

The camera surface exposes a small runtime-only pose-view selector with three modes:

- `Camera`: existing live-camera behavior only.
- `Skeleton`: hide the raw preview and show the canonical skeleton on a neutral background.
- `Camera + Skeleton`: show the skeleton over the existing preview.

The initial mode is `Camera` so existing camera behavior remains unchanged until the user opts into pose visualization. The mode is not persisted in workout YAML or settings yet.

`PosePipelineResult` supplies the realtime canonical poses. PR5 selects one primary pose using the highest aggregate `BodyPose.confidence`, then passes that pose through `PosePainter` to `SkeletonPoseRenderer`. Missing or low-confidence joints are skipped without blocking the workout. The initial rendering threshold is `0.4` and applies only to visualization.

Front-camera mirroring is presentation-only. Canonical `BodyPose` data remains unmirrored for future exercise analysis. PR5 only applies the obvious front-preview mirror and keeps coordinate transformation isolated so PR6 can correct sensor rotation, crop, preview aspect mapping, and orientation precisely.

## Settings

Settings includes a Workout Camera section with:

- Start workout camera automatically: on/off.
- Default comparison layout: Split / Demo main + Camera PiP / Camera main + Demo PiP / Overlay.

Preferences are local to the device. The initial safe default is camera auto-start off so installing or upgrading AnhPT never unexpectedly activates the camera.

Pose visualization mode is currently session/runtime-only and is intentionally not added to persistent settings yet.

## Privacy and storage

The workout camera stream is not recorded:

- no recording;
- no snapshot capture;
- no upload;
- no workout-camera media persisted by AnhPT;
- camera audio capture is disabled;
- canonical realtime pose results used for the skeleton are not persisted by PR5.

Platform camera permission is required. Permission copy should explain that the camera is used to show the exerciser during workouts for form comparison.

## Platform behavior

### Android

Android uses the Flutter `camera` API and prefers a front-facing camera. The application declares `android.permission.CAMERA`. Where image streaming is available, the same controller also feeds the pose pipeline.

### iOS

iOS uses the Flutter `camera` API and prefers a front-facing camera. An iOS target must include the required camera usage description before distribution. Where image streaming is available, the same controller also feeds the pose pipeline.

### Windows

Windows is a supported camera-preview platform through `camera_windows`, the Windows implementation of the Flutter camera platform interface. AnhPT enumerates available camera devices, prefers a camera reported as front-facing when one exists, and otherwise falls back to the first available device. This fallback is important because Windows webcams are often reported as external or without a meaningful front/back concept.

If multiple cameras exist, the user can select another device from the camera preview. The camera is opened with audio disabled. Windows camera permission and privacy restrictions are handled as normal camera initialization failures and do not stop the workout.

The current Windows camera implementation does not provide the image stream required by the pose pipeline, so camera preview continues to work there while realtime skeleton inference is unavailable until the backend can stream frames.

### Unsupported platforms

Unsupported platforms degrade gracefully: the workout continues normally and camera controls are hidden or disabled as appropriate.

## Lifecycle and failure behavior

Camera initialization, no camera devices, permission denial, app lifecycle changes, camera switching, preview errors, or pose-estimation failures must never stop the workout engine. The camera controller is released when the app becomes inactive and is initialized again when the app resumes while the feature is enabled.

Changing workout steps, demonstration media, comparison layouts, or pose visualization mode must not dispose or recreate the camera controller. The live camera is expected to remain continuous for the duration of the enabled workout-camera session.

The player shows a concise non-blocking camera error and allows retrying camera initialization. Pose pipeline errors are non-fatal and the current camera surface remains usable. `SessionEngine` remains independent from both camera and pose implementation details.

## Dependencies

The implementation intentionally uses versions compatible with the project's Dart >=3.3 baseline:

- `camera: 0.11.0+2`
- `camera_windows: 0.2.6+1`

The Windows implementation is explicitly declared because `camera_windows` is not an endorsed dependency automatically pulled in by `camera`.

## Out of scope for the current pose visualization

- Recording workout sessions.
- Saving clips or snapshots.
- Cloud upload/sync of camera footage.
- Pose smoothing or temporal filters.
- Tracking states such as no-person/partial-body/lost-tracking.
- Joint-angle or pose-feature extraction.
- Exercise recognition, rep counting, or form scoring.
- Voice feedback based on pose analysis.
- Avatar/character rendering.
- Workout YAML pose configuration.
- Engine-selection UI or additional estimator implementations.

## Acceptance criteria

- Auto-start can be enabled or disabled and persists between launches.
- Default layout persists between launches.
- Camera can be toggled during an active workout.
- Android/iOS prefer the front-facing camera.
- Windows can use an available built-in or USB webcam.
- Windows users can switch cameras when multiple devices are present.
- Camera preview works independently of whether the step has demonstration media.
- Split, both Picture-in-Picture directions, and Overlay can be selected during a workout.
- The selected layout remains unchanged when stepping between exercises with and without demonstration media.
- A default demonstration placeholder occupies the demonstration slot when no media is assigned.
- Camera preview preserves native aspect ratio without stretching.
- Changing workout steps, comparison layouts, or pose view mode does not restart the camera.
- Changing workout steps does not unnecessarily re-request camera permission or reset the chosen layout.
- No workout camera video or audio is saved.
- Camera failure does not alter `SessionEngine` timing or voice-guide behavior.
- Existing workout player behavior remains functional when camera is off.
- `Camera`, `Skeleton`, and `Camera + Skeleton` can be selected during a supported pose-camera session.
- Skeleton rendering consumes only canonical pose types and safely ignores missing/low-confidence joints.
- `Camera` mode preserves the pre-PR5 camera-only behavior.
- Empty pose results do not display a blocking dialog.

## Next coordinate work (PR6)

PR5 intentionally keeps the renderer raw so inference and mapping problems remain visible. PR6 should validate and correct the view transform for:

- portrait and landscape orientation;
- camera sensor rotation;
- preview crop/letterboxing geometry;
- front-camera mirroring;
- source-image versus preview aspect ratio.

Those corrections should remain in the presentation transform and must not mutate canonical `BodyPose` coordinates.
