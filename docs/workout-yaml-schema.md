# AnhPT Workout YAML Schema

This document is the human-readable reference for the workout YAML accepted by AnhPT.

**Authoritative implementation:** `lib/services/workout_parser.dart`.

When this document and the parser disagree, the parser wins. Any schema change must update both the parser/tests and this document in the same PR.

## Schema version

```yaml
version: 2
```

Accepted values are `1` and `2`. New workouts should use `2`.

Unknown fields are rejected at every documented object level.

## Complete example

```yaml
version: 2

name: AnhPT Feature Demo
description: Short interactive workout demonstrating voice, camera, media, repeat and progress.

tags:
  - demo
  - beginner

start_countdown: 3s

voice:
  language: en
  timing:
    elapsed_time: false
    interval: true
    interval_every: 10s
    final_countdown: true
    countdown_from: 3s
  announce_step_name: true
  announce_start: true
  announce_finish: true

feedback:
  sound: beep
  haptic: medium

audio:
  ducking: medium

video:
  auto_enable: true
  layout: picture_in_picture
  camera: front

completion_action: none

background_music:
  source: media/music.mp3
  name: Demo music
  enabled: true
  volume: 0.35
  ducking: gentle

exercises:
  - id: squat
    name: Squat
    demo_media: media/squat.png

steps:
  - id: warmup
    name: Warm up
    duration: 15s
    countdown: false
    guide: Get ready.

  - id: squat-main
    name: Squat
    exercise_id: squat
    duration: 30s
    guide: Move at a comfortable pace.

  - repeat: 2
    steps:
      - name: Squat repeat
        exercise_id: squat
        duration: 20s
```

## Root fields

| Field | Type | Required | Default / validation |
| --- | --- | --- | --- |
| `version` | integer | yes | Must be `1` or `2` |
| `name` | string | yes | Non-empty, max 100 chars |
| `description` | string | no | Max 500 chars, may be empty |
| `tags` | list of strings | no | Max 20 tags, each max 30 chars |
| `start_countdown` | duration | no | Default `3s`, zero allowed |
| `voice` | object | no | See Voice |
| `feedback` | object | no | See Feedback |
| `audio` | object | no | See Audio |
| `completion_action` | enum | no | `none` or `shutdown_or_exit`; default `none` |
| `screen_off_after_start` | duration | no | If present, must be greater than `0s` |
| `recording` | source string | no | Safe relative path or `asset:` reference |
| `background_music` | object | no | See Background music |
| `video` | object | no | See Video |
| `exercises` | list | no | See Exercises |
| `steps` | list | yes | Must contain at least one step |

## Duration values

Duration fields are parsed by `DurationParser`. Existing workout files normally use values such as:

```yaml
10s
1m
1m30s
```

Use the same duration syntax already accepted by the app parser. `start_countdown` and `step.duration` may be zero where noted.

## Voice

Allowed fields:

```yaml
voice:
  language: en
  timing:
    elapsed_time: false
    interval: true
    interval_every: 10s
    final_countdown: true
    countdown_from: 5s
  announce_step_name: true
  announce_start: true
  announce_finish: true
```

### `voice.language`

Allowed values:

- `en`
- `vi`

If omitted, the app default voice language is used.

### `voice.timing`

| Field | Type | Default |
| --- | --- | --- |
| `elapsed_time` | boolean | `false` |
| `interval` | boolean | `true` |
| `interval_every` | duration | `10s` |
| `final_countdown` | boolean | `true` |
| `countdown_from` | duration | `5s` |

The following old/incorrect forms are **not valid**:

```yaml
voice:
  mode: combined
  announce_every: 10s
  countdown_from: 3s
```

`interval_every` and `countdown_from` belong under `voice.timing`.

## Feedback

```yaml
feedback:
  sound: beep
  haptic: medium
```

`feedback.sound` values:

- `beep`
- `bell`
- `click`
- `none`

Default: `beep`.

`feedback.haptic` values:

- `off`
- `light`
- `medium`
- `strong`

Default: `medium`.

## Audio

```yaml
audio:
  ducking: medium
```

Allowed `ducking` values:

- `off`
- `low`
- `medium`
- `high`

Default: `medium`.

## Video / workout camera

```yaml
video:
  auto_enable: true
  layout: picture_in_picture
  camera: front
```

| Field | Type | Allowed values / default |
| --- | --- | --- |
| `auto_enable` | boolean | default `false` |
| `layout` | enum | `split`, `picture_in_picture`, `camera_picture_in_picture`, `overlay`; default `picture_in_picture` |
| `camera` | enum | `front`, `back`; default `front` |

## Recording sources

The root `recording` field and step-level `recording` field accept a source string up to 500 chars.

Valid examples:

```yaml
recording: media/intro.mp3
recording: asset:audio/intro.mp3
```

Unsafe absolute paths and traversal are rejected, including Windows drive paths, paths starting with `/`, and paths containing `..` segments.

## Background music

```yaml
background_music:
  source: media/music.mp3
  name: Demo music
  enabled: true
  volume: 0.35
  ducking: gentle
```

| Field | Type | Required | Validation/default |
| --- | --- | --- | --- |
| `source` | string | yes | Safe source, max 500 chars |
| `name` | string | no | Max 100 chars |
| `enabled` | boolean | no | Default `true` |
| `volume` | number | no | `0.0` to `1.0`, default `0.35` |
| `ducking` | enum | no | `off`, `gentle`, `medium`, `high`, `very_high`; default `gentle` |

## Exercises and demonstration media

```yaml
exercises:
  - id: squat
    name: Squat
    demo_media: media/squat.png
```

Allowed exercise fields:

- `id`
- `name`
- `demo_media`
- `demo_video`

Rules:

- `id` is required and unique.
- `name` is required, non-empty, max 100 chars.
- `demo_media` and `demo_video` are aliases at parser level, but an exercise must not contain both.
- Media references may be safe relative paths, `asset:` references, or SHA-256 media IDs such as `sha256:<64 hex chars>`.
- Exercise IDs may contain letters, numbers, hyphens and underscores, with separators only between alphanumeric groups.

Example video reference:

```yaml
exercises:
  - id: plank
    name: High Plank
    demo_video: media/high-plank.mp4
```

## Timed steps

```yaml
steps:
  - id: squat-main
    name: Squat
    duration: 30s
    guide: Keep your knees aligned with your toes.
    countdown: true
    recording: media/squat-coach.mp3
    exercise_id: squat
```

Allowed fields:

- `id`
- `name`
- `duration`
- `guide`
- `countdown`
- `recording`
- `exercise_id`

Rules and defaults:

- `name` is required, non-empty, max 100 chars.
- `duration` defaults to `0s`; zero is allowed.
- `guide` is optional, max 500 chars.
- `countdown` defaults to `true`.
- `id` is optional. If omitted, the app derives a stable slug-like ID from the name and avoids collisions.
- Explicit `step.id` must be unique case-insensitively, max 40 chars, and contain only letters, numbers and single hyphens.
- `exercise_id`, when present, must reference an existing exercise.
- `exercise_id` accepts letters, numbers, hyphens and underscores.

## Repeat groups

```yaml
steps:
  - repeat: 3
    steps:
      - name: Squat
        duration: 20s
      - name: Rest
        duration: 10s
        countdown: false
```

A repeat object may contain only:

- `repeat`
- `steps`

Rules:

- `repeat` must be an integer from `1` to `10000`.
- Nested `steps` must be non-empty.
- Maximum repeat nesting depth is 10.

## Global validation limits

A workout is rejected when any of these limits are exceeded:

- Total expanded workout duration greater than 24 hours.
- More than 100,000 effective steps after repeats are expanded.
- More than 20 tags.
- Repeat nesting deeper than 10 levels.
- Unknown fields in schema-controlled objects.
- Duplicate explicit step IDs.
- Duplicate exercise IDs.
- Missing `exercise_id` targets.

## Compatibility and change policy

1. `lib/services/workout_parser.dart` is the runtime authority.
2. New YAML fields must be added to the parser allow-list and implemented before bucket workouts use them.
3. Update this document in the same PR as every parser/schema change.
4. Add or update parser tests for every new field, enum value or validation rule.
5. Official bucket workouts must target fields supported by their declared `minAppVersion`.
6. Before publishing an official bucket release, validate every `workout.yaml` against the app parser/schema version it targets.

## Bucket packages

A bucket package typically contains a `manifest.json`, `workout.yaml`, and optional media files. The workout YAML itself must follow this schema. Package versioning and `minAppVersion` belong to the bucket manifest, not to `workout.yaml`.

Example manifest:

```json
{
  "schemaVersion": 1,
  "workoutFile": "workout.yaml",
  "id": "anhpt-feature-demo",
  "version": "1.0.1",
  "minAppVersion": "0.14.0"
}
```
