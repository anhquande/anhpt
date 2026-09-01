# UX PR Review Checklist

Use this checklist for pull requests that add or change user-facing behavior.

## Placement and hierarchy

- [ ] The feature lives on the correct screen according to `information-architecture.md`.
- [ ] Frequent actions are visible; infrequent/advanced actions are appropriately secondary.
- [ ] The change does not create a duplicate action or competing navigation path.
- [ ] Primary content/state remains visually stronger than metadata and advanced controls.

## Interaction

- [ ] Icon-only controls have understandable icons and semantic labels/tooltips.
- [ ] Drag handles are only shown where drag works and are not placed next to toggles/destructive controls.
- [ ] Dialogs have one focused purpose and clear primary/cancel/destructive actions.
- [ ] Forms preserve input when validation fails.

## Player and media

- [ ] Player layout remains stable between steps.
- [ ] Missing demonstration media uses fallback content instead of collapsing the layout.
- [ ] Camera does not restart on normal step transitions or layout switching.
- [ ] Camera/video aspect ratio is preserved; content is not stretched.
- [ ] Optional media/audio/camera failures do not block the workout.

## States and feedback

- [ ] Loading state is defined where necessary.
- [ ] Empty state explains what is empty and offers a useful next action.
- [ ] Error state explains failure and recovery where possible.
- [ ] Offline/cached/local behavior is explicit.
- [ ] Disabled actions have an understandable reason.
- [ ] Success is shown only after persistence succeeds.
- [ ] Destructive operations are appropriately confirmed.

## Responsive behavior

- [ ] Tested on narrow Android layout.
- [ ] Tested on typical Android phone layout.
- [ ] Tested on compact Windows window.
- [ ] Tested on wide Windows window.
- [ ] No required action disappears without an alternative path.
- [ ] Software keyboard does not block Android forms/dialogs.

## Accessibility

- [ ] Essential state is understandable without audio.
- [ ] Important state is not communicated through color alone.
- [ ] Windows keyboard navigation works for affected flows.
- [ ] Touch targets are sufficiently large on Android.
- [ ] Larger text/long translations do not clip primary actions.
- [ ] Overlays remain readable over camera/media backgrounds.

## Data and consistency

- [ ] Existing workout/user/health data remains preserved.
- [ ] Source provenance remains intact where applicable.
- [ ] Reordering preserves identity and associated recordings/media.
- [ ] Code behavior matches `AnhPT_UX_UI_Specification_v0.3.md`.
- [ ] If the product behavior changed, UX documentation is updated in the same PR.
