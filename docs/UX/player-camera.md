# Workout Player and Camera UX

## Player priority

The Player is the most attention-sensitive surface in AnhPT. The user should understand the current movement, remaining time, next step, coach guidance, demonstration, and camera view with minimal interaction.

## Stable layout

Major visual regions should remain stable across step transitions. Do not remove the demonstration region simply because the current step has no media. Use a neutral fallback visual instead.

Avoid UI reflow that moves Pause/Resume or other session-critical controls between steps.

## Camera lifecycle

Camera is session-scoped, not step-scoped.

Once enabled:

- keep the same camera stream alive across step changes,
- do not recreate the camera when demonstration content changes,
- stop it only when explicitly disabled, the user leaves the Player, or the workout ends.

This prevents visible flashing and avoids unnecessary hardware reinitialization.

## Camera aspect ratio

Preserve the source aspect ratio. Prefer a sensible preview container such as 4:3 or 16:9 depending on the camera stream and available space.

Never stretch camera frames to arbitrary dimensions. Use fit/crop/letterbox behavior where necessary while preserving proportions.

## Supported presentation modes

The Player may expose these layout modes:

1. Demonstration main + camera Picture-in-Picture.
2. Camera main + demonstration Picture-in-Picture.
3. Side-by-side/comparison mode where both receive meaningful space.

Changing layout must not restart the camera stream.

## Missing demonstration

When a step has no demonstration media:

- keep the demonstration surface,
- show the defined default/fallback visual,
- preserve PiP placement and player geometry,
- do not treat missing media as an error that blocks progression.

## Demonstration behavior

- static image remains visible,
- GIF continues animating,
- video loops muted,
- video pauses/resumes with the workout session,
- unsupported or missing media degrades to fallback content.

## Session states

### Ready/countdown

Show `READY` and a prominent countdown. Camera/media layout may already be visible so the user can position themselves before the first movement.

### Running

Show current step, remaining time, progress, next step, and Pause clearly.

### Finishing guide

If the timer reaches zero before protected speech finishes, keep the current step visible at `00:00` and show a waiting state such as `FINISHING GUIDE`.

### Paused

Show an unmistakable `PAUSED` state. Preserve camera and demonstration geometry; pause demonstration video while keeping the camera preview available where supported.

### Completed

Show completion summary and a safe exit path. Release session resources when leaving/completing according to platform lifecycle.

## Timer and voice rule

A step advances only after both configured time and protected announcement have completed. The visible timer remains authoritative for step duration.

## Camera controls

Camera on/off and layout switching are session-relevant controls and may be available in the Player. Keep them compact so they do not compete with Pause/Resume.

If camera permission or device availability fails, show concise feedback and continue the workout without camera.
