# Workout Front Camera

Status: implementation-ready product specification  
Date: 2026-09-01

## Goal

During a workout, AnhPT can show the exerciser's live front-camera image together with the exercise demonstration. This acts as a mirror so the user can visually compare posture and movement with the instructor.

## Decisions from product discussion

1. The feature uses the phone's front camera.
2. A persistent preference controls whether the camera starts automatically when a workout begins. The user can still turn it on or off during the workout.
3. The first version is live preview only. AnhPT does not record or save workout camera video because recordings would consume substantial storage.
4. Camera preview remains available even when the current step has no demonstration media.
5. When demonstration media exists, the user can switch layout while the workout is running.
6. Three comparison layouts are supported:
   - Split: demonstration and user camera side by side.
   - Picture in Picture: demonstration is primary and the user's camera appears as a movable/compact secondary view where practical.
   - Overlay: user camera and demonstration share the same area, with transparency used to make posture comparison easier.
7. The camera preview should behave like a mirror by default because that is the most natural feedback for exercising in front of a screen.

## Player UX

The workout player exposes a camera toggle. Turning the camera on requests camera permission when necessary. A denied/unavailable camera must not interrupt workout timing, voice guidance, demonstration playback, music, pause/resume, or workout completion.

When the camera is on and the step has demonstration media, a layout control lets the user choose Split, Picture in Picture, or Overlay without restarting the workout. When no demonstration is available, the live camera is displayed on its own and the selected comparison layout is retained for the next step that has demonstration media.

The UI should keep the timer, step name, progress, pause/resume and end-workout controls usable in all layouts. On small portrait screens, comparison media may use the largest practical region while controls remain accessible.

## Settings

Settings includes a Workout Camera section with:

- Start camera automatically: on/off.
- Default comparison layout: Split / Picture in Picture / Overlay.

Preferences are local to the device. The initial safe default is camera auto-start off so installing/upgrading AnhPT never unexpectedly activates the camera.

## Privacy and storage

The V1 camera stream is preview-only:

- no recording;
- no snapshot capture;
- no upload;
- no workout-camera media persisted by AnhPT.

Platform camera permission is required. Permission copy should explain that the camera is used to show the exerciser during workouts for form comparison.

## Platform behavior

The feature is primarily for Android and iOS phones. Unsupported platforms must degrade gracefully: the workout continues normally and camera controls are hidden or disabled as appropriate.

Android requires CAMERA permission. iOS requires NSCameraUsageDescription. The implementation should prefer the front-facing camera and should not initialize audio capture as part of camera preview.

## Failure behavior

Camera initialization, missing front camera, permission denial, app lifecycle changes, or preview errors must never stop the workout engine. The player should show a concise non-blocking error and allow the user to continue without camera.

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
- Front-camera preview works independently of whether the step has demonstration media.
- Split, Picture in Picture and Overlay can be selected during a workout with demonstration media.
- Changing steps does not unnecessarily re-request camera permission or reset the chosen layout.
- No workout camera video is saved.
- Camera failure does not alter SessionEngine timing or voice-guide behavior.
- Existing workout player behavior remains functional when camera is off.

## Future direction

The live comparison surface is intentionally structured so later versions can add pose landmarks, alignment guides, repetition recognition, or optional form analysis without coupling those features to SessionEngine.