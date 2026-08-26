# AnhPT YAML Schema Specification

**Version:** 0.2  
**Schema version:** 1  
**Status:** Backward-compatible extension of the existing schema.

## 1. Root Structure

| Field | Required | Default / Notes |
|---|---:|---|
| `version` | Yes | Must be `1`. |
| `name` | Yes | Workout name. |
| `description` | No | Empty string. |
| `tags` | No | Empty list. |
| `start_countdown` | No | `3s`. |
| `voice` | No | Defaults applied. |
| `feedback` | No | Defaults applied. |
| `audio` | No | Defaults applied. |
| `steps` | Yes | At least one step or repeat group. |

## 2. Step

| Field | Required | Default | Meaning |
|---|---:|---|---|
| `name` | Yes | — | Spoken/displayed step name. |
| `duration` | No | `0s` | Timer duration. `0s` is valid. |
| `guide` | No | `null` | Additional spoken instruction, max 500 characters. |
| `countdown` | No | `true` | When `false`, disables all timing voice for this step. |

A missing `duration` is equivalent to `duration: 0s`.

## 3. Repeat Group

| Field | Required | Rules |
|---|---:|---|
| `repeat` | Yes | Integer from 1 to 10,000. |
| `steps` | Yes | Non-empty list; nesting depth maximum 10. |

## 4. Voice Configuration

| Field | Values / Default |
|---|---|
| `language` | `vi` or `en`; defaults to app preference. |
| `mode` | `continuous`, `interval`, `ending`, `combined`; default `combined`. |
| `announce_every` | Default `10s`. |
| `countdown_from` | Default `5s`. |
| `announce_step_name` | Default `true`. |
| `announce_start` | Default `true`. |
| `announce_finish` | Default `true`. |

## 5. Examples

```yaml
version: 1
name: Quick Plank
steps:
  - name: Chuẩn bị tư thế
    guide: Đặt khuỷu tay dưới vai.
    countdown: false

  - name: Plank
    duration: 20s
```

```yaml
steps:
  - repeat: 3
    steps:
      - name: Plank
        duration: 30s
      - name: Nghỉ
        duration: 15s
        countdown: false
```

## 6. Execution Semantics

- `duration: 0s` is valid and can represent an instruction-only step.
- `countdown: false` suppresses continuous, interval, and ending timing speech, but not step name, guide, cue sound, or visible timer.
- For nested repeat groups, spoken repeat index refers only to the innermost repeat context.
- Timer and protected step announcement start in parallel at step activation.
- A step advances only when `timerFinished == true` **and** `announcementFinished == true`.
- If duration is `0s`, `timerFinished` is true immediately; the step waits only for announcement completion.
- If there is no protected announcement content, `announcementFinished` is considered complete immediately.
