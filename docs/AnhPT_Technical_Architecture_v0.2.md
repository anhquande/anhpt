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

## 7. Client-Only Voice Sources and Local Cache Direction

The planned high-quality voice path is client-only. It must not depend on an
AnhPT audio server, shared API key, subscription audio service, server cache, or
shared cache.

For each utterance, the client should use this order:

1. Compute the versioned cache key and check the device-local audio cache.
2. On a cache miss, check whether the user has assigned a locally recorded
   coach-audio file to the selected cue or workout and play that file.
3. If there is no usable recording and the user has supplied their own OpenAI API key on that
   device, request high-quality speech directly from the client and store the
   successful result in the device-local cache.
4. If no user key is available or remote synthesis fails, fall back to the
   platform TTS already available on the device. Voice failure must still not
   stall workout progression.

User-recorded coach audio is local-only. Recording and playback do not require
an API key and recordings are not uploaded by default. The app should maintain
a local recording index with at least: workout identifier, scope
(`description` or `step`), cue identifier, optional structural step key,
optional voice profile, language, device-local audio path, creation time, and
metadata/schema version. Step keys use the step's structural index path in the
workout definition, so repeat rounds share the recording for the same defined
step without changing the YAML schema. Paths must be treated as device-local
references and checked for file availability before playback; a missing or
unreadable recording continues to the next fallback without stalling the
workout.

A recording flow must request microphone permission only when needed and
explain why it is needed. Before assigning a recording, the user must be able
to review its target cue/workout and listen to it. The user must also be able
to replace or delete an assignment and its local file. Destructive replacement
or deletion should be explicit, and permission denial must leave device TTS and
other voice paths usable.

The user's API key is device-local secret material. A future implementation
must store it with platform secure storage, never hard-code it, commit it,
include it in cache metadata, or write it to application logs. Cached audio and
cache indexes remain local to the user's device; no cross-user or cross-device
cache or recording storage is implied.

The cache identity should include normalized text, language, voice profile,
voice, speed, TTS provider/model, and a synthesis/profile version. Changing any
of these inputs produces a different cache entry.

## 8. Offline Background Music

Background music is client-only and uses a dedicated `AudioPlayer`, separate
from cue/coach audio so it never blocks timers or step transitions. Per-workout
metadata is keyed by `workout.id` and stores optional track id, enabled state,
base volume, and ducking mode (`off`, `gentle`, or `medium`). No YAML change is
required.

The local music library contains immutable bundled entries and personal tracks
copied into application documents after user import. Track metadata (id, name,
mood, source, bundled flag, creation time), assignments, and files remain local.
Deleting a personal track clears every affected workout assignment before the
file is removed. Missing/unreadable files cause a safe no-music workout.

Music starts at workout start, loops, pauses/resumes with the session, and is
stopped/disposed on completion, early end, or screen disposal. Coach activity
drives a short volume fade: gentle uses about 82% of base volume, medium 60%,
and off preserves base volume. Duck/restore calls are fire-and-forget.
