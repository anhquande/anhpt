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
