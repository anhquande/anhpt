# AnhPT UX/UI Specification

**Version:** 0.2  
**Status:** Updated to match AnhPT v0.8.2.

## 1. Workout Creation

The default creation flow is the **Visual Workout Builder**. YAML editing remains available as an advanced option and import/export mechanism.

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
