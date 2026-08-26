# AnhPT Technical Architecture

**Version:** 0.2  
**Status:** Updated to match AnhPT v0.8.2.

## 1. Architecture Summary

AnhPT is a Flutter application with a model/parser layer, execution engine, voice/audio services, local persistence, and presentation screens. YAML is a serialization/import format. The Visual Builder edits a mutable draft model and serializes it back to YAML before validation and persistence.

## 2. Main Components

| Component | Responsibility |
|---|---|
| `Workout`, `WorkoutStep`, `RepeatGroup` | Immutable validated workout model. |
| `WorkoutDraft`, `StepDraft`, `RepeatDraft` | Mutable Builder-side editing model. |
| `WorkoutParser` | Parse/validate YAML and apply defaults including `duration=0s` and `countdown=true`. |
| `WorkoutSerializer` | Serialize Builder draft back to YAML and omit safe defaults for concise output. |
| `ExecutableStep`, `RepeatContext` | Flatten nested workout structure for runtime while retaining innermost repeat context. |
| `SessionEngine` | Own timing, pause/resume, step progression, and timer/announcement completion coordination. |
| `VoiceGuideController` | Build step announcements, repeat-round phrases, guide speech, timing speech, and notify the engine when protected announcement completes. |
| `AudioFeedbackService` | TTS, TTS completion callbacks, cue playback, language-specific phrases. |
| `LocalStore`, `AppController` | Persist workouts/preferences and coordinate app state. |

## 3. Step Completion Model

For each executable step, two independent completion conditions are tracked:

1. `timerFinished`
2. `announcementFinished`

Both start at step activation. The engine may advance only when both are true.

```text
activateStep()
  -> startTimer()
  -> startProtectedAnnouncement()
  -> wait(timerFinished && announcementFinished)
  -> advanceStep()
```

### Important behavior

- If TTS takes longer than the configured duration, the timer reaches zero but the step remains active until TTS completes.
- If TTS finishes first, the engine waits for the timer.
- For `duration: 0s`, timer completion is immediate and only the announcement may remain pending.
- If there is no protected announcement content, announcement completion is immediate.

## 4. Repeat Context

`Workout.expand()` generates `ExecutableStep` instances. `RepeatContext` carries `index`, `total`, and `isFirstStepOfRound`. For nested repeats, runtime voice announcements intentionally use only the innermost repeat context.

## 5. Per-Step Voice Timing

`WorkoutStep.countdown` defaults to `true`. When false, all timing speech is disabled for that step, including continuous, interval, and final countdown speech. Step name, guide, cue sound, and visible timer still operate normally.

## 6. Concurrency / TTS Safety

- Protected step announcements use a completion-aware TTS path.
- A step transition must never interrupt a protected step name/guide announcement.
- Timing voice remains separate from protected step announcement semantics.
- Engine/listener callbacks must avoid re-entrant transitions.
- TTS failure must not deadlock the workout; failure is treated as announcement completion so execution can continue.
