# AnhPT Implementation Plan & Backlog

**Version:** 0.2  
**Status:** Updated to match AnhPT v0.8.2.

## 1. Implemented in Current MVP

- Flutter Web/Windows application shell and local workout persistence.
- YAML parsing/validation with nested repeats.
- Real TTS and cue sounds.
- Visual Workout Builder with Step/Repeat/nested Repeat editing.
- Optional per-step `guide`.
- Innermost repeat-round voice announcement, e.g. `Plank lần thứ 1`.
- Per-step `countdown: false` to disable all timing speech.
- Optional `duration`, defaulting to `0s`.
- Parallel timer + protected step announcement.
- AND-gated step completion: advance only when timer and protected announcement are both finished.
- Windows TTS completion callback handling with safe failure fallback.
- Windows local workout-description and per-step coach recording with
  permission guidance, listen-back, scoped assignment, replacement/deletion,
  and device-TTS fallback.
- Windows offline background music library and per-workout assignment, with
  looped lifecycle playback, volume control, smooth coach ducking, personal
  import/delete safety, and missing-file fallback.
- YAML v2 recording references, globally unique effective step IDs,
  background-music assignment, YAML v1 compatibility, and legacy migration.
- SHA-256 media deduplication, optional Exercise references, file-selected
  static image/GIF/video demonstrations, type-aware player integration, and ZIP
  media manifests.

## 2. Near-Term Backlog

| Priority | Item | Notes |
|---|---|---|
| P0 | Regression tests for step-completion semantics | Cover timer shorter/longer than TTS, `0s` steps, no-announcement steps, pause/resume. |
| P0 | Builder validation UX | Inline errors for invalid duration/repeat count instead of save-time only. |
| P1 | Drag-and-drop reorder | Optional replacement/extension for move up/down. |
| P1 | Workout templates | Plank, HIIT, stretching, mobility presets. |
| P1 | Android device QA | TTS languages, haptics, lifecycle/background behavior. |
| P2 | Native iPhone implementation | Background audio, interruptions, Live Activity, Lock Screen, Dynamic Island. |
| P2 | Cloud sync / sharing | Optional future capability; not required for local MVP. |
| P1 | Exercise video capture | Camera capture, trim, compression, and platform QA; file selection comes first. |
| P2 | Media cleanup UI | Find and remove unreferenced shared media safely. |

## 3. Required Regression Tests

1. `duration: 2s`, protected announcement takes 5s → advance after approximately 5s.
2. `duration: 10s`, protected announcement takes 3s → advance after approximately 10s.
3. Duration omitted / `0s`, protected announcement exists → advance after announcement finishes.
4. `duration: 0s`, no protected announcement content → advance immediately.
5. `countdown: false` → no continuous/interval/final timing speech.
6. Nested repeat → only inner repeat count is spoken.
7. Pause/resume preserves timer elapsed time accurately.
8. Timer reaches zero while guide speaks → remain on step, show waiting state, then advance after speech.
9. TTS error → workout continues instead of deadlocking.
10. Existing YAML without `guide`, `countdown`, or explicit `duration` remains backward compatible according to defaults.

## 4. Architecture Follow-ups

- Add unit tests around `SessionEngine` independent completion flags.
- Add fake/mock TTS completion source for deterministic tests.
- Verify listener serialization under rapid timer ticks and TTS callbacks.
- Ensure timing announcements do not incorrectly satisfy or reset protected announcement completion.
- Verify zero-duration chains do not cause recursion/re-entrancy issues.

## 5. Documentation Policy

Markdown files in `docs/` should be treated as the actively maintained specifications because they are directly diffable and editable through Git. Older DOCX files are retained as historical snapshots.
