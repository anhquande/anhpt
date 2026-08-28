# AnhPT YAML Schema Specification

**Version:** 0.3
**Schema version:** 2
**Status:** YAML v2 with backward-compatible YAML v1 parsing.

## 1. Root Structure

| Field | Required | Default / Notes |
|---|---:|---|
| `version` | Yes | `2` for new files; legacy `1` remains accepted. |
| `name` | Yes | Workout name. |
| `description` | No | Empty string. |
| `tags` | No | Empty list. |
| `start_countdown` | No | `3s`. |
| `voice` | No | Defaults applied. |
| `feedback` | No | Defaults applied. |
| `audio` | No | Defaults applied. |
| `recording` | No | Safe relative path to the workout-introduction recording. |
| `background_music` | No | Selected track and playback settings. |
| `completion_action` | No | `none`; may be `shutdown_or_exit`. |
| `screen_off_after_start` | No | Disabled when omitted; positive duration such as `10s`. |
| `exercises` | No | Reusable exercise definitions referenced by steps. |
| `steps` | Yes | At least one step or repeat group. |

## 2. Step

| Field | Required | Default | Meaning |
|---|---:|---|---|
| `id` | No | Derived from `name` | Unique effective step identifier. |
| `name` | Yes | — | Spoken/displayed step name. |
| `duration` | No | `0s` | Timer duration; `0s` is valid. |
| `guide` | No | `null` | Additional spoken instruction, max 500 characters. |
| `countdown` | No | `true` | When false, disables timing voice for this step. |
| `recording` | No | `null` | Safe relative path to the step recording. |
| `exercise_id` | No | `null` | ID of an entry in root `exercises`. |

### Exercises and demonstration media

`exercises` is optional, so existing YAML v1/v2 workouts remain valid. Exercise
IDs are unique within the workout. A step may omit `exercise_id` for
instructions, rest, or steps without reusable movement media.

```yaml
exercises:
  - id: exercise_high_plank
    name: High Plank
    demo_media: media/high-plank-8f2c7a00.gif
```

`demo_media` normally uses a safe, readable relative path such as
`media/high-plank-8f2c7a00.gif`. It may resolve to a static image, animated GIF,
or video. The short hash suffix prevents name collisions while keeping the file
recognizable and editable. Full `sha256:` IDs and legacy `demo_video` remain
accepted for backward compatibility; when the referenced local asset is
available, the app normalizes them to readable `demo_media` paths when saved.

On platforms with application Documents storage, Builder saves mirror this
serialized document to `Documents/AnhPT/workouts/<workout-id>.yaml`. Therefore
recording assignments and demonstration references are visible in the local
YAML immediately after an edit. Media and recording binary data are not embedded
in YAML; package export remains the portable way to transfer the referenced
files together with the workout.

`step.id` is unique across the complete workout, including nested repeats.
Explicit IDs contain letters, numbers, and single hyphens and are at most 40
characters. When omitted, the effective ID is the lowercase, unaccented,
hyphenated form of `name`. Collisions receive `-2`, `-3`, and so on. Duplicate
explicit IDs are invalid. The Builder writes an explicit ID when a step owns a
recording, preserves it on move, and gives a duplicate a new implicit ID without
copying the recording.

## 3. Recording References

Root `recording` is the workout-introduction recording. Step `recording` is the
recording for that step's name/guide cue. Both are scalar strings; recording has
no language or nested metadata.

References must use `asset:` or a safe path relative to application-managed
storage. Absolute paths and `..` segments are invalid. Missing or unreadable
recordings fall back to device TTS and must not stall execution.

Builder-created recordings use a simplified form of the workout or step name,
for example `coach_recordings/nang-dau-goi.m4a`. If that name already exists,
the app appends `-2`, `-3`, and so on. Existing generated timestamp names are
renamed and their YAML references updated during local migration.

## 4. Background Music

| Field | Required | Default / Rules |
|---|---:|---|
| `source` | Yes | `asset:` reference or safe relative path. |
| `name` | No | Display name. |
| `enabled` | No | `true`. |
| `volume` | No | `0.35`; number from `0` to `1`. |
| `ducking` | No | `gentle`; `off`, `gentle`, `medium`, `high`, or `very_high`. |

Only the selected track is serialized; the local music library is not copied
into every workout. Missing music never blocks workout execution.

Browsed music keeps a filesystem-safe form of its original filename, for
example `music/Morning Flow.mp3`. Name collisions receive numeric suffixes such
as `Morning Flow-2.mp3`. Older generated `track_<timestamp>` and imported paths
are migrated to readable names, and their YAML `source` values are rewritten.

Portable export uses an `.anhpt.zip` package containing `workout.yaml` and all
available non-bundled referenced audio files. Import validates archive paths and
sizes, copies audio into an isolated application-managed folder, and rewrites
the YAML references. Bundled `asset:` audio is referenced but not copied.

## 5. Repeat Group

| Field | Required | Rules |
|---|---:|---|
| `repeat` | Yes | Integer from 1 to 10,000. |
| `steps` | Yes | Non-empty list; nesting depth maximum 10. |

## 6. Voice Configuration

| Field | Values / Default |
|---|---|
| `language` | `vi` or `en`; defaults to app preference. |
| `mode` | `continuous`, `interval`, `ending`, `combined`; default `combined`. |
| `announce_every` | Default `10s`. |
| `countdown_from` | Default `5s`. |
| `announce_step_name` | Default `true`. |
| `announce_start` | Default `true`. |
| `announce_finish` | Default `true`. |

## 7. Example

```yaml
version: 2
name: Quick Plank
recording: recordings/quick-plank-intro.m4a

background_music:
  source: music/focus-flow.mp3
  name: Focus Flow
  volume: 0.35

steps:
  - name: Chuẩn bị tư thế
    guide: Đặt khuỷu tay dưới vai.
    countdown: false

  - id: plank
    name: Plank
    duration: 20s
    recording: recordings/plank.m4a
```

## 8. Execution Semantics

- Missing `duration` means `0s`.
- `countdown: false` suppresses timing speech, not name, guide, cue, or timer.
- Nested repeats announce only the innermost repeat context.
- Timer and protected announcement start together.
- A step advances only when both timer and announcement are finished.
- Missing/unreadable recording or music never stalls workout progression.

## 9. Completion Action

`completion_action` is optional and defaults to `none`. With
`shutdown_or_exit`, a successfully completed workout shuts down Windows
immediately with force-close semantics or exits AnhPT on Android. It has no
effect for incomplete workouts, Web, or iOS. Because forced Windows shutdown
may discard unsaved work in other applications, Builder presents an explicit
warning beside this option.

## 10. Screen-off Action

`screen_off_after_start` is optional. When present, AnhPT schedules a display
power-off request from the moment the workout Player opens after Start. The
current Builder and Overview controls use `10s`. Windows turns off the monitor
through the native `SC_MONITORPOWER` system command; normal mouse or keyboard
activity can wake it again. The workout timer and audio continue running.

The field remains portable on Android, iOS, and Web, but those targets ignore
the action because ordinary applications cannot safely lock or power off the
device display without privileged device-management capabilities. The timer is
cancelled if the Player closes or the workout finishes before the delay.

## 11. Marketplace package metadata

Marketplace downloads use the same `.anhpt.zip` and YAML validation path as
manual import. A package may add a root `manifest.json` with `schemaVersion: 1`
and optional `workoutFile` (default `workout.yaml`). Package identity, version,
URL, and SHA-256 live in the bucket catalog rather than workout YAML. Existing
manifest-less packages remain valid.
