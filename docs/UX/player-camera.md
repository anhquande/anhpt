# Workout Player and Camera UX

## Player priority

The Player is the most attention-sensitive surface in AnhPT. The demonstration/camera stage is the primary surface. The user should understand the current movement, remaining time, overall workout position, next step, coach guidance, demonstration, and camera view with minimal interaction.

## Focus-mode hierarchy

During an active workout:

- reserve most usable viewport space for demonstration/camera media;
- let media extend to the top of the Player safe area;
- render progress, title, sound, display-mode controls, and timer/state as overlays on the media stage rather than separate rows;
- do not show background-music title/status or a persistent volume slider;
- expose one speaker icon that toggles workout sound on/off;
- keep long instructions and secondary metadata out of the persistent running layout.

## Overall progress

Place overall workout progress as a top overlay, similar to a video player timeline:

- thin progress track;
- small playhead/position indicator;
- elapsed workout position and total configured workout duration nearby;
- the playhead is display-only for now and is not freely seekable.

Manual next/previous navigation updates this overall position to the selected resolved runtime step.

## Stable layout

Major visual regions should remain stable across step transitions. Do not remove the demonstration region simply because the current step has no media. Use a neutral fallback visual instead.

Do not reflow the media stage when changing step, pausing, resuming, or switching video display mode.

## Direct media interaction

The media stage itself is the primary pause/resume control:

- tap/click the center media area to toggle workout Pause/Resume;
- briefly show a large play/pause feedback icon, then fade it away;
- do not reserve permanent layout height for a large Pause/Resume button;
- keyboard users can use Space/Enter.

Vertical navigation follows a paged timeline model:

- swipe up: next resolved runtime step;
- swipe down: previous resolved runtime step;
- one deliberate swipe moves at most one logical step;
- use a threshold so normal taps do not accidentally navigate;
- keyboard users can use Up/Down arrows;
- tapping the upcoming-step preview is also a next-step alternative.

Manual navigation must safely coordinate timer, TTS/recorded guidance, demonstration playback, and runtime repeat ordering.

## Next-step preview

The next step is preparation-critical and remains visible at the bottom of the Player.

Do not add a `NEXT` heading. Separate current content from the upcoming item with a thin separator and a small amount of whitespace, similar to adjacent items in a vertical social feed.

The upcoming item should contain:

- demonstration thumbnail or fallback thumbnail;
- step name;
- compact duration/repetition metadata when useful.

This preview visually teaches that more workout content exists below and supports swipe-up navigation.

## Camera lifecycle

Camera is session-scoped, not step-scoped.

Once enabled:

- keep the same camera stream alive across step changes;
- do not recreate the camera when demonstration content changes;
- do not restart it when switching between camera-enabled display modes;
- stop it when `Demonstration only` is selected, the user leaves the Player, or the workout ends.

This prevents visible flashing and avoids unnecessary hardware reinitialization.

## Camera aspect ratio

Preserve the source aspect ratio. Prefer a sensible preview container such as 4:3 or 16:9 depending on the camera stream and available space.

Never stretch camera frames to arbitrary dimensions. Use fit/crop/letterbox behavior where necessary while preserving proportions.

## Video display modes

Use one grid-style `Video layout` control for both camera enable/disable and layout selection. Do not expose a separate camera on/off button in the normal Player overlay.

The popup contains visual thumbnails and these modes:

1. `Demonstration only` — camera off.
2. `Demo main / Camera PiP` — camera on.
3. `Camera main / Demo PiP` — camera on.
4. `Split` — camera on.
5. `Overlay` — camera on.

Selecting `Demonstration only` stops/disables the camera for the session view. Selecting any camera-enabled mode automatically enables the camera if needed. If the camera is already running, changing between camera-enabled modes must reuse the same stream and must not restart the timer, TTS, or demonstration playback.

The current mode is visibly selected in the popup, and every option includes a compact layout illustration so the user can understand the result before selecting it.

## Missing demonstration

When a step has no demonstration media:

- keep the demonstration surface;
- show the defined default/fallback visual;
- preserve PiP placement and player geometry;
- do not treat missing media as an error that blocks progression.

## Demonstration behavior

- static image remains visible;
- GIF continues animating;
- video loops muted;
- video pauses/resumes with the workout session;
- unsupported or missing media degrades to fallback content.

## Session states

### Ready/countdown

Show `READY` and countdown as an overlay on the stable media stage. Camera/media layout may already be visible so the user can position themselves before the first movement.

### Running

Show current step and remaining time as overlays while preserving maximum media space. Overall progress remains overlaid at the top and upcoming-step preview remains below the media stage.

### Finishing guide

If the timer reaches zero before protected speech finishes, keep the current step visible at `00:00` and show `FINISHING GUIDE` in the same timer/state overlay region.

### Paused

Show an unmistakable `PAUSED` state using the same overlay region. Preserve camera and demonstration geometry; pause demonstration video while keeping the camera preview available where supported.

### Completed

Show completion summary and a safe exit path. Release session resources when leaving/completing according to platform lifecycle.

## Timer and voice rule

A step advances only after both configured time and protected announcement have completed during normal playback. The visible remaining timer remains authoritative for the current step.

Manual step navigation intentionally changes the active resolved step and resets that step timer while cancelling/transitioning the previous step's guide safely.

## Sound control

Use one compact speaker icon instead of persistent music/volume UI. It toggles workout sound as one user-facing state, covering coach voice/audio and background music while preserving configured volume levels for later unmute.

## Camera failure

If camera permission or device availability fails, show concise feedback and continue the workout with demonstration content rather than blocking the session.
