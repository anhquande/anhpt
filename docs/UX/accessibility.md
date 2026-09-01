# Accessibility

## Goal

AnhPT must remain understandable when audio, vision, dexterity, or attention is limited. Workout usage is especially demanding because the user may be moving and looking only briefly at the screen.

## Visual accessibility

- Maintain readable contrast for text, controls, metadata, overlays, and disabled states.
- Do not communicate state through color alone.
- Use clear text/state labels for countdown, paused, finishing guide, completed, camera unavailable, and similar conditions.
- Text scaling must not clip primary controls or essential workout information.

## Controls

- Icon-only controls require semantic labels and tooltips where supported.
- Touch targets should remain comfortably tappable even when the visible icon is compact.
- Keyboard users on Windows must be able to reach all essential actions.
- Focus order should follow the visual/task order.

## Audio independence

Voice guidance is important but cannot be the sole source of critical state. The current step, remaining time, Pause/Resume state, and completion status must remain visible.

If TTS or recordings fail, the workout should still be operable visually.

## Motion and media

Avoid unnecessary flashing or layout shifts. Camera must not visibly restart on every step transition.

Looping demonstration video/GIF should support the session pause state. Avoid decorative motion that distracts from exercise guidance.

## Labels and language

Use concise, action-oriented labels. Avoid jargon when user-facing wording can describe the outcome instead.

Support long translated strings without clipping or hiding controls.

## Forms and validation

Validation should identify both the affected field and the problem. Do not rely only on red outlines.

Preserve user input after validation errors.

## Testing

For UI changes, verify at least:

- keyboard-only navigation on Windows for affected flows,
- larger text scaling,
- long labels,
- screen states with audio disabled/unavailable,
- touch target usability on Android,
- contrast/readability over camera and demonstration backgrounds.
