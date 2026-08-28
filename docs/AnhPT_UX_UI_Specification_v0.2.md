# AnhPT UX/UI Specification

**Version:** 0.2  
**Status:** Updated to match AnhPT v0.8.2.

## 1. Workout Creation

The default creation flow is the **Visual Workout Builder**. YAML editing remains available as an advanced option and import/export mechanism.

Workout Detail offers portable package export. Home offers package import. The
package contains YAML plus available local recording/music files; importing it
creates a new workout and isolated managed copies of its audio.

Home exposes `Browse workouts` beside the primary creation journey; installing
catalog content never requires navigating through Settings. `Browse Workouts`
keeps a search field pinned below its app bar and searches workout name,
description, tags, author, and source with case- and Vietnamese-accent-
insensitive matching after a short debounce. Status/source filters, name sort,
result count, direct Install/Update states, and an Open action after successful
installation support larger catalogs. Settings contains only `Workout sources`
for technical source management.
Browse Workouts follows the Home visual system: a standard-height app bar, the
same inset search field, a counted section header with compact filter/sort icon
menus, and lightweight cards with matching padding, typography, one-line
descriptions, muted metadata, and tonal actions. Tags are compact inline
metadata rather than large chips.

Home uses a restrained `My Workouts` app bar with only Settings visible.
`New workout` and `Browse workouts` remain visible as the frequent actions.
The less frequent `Import package` and `Import YAML` actions live in an adjacent
three-dot overflow menu. The redundant greeting and floating creation button
are omitted. A local accent-insensitive search filters name,
description, and tags. Favorites and all other workouts use counted lightweight
sections, while compact cards prioritize title, optional one-line description,
metadata, favorite, and a tonal Play action. Bucket-installed workout cards also
show a compact `From <source>` line, while locally created workouts omit it.
When a bucket workout has been renamed, its card adds a compact
`Originally “<name>”` line.

Workout Overview uses one persistent top app bar that remains visible while the
content scrolls. It shows the ellipsized workout title on the left, the primary
`Start` action on the right, and an adjacent three-dot menu. The menu contains
Edit, Duplicate, Copy YAML, Edit YAML, and Export package; these actions are not
repeated in the scrolling body. A separated destructive `Delete workout` action
opens a confirmation dialog before removing the local workout. Deleting one
bucket variant removes only that local variant and its provenance record.

Builder offers an optional `Shut down or exit when complete` toggle with a
forced-shutdown warning. For opted-in workouts, successful completion shuts
Windows down immediately without another prompt or exits Android. Incomplete
sessions, Web, and iOS keep the normal completion flow.
The control appears as an always-visible `After workout` card in Builder rather
than inside Voice settings. Workout Overview also always shows an `After
workout` switch; changing it persists immediately to the workout YAML so
Builder, YAML editor, and Overview remain synchronized.

For a workout installed from a bucket, Overview shows a quiet `From <source>`
origin line. Its action menu includes `View source`, which reveals the source
name and stable catalog workout ID. Renaming the workout does not change this
origin metadata. If the current name differs, Overview also shows the original
catalog name; unchanged names do not repeat it.

Below the sticky header, a non-empty description uses a subtle notes icon,
muted body color, and comfortable line height. It collapses after three lines
with More/Less controls. Tags appear as compact, borderless secondary-color
chips and are hidden as a group when empty. Duration, step count, language, and
voice mode are presented as lightweight icon/text metadata rather than chips,
so technical facts do not compete visually with tags.

Overview content is divided into `Introduction`, `Music`, and `Structure` tabs;
`Structure` is selected initially. The description, tags, and metadata remain a
shared summary above the tabs. The tab bar pins below the persistent app bar
when the summary scrolls away, while each tab preserves its own scroll position.
Horizontal swipe navigation is disabled so it cannot conflict with the Music
volume slider.

The Introduction tab uses the same compact recording pattern as a Structure
step. An unassigned cue shows a microphone action; an assigned cue replaces it
with the shared Play/Pause mini player whose Manage action appears on hover or
touch. Recording, replacement, and deletion remain in the full dialog opened
from that compact control.

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
| Demonstration media | Choose, replace, or unlink a reusable image, animation, or video. |

### Exercise demonstration media MVP

The Step card may attach a JPG, JPEG, PNG, WebP, GIF, MP4, MOV, or WebM file up
to 20 MB. AnhPT creates
an internal Exercise when necessary and stores identical selected content once
in the shared Media Library. Unlink removes only the reference.

Overview and Builder show the same adjacent per-step icon actions: microphone
for coach recording and folder/media for browsing or replacing demonstration
files. The media action is an icon button with an explanatory tooltip, not a
text button. No redundant empty-state heading or format-description copy is
shown. A new unsaved workout must be saved before step recording can start.
Step rows do not show a leading timer icon: the explicit duration field/value
already communicates timing, so the step name remains the primary visual cue.

When a step recording is assigned, both Overview and Builder show a compact
inline audio player in the step's right-side action area. Its management dialog
provides delete and record-again actions. Delete removes the local file and YAML
assignment, after which device TTS resumes as the fallback.

The collapsed mini player shows only Play/Pause. Pointer hover reveals one
`Manage recording` action with an audio-settings icon; it opens the full
recording dialog where delete and record-again controls live. Leaving the player
hides the management action. On touch devices, tapping the mini player reveals
the action temporarily so the same capability remains accessible without hover.
When a recording exists, this Play/Manage cluster replaces the standalone
`Edit step recording` microphone and remains in the step's right-side action
area immediately beside the demonstration-media button; no duplicate player is
shown below the step.

When no demonstration is attached, the existing Browse icon remains beside the
audio controls. Once attached, Browse is replaced by a rounded 32×32 visual
thumbnail centered in a 40×40 accessible tap target, followed by 8 px spacing
before the duration/control to its right. It remains in the Browse action's
position; no large thumbnail or attached-state heading is shown
below the step. Tapping the thumbnail opens a large preview dialog with Close,
Delete demonstration, and Replace demonstration actions. Delete only unlinks
the shared media; it does not remove the physical shared asset.

The empty-state Browse action uses `add_photo_alternate_outlined` to communicate
adding visual demonstration media. Replace inside the preview dialog retains a
folder icon to distinguish replacing a file from the initial add action.

During a workout, a static image remains visible, an animated GIF animates, and
a video is muted and looped independently of the timer and voice guide. Video
pauses/resumes with the session. Missing or unsupported media is non-blocking.
Camera capture, trimming, and compression are later phases.

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

## Workout Buckets

- Settings links to a focused source manager.
- A source can be added by name and public HTTPS catalog URL, enabled/disabled,
  refreshed, or removed without deleting installed workouts.
- The catalog shows package metadata and installed/update state.
- An installed entry exposes `Add another`, creating an independent local
  variant with the same source attribution. Duplicate local names receive the
  first available suffix, such as `Workout 2`, `Workout 3`, and `Workout 4`.
- Updating asks to keep the local workout, install as a copy, or replace it.
- Loading, cached-offline, empty, validation, download, and checksum failures are
  explicit and do not alter existing workouts.
# AnhPT UX/UI Specification
