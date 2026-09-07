# Per-step Voice Coach cues

AnhPT workouts can opt individual steps into contextual Voice Coach cues without changing legacy global voice timing behavior.

## YAML

```yaml
steps:
  - name: High Plank
    duration: 30s
    voice_cues:
      announce_next: true
      get_ready: true
      countdown: true
      halfway: true
      remaining_time: 10
      completion: true
```

All fields are optional and default to off.

| Field | Type | Default | Behavior |
|---|---|---:|---|
| `announce_next` | bool | `false` | Announces the next step near the end when there is enough time. |
| `get_ready` | bool | `false` | Says a preparation cue before the timed step starts. |
| `countdown` | bool | `false` | Says `3, 2, 1, go` before the timed step starts. |
| `halfway` | bool | `false` | Announces the halfway point once when the step is long enough. |
| `remaining_time` | int | `0` | Announces that many seconds remaining. `0` or omission disables the cue. |
| `completion` | bool | `false` | Allows a short completion cue before transitioning to the next step. |

`remaining_time` accepts integer seconds from 0 through 86400. A value greater than or equal to the step duration is ignored at runtime because it would not represent a meaningful in-step reminder.

## Timing semantics

`get_ready` and `voice_cues.countdown` are pre-start coaching. The configured step timer begins only after those protected announcements complete, so a `30s` step still receives 30 seconds of exercise time.

The new `voice_cues.countdown` is intentionally different from the existing legacy `countdown` property on a step:

- `step.countdown` controls legacy global timing speech such as periodic remaining time and final countdown.
- `step.voice_cues.countdown` is a short `3, 2, 1, go` cue before the step timer begins.

Existing workouts without `voice_cues` retain their previous behavior.

## Short-step protection

The YAML expresses author intent; runtime decides whether a cue can still be spoken accurately and naturally.

Current guardrails:

- halfway is considered only for steps of at least 8 seconds;
- announce-next is considered around 5 seconds remaining only when the current step is at least 12 seconds and a next step exists;
- `remaining_time: X` is ignored when `X >= step duration`;
- contextual timed cues use a minimum spacing of about 3.5 seconds;
- when multiple contextual cues collide, the runtime favors remaining-time, then announce-next, then halfway;
- legacy timing remains backward compatible, but is briefly suppressed after a contextual cue so TTS does not speak over itself;
- completion speech may be suppressed when another timed cue was just spoken; the transition is never blocked if TTS fails;
- the final workout step relies on the normal workout-complete phrase instead of adding another `Done` immediately before it.

These rules intentionally allow a configured cue to be skipped on very short steps rather than producing dense or inaccurate speech.

## Pause, resume and manual navigation

Voice Coach work is generation-scoped. Pause, resume, skip and manual step navigation invalidate stale audio operations. Timed cue state belongs to the current resolved step so halfway/remaining/next cues are not replayed just because the user paused and resumed.

## Builder UI

Each Step card contains a **Voice Coach cues** section. Authors can toggle the boolean cues and enter `remaining_time` as seconds. `0` means off.
