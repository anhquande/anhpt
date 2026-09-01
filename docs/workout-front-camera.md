# Workout Camera

Status: implementation in progress  
Date: 2026-09-01

## Goal

During a workout, AnhPT can show the exerciser's live camera image together with the exercise demonstration. This acts as a mirror so the user can visually compare posture and movement with the instructor.

## Decisions from product discussion

1. On Android and iOS, AnhPT prefers the front-facing camera.
2. On Windows, AnhPT supports built-in and USB webcams. If multiple cameras are available, the user can switch between them while the workout is running.
3. A persistent preference controls whether the camera starts automatically when a workout begins. The user can still turn it on or off during the workout.
4. The first version is live preview only. AnhPT does not record or save workout camera video because recordings would consume substantial storage.
5. Camera preview remains available even when the current step has no demonstration media.
6. When demonstration media exists, the user can switch layout while the workout is running.
7. Four comparison layouts are supported:
   - Split: demonstration and user camera side by side.
   - Demo main / Camera PiP: demonstration is primary and the user's camera appears as a compact secondary view.
   - Camera main / Demo PiP: the user's live camera is primary and the demonstration appears as a compact secondary view.
   - Overlay: user camera and demonstration share the same area, with transparency used to make posture comparison easier.
8. The camera preview behaves like a mirror by default because that is the most natural feedback for exercising in front of a screen.
9. Once enabled, the workout camera should remain active continuously across step and layout changes until the user explicitly turns it off, the workout ends, or the app lifecycle requires the camera resource to be released.
10. Camera preview preserves the camera's native aspect ratio; it should never be stretched to fill a differently-shaped container. Letterboxing is preferred over distortion.

## Player UX

The workout player exposes a camera toggle. Turning the camera on requests camera permission when necessary. A denied or unavailable camera must not interrupt workout timing, voice guidance, demonstration playback, music, pause/resume, or workout completion.

When the camera is on and the step has demonstration media, a layout control lets the user choose Split, Demo main / Camera PiP, Camera main / Demo PiP, or Overlay without restarting the workout. When no demonstration is available, the live camera is displayed on its own and the selected comparison layout is retained for the next step that has demonstration media.

When more than one camera is detected, the live preview exposes a camera switch menu. Windows camera labels use the device names reported by the operating system so built-in and USB webcams can be distinguished.

## Settings

Settings includes a Workout Camera section with:

- Start workout camera automatically: on/off.
- Default comparison layout: Split / Demo main + Camera PiP / Camera main + Demo PiP / Overlay.

Preferences are local to the device. The initial safe default is camera auto-start off so installing or upgrading AnhPT never unexpectedly activates the camera.

## Privacy and storage

The V1 camera stream is preview-only:

- no recording;
- no snapshot capture;
- no upload;
- no workout-camera media persisted by AnhPT;
- camera audio capture is disabled.

Platform camera permission is required. Permission copy should explain that the camera is used to show the exerciser during workouts for form comparison.

## Platform behavior

### Android

Android uses the Flutter `camera` API and prefers a front-facing camera. The application declares `android.permission.CAMERA`.

### iOS

iOS uses the Flutter `camera` API and prefers a front-facing camera. An iOS target must include the required camera usage description before distribution.

### Windows

Windows is a supported V1 platform through `camera_windows`, the Windows implementation of the Flutter camera platform interface. AnhPT enumerates available camera devices, prefers a camera reported as front-facing when one exists, and otherwise falls back to the first available device. This fallback is important because Windows webcams are often reported as external or without a meaningful front/back concept.

If multiple cameras exist, the user can select another device from the camera preview. The camera is opened with audio disabled. Windows camera permission and privacy restrictions are handled as normal camera initialization failures and do not stop the workout.

### Unsupported platforms

Unsupported platforms degrade gracefully: the workout continues normally and camera controls are hidden or disabled as appropriate.

## Lifecycle and failure behavior

Camera initialization, no camera devices, permission denial, app lifecycle changes, camera switching, or preview errors must never stop the workout engine. The camera controller is released when the app becomes inactive and is initialized again when the app resumes while the feature is enabled.

Changing workout steps, demonstration media, or comparison layouts must not dispose or recreate the camera controller. The live camera is expected to remain continuous for the duration of the enabled workout-camera session.

The player shows a concise non-blocking error and allows retrying camera initialization. SessionEngine remains independent from the camera implementation.

## Dependencies

The implementation intentionally uses versions compatible with the project's Dart >=3.3 baseline:

- `camera: 0.11.0+2`
- `camera_windows: 0.2.6+1`

The Windows implementation is explicitly declared because `camera_windows` is not an endorsed dependency automatically pulled in by `camera`.

## Out of scope for V1

- Recording workout sessions.
- Saving clips or snapshots.
- Cloud upload/sync of camera footage.
- Automatic pose estimation or AI form scoring.
- Automatic comparison/scoring against the demonstration.

These can be considered later without changing the V1 privacy expectation that live preview is not recorded.

## Acceptance criteria

- Auto-start can be enabled or disabled and persists between launches.
- Default layout persists between launches.
- Camera can be toggled during an active workout.
- Android/iOS prefer the front-facing camera.
- Windows can use an available built-in or USB webcam.
- Windows users can switch cameras when multiple devices are present.
- Camera preview works independently of whether the step has demonstration media.
- Split, both Picture-in-Picture directions, and Overlay can be selected during a workout with demonstration media.
- Camera preview preserves native aspect ratio without stretching.
- Changing workout steps or comparison layouts does not restart the camera.
- Changing workout steps does not unnecessarily re-request camera permission or reset the chosen layout.
- No workout camera video or audio is saved.
- Camera failure does not alter SessionEngine timing or voice-guide behavior.
- Existing workout player behavior remains functional when camera is off.

## Future direction

The live comparison surface is intentionally structured so later versions can add pose landmarks, alignment guides, repetition recognition, or optional form analysis without coupling those features to SessionEngine.
