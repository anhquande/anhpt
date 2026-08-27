# AnhPT UX/UI Specification

**Version:** 0.2  
**Status:** Updated to match AnhPT v0.8.2.

## 1. Workout Creation

The default creation flow is the **Visual Workout Builder**. YAML editing remains available as an advanced option and import/export mechanism.

Workout Detail offers portable package export. Home offers package import. The
package contains YAML plus available local recording/music files; importing it
creates a new workout and isolated managed copies of its audio.

## 2. Builder Step Card

| Control | Behavior |
|---|---|
| Name | Required text. |
| Duration | Optional; blank means `0s`. |
| Guide | Optional multiline spoken instruction. |
| Voice timing | ON by default; OFF serializes `countdown: false`. |
| Move up/down | Reorder within the current group. |
| Duplicate | Clone the step including guide/countdown settings. |
| Delete | Remove the step. |

Builder-generated YAML should remain concise. In particular, `duration` may be omitted when it is `0s`, and `countdown` may be omitted when it is `true`.

Step IDs are normally hidden Builder metadata. Moving a step preserves its
explicit ID and recording. Duplicating a step creates a new implicit ID and does
not copy its recording. Builder save preserves tags, root recording, step
recordings, and background-music configuration.

## 3. Repeat Card

- Repeat count input.
- Add Step and Add Repeat actions.
- Nested repeat support.
- Move, duplicate, and delete controls.
- Spoken repeat number applies to the first step of each innermost repeat round.

## 4. Player Screen

| State | UI expectation |
|---|---|
| Start countdown | `READY` plus visible countdown. |
| Running | Current step name, visible remaining time, progress, next step, Pause action. |
| Timer finished while protected guide is still speaking | Show `00:00` and a waiting indicator such as `FINISHING GUIDE`; do not advance yet. |
| Paused | `PAUSED` indicator and Resume action. |
| Completed | Completion summary dialog. |

## 5. Timer + Voice Synchronization

At the beginning of each step, the visible timer and protected step announcement start in parallel.

A step transition occurs only when both conditions are complete:

```text
timerFinished == true
AND
announcementFinished == true
```

This means:

- If a 2-second step needs 5 seconds to speak, the UI reaches `00:00` after 2 seconds but remains on the step until speech completes.
- If speech takes 3 seconds and duration is 10 seconds, the step remains until the full 10 seconds have elapsed.
- A zero-duration instruction step displays `00:00` and remains visible only as long as its protected announcement requires.

## 6. Voice / Visual Consistency

The visible timer is authoritative for the configured step duration. Spoken timing can be scheduled slightly early to compensate for TTS latency, but the spoken value and displayed value should correspond perceptually. Protected step name/guide speech must not be cut off by a step transition.

## 7. Per-Step Voice Timing

When `countdown: false`, the player still:

- shows the timer,
- reads the step name,
- reads the guide,
- plays the transition cue,

but does not produce continuous, interval, or ending timing speech for that step.

## 8. Local Coach Recording MVP

The workout detail screen exposes a Windows-only recording card for the spoken
workout description. Each step row exposes a compact microphone action; opening
it shows a centered recording dialog for that step's name/guide cue without
permanently expanding the structure list. The dialog shows the step guide as a
read-along script when present. Both flows support start/stop, listen-back before
assignment, replacement, discard, and confirmed deletion. The UI states that
recordings remain on the device. Assignments are written to YAML as safe
relative paths. Permission denial, a missing file, or a
playback error must leave the corresponding device TTS available as fallback.

While capture is active, the recording card shows a live microphone-amplitude
waveform, elapsed recording time, and a prominent `REC` state. These indicators
appear only after the recorder confirms that capture has started.

Recording cards and dialogs stay focused on capture and review; they do not show
platform permission explanations or an Open microphone settings action. Settings
contains a concise Microphone access section with platform-appropriate guidance
and opens the system microphone/privacy page where the platform supports it.
Record controls are enabled only after microphone availability is confirmed.
While checking or unavailable, the disabled control exposes a short hover/focus
tooltip that points to Settings without adding static permission copy to the card.

After capture, an inline player replaces the separate Listen action. Save & use
recording and Discard share one action row below it. Save & use recording is
presented as a pending action, without a success/check indicator; assigned/saved
feedback appears only after persistence succeeds.

Step and workout-introduction recording surfaces share the same inline preview
player. A newly created draft and an assigned recording keep the player visible,
with play/pause, stop, elapsed/total time, and seeking when duration is known.
Starting a replacement, discarding, deleting, closing, or a playback/load error
stops and resets the single preview player so recordings never overlap.
For an assigned recording, Record replacement is placed at the left and Delete
recording at the right of one action row; narrow layouts wrap the actions without
clipping while preserving that order.

## 9. Offline Music Library

Settings exposes Music Library with mood filtering, preview, personal-track
import, rename/mood editing, and deletion. Bundled tracks cannot be deleted.
Deleting an assigned personal track warns with the affected workout count and
clears those assignments.

The Import action exposes a compact supported-format tooltip generated from the
same extension allowlist as the file picker. Imported MP3 files prefer the ID3
title; other files and missing metadata use a cleaned original filename, never
an internal generated track identifier.

The allowlist must reflect formats that the supported playback backend can open;
standalone `.opus` is not offered on Windows because the current native
`audioplayers` backend does not provide reliable Opus playback.

Selecting a track for preview opens an in-library mini player showing the track
name, elapsed/total time, play/pause/resume and stop controls, plus a seekable
progress slider for jumping to a chosen section.

Workout Detail exposes a compact Background music card with no-music/track
selection, enable toggle, preview, base-volume slider, and
Off/Gentle/Medium/High/Very high ducking. Gentle is the default. A missing or
unplayable assigned file produces
feedback but does not prevent the workout from starting.

After track selection, the workout-level preview uses the same visual player as
recording previews: play/pause, stop, elapsed/total time, and a seekable progress
slider in the same control order. Background music volume follows the player and
shows its current percentage; moving it updates active preview immediately and
persists the same base volume in workout YAML. Coach ducking and its Test action
share a two-column row when space permits and stack vertically on narrow layouts.

The Background music card also provides a user-initiated ducking test. It plays
the selected track together with a short bundled coach-voice sample, applies the
currently displayed base volume and ducking mode, and restores the base volume
when the sample completes, is stopped, or fails. The test remains available for
a selected track even when workout music is disabled.
