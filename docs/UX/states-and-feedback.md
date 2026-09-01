# States and Feedback

## Principle

Every data-driven or hardware-dependent surface must intentionally define its non-happy-path states. Blank space or silent failure is not an acceptable state.

## Loading

Show progress when content or hardware initialization takes noticeable time. Preserve surrounding layout where possible so the screen does not jump when loading finishes.

Avoid duplicate submissions while a write/install/import operation is in progress.

## Empty

An empty state should answer two questions:

1. What is empty?
2. What can the user do next?

Examples include no workouts, no health measurements, no catalog results, or no imported music.

## Error

Error feedback should be specific enough to guide recovery without exposing unnecessary implementation detail.

Provide Retry only when repeating the operation is meaningful. Preserve existing local data when remote operations fail.

## Offline

Differentiate unavailable remote content from still-available local/cached content. Offline catalog failures must not make installed workouts appear lost.

## Disabled

Disabled controls should have an understandable reason. On pointer/focus platforms, a short tooltip may explain why. Avoid long permanent warning text unless the limitation is important before interaction.

## Success

Success feedback should confirm persistence, not merely a button press. Avoid showing saved/success states before the underlying write actually completes.

## Optional subsystem degradation

Failures should remain local:

- camera unavailable → workout continues without camera,
- missing demonstration → fallback visual,
- music unavailable → workout starts without that track,
- recording missing → TTS fallback where applicable,
- TTS unavailable → visual timer/session still functions,
- bucket refresh failure → existing local workouts remain intact.

## Destructive confirmation

Confirm destructive operations when the consequence is difficult to reverse or involves user-created data. The confirmation should name what is being removed and avoid vague `Are you sure?` copy.

## Long-running operations

For installation, import/export, media processing, or other longer actions:

- indicate progress or busy state,
- prevent accidental duplicate execution,
- allow safe cancellation when technically supported,
- provide clear final success/failure feedback.
