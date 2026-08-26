# AnhPT Codex Guide

## Purpose
AnhPT is a Flutter workout timer with voice-guided exercises. Keep the implementation aligned with the living specifications in `docs/` and preserve existing working behavior unless a task explicitly changes it.

## Source of truth
Before making non-trivial changes, read the relevant Markdown specs under `docs/`:

- `docs/AnhPT_Product_Description_v0.3.md`
- `docs/AnhPT_YAML_Schema_Specification_v0.2.md`
- `docs/AnhPT_Technical_Architecture_v0.2.md`
- `docs/AnhPT_UX_UI_Specification_v0.2.md`
- `docs/AnhPT_Implementation_Plan_Backlog_v0.2.md`

The Markdown files are the current living specifications. Older DOCX files are historical snapshots only.

If code and specification conflict, do not silently choose one. Inspect recent implementation intent and make the smallest coherent change. Update the relevant Markdown spec whenever product behavior or YAML semantics change.

## Core product rules
Preserve these behaviors unless the task explicitly changes them:

- YAML is the portable/import-export format; the Visual Workout Builder is the normal editing UI.
- A step may have `name`, optional `duration`, optional `guide`, and optional `countdown`.
- Missing `duration` means `0s`.
- `duration: 0s` is valid.
- Missing `countdown` means `true`.
- `countdown: false` disables all timing voice for that step, but does not suppress the step name, guide, or transition cue.
- Step announcement and step timer start together.
- A step may advance only when BOTH conditions are true:
  1. the configured timer duration has finished, and
  2. the step name/guide announcement has finished.
- Therefore a short or `0s` step must still wait for its announcement to finish before advancing.
- If announcement finishes before the timer, wait for the timer.
- If timer finishes before announcement, keep the current step at `00:00` until announcement finishes.
- TTS failure must not permanently stall a workout.
- Repeat voice announcement is spoken at the first step of a repeat round, e.g. `Plank lần thứ 2` in Vietnamese.
- For nested repeats, announce the innermost applicable repeat context, not the outer repeat.
- Timing voice and displayed countdown should remain perceptually synchronized; existing TTS lead compensation should not be removed casually.

## Architecture boundaries
Prefer the existing separation of responsibilities:

- `lib/models/`: persisted/domain models and builder draft models.
- `lib/core/session_engine.dart`: deterministic workout execution/timing state. Do not put UI or TTS implementation details here.
- `lib/services/workout_parser.dart`: YAML parsing and validation.
- `lib/services/workout_serializer.dart`: Builder model to YAML.
- `lib/services/audio_feedback_service.dart`: platform TTS/audio details.
- `lib/services/voice_guide_controller.dart`: orchestration between session state and spoken feedback.
- `lib/screens/`: Flutter UI only.

Keep `WorkoutStep` as the workout definition. Runtime repeat/execution information belongs in execution context types such as `ExecutableStep` / `RepeatContext`, not as mutable state on the YAML model.

## YAML compatibility
Changes to the YAML schema must be backward compatible when practical. Existing valid workouts should continue to parse without edits.

When adding an optional field:

- define a safe default,
- update parser validation,
- update model serialization/persistence,
- update Builder UI if user-facing,
- update `workout_serializer.dart`,
- update `docs/AnhPT_YAML_Schema_Specification_v0.2.md` (or create the next version when appropriate),
- consider stored workouts created by older app versions.

Do not emit redundant default fields in YAML when omission keeps the file clearer. For example, omit `countdown: true` and omit `duration` for a zero-duration instruction step where possible.

## Voice and timing changes
Voice/timer synchronization is a sensitive area. When modifying it, reason explicitly about these cases:

- normal step: voice shorter than timer,
- short step: voice longer than timer,
- `duration: 0s`,
- no guide,
- `announce_step_name: false`,
- `countdown: false`,
- pause/resume,
- last step completion,
- TTS error or unavailable voice,
- repeated and nested-repeated steps.

Avoid blocking periodic timer updates by awaiting long TTS work directly inside timer evaluation code. Keep the engine state deterministic and let the voice controller report announcement completion back to the engine.

## Builder requirements
The Visual Builder should remain understandable for non-technical users. Prefer controls over exposing YAML concepts directly.

Each Step editor should support:

- name,
- duration (blank = `0s`),
- optional guide,
- Voice timing toggle,
- move up/down,
- duplicate,
- delete.

Repeat groups must support nested Steps/Repeats. YAML editing/import remains an advanced path and must stay available.

## Coding conventions
- Use idiomatic Dart and Flutter.
- Prefer clear domain names over abbreviations.
- Keep methods small when state transitions become difficult to reason about.
- Avoid broad rewrites when a localized fix is sufficient.
- Preserve public APIs where practical.
- Do not add dependencies unless they materially simplify the requirement.
- Do not introduce platform-specific behavior into shared code unless guarded appropriately.

## Validation before finishing
For code changes, run at least:

```bash
flutter pub get
flutter analyze
flutter test
```

If no tests exist for changed logic, add focused unit tests when practical, especially for parser/session-engine behavior.

For player/timing/TTS changes, also do a best-effort runtime check on an available target. Windows and Chrome are current development targets; Android is also supported for testing.

When changing YAML behavior, test at minimum:

```yaml
- name: Instruction only
  guide: Prepare for the next exercise.

- name: Rest
  duration: 5s
  countdown: false

- repeat: 2
  steps:
    - name: Plank
      duration: 3s
```

## Change discipline
Before editing, inspect the current implementation rather than assuming the spec describes every implementation detail.

After editing:

1. verify behavior,
2. update affected living spec(s),
3. summarize files changed and any trade-offs,
4. call out anything not tested.

Prefer one coherent feature/fix per commit. Suggested commit prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.

## Do not regress
Do not remove or break these established capabilities while implementing unrelated work:

- Windows/Web voice feedback,
- Vietnamese voice selection where supported,
- Visual Builder,
- YAML import/editor,
- optional step guides,
- repeat/nested-repeat execution,
- repeat round announcement,
- per-step Voice timing toggle,
- optional/zero duration steps,
- timer/announcement completion gating.
