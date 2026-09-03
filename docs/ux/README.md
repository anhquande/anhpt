# AnhPT UX Documentation

This folder contains modular UX guidance that complements the canonical product specification in [`../AnhPT_UX_UI_Specification_v0.3.md`](../AnhPT_UX_UI_Specification_v0.3.md).

The v0.3 specification remains the source of truth for established product decisions. Files in this folder explain how to apply those decisions consistently during design, implementation, and PR review.

## Documents

- [`design-principles.md`](design-principles.md) — core UX principles and decision rules.
- [`information-architecture.md`](information-architecture.md) — navigation, screen ownership, and where features belong.
- [`interaction-patterns.md`](interaction-patterns.md) — reusable behavior for actions, dialogs, lists, tables, media, and forms.
- [`player-camera.md`](player-camera.md) — workout Player, camera lifecycle, PiP, media fallback, and stable layout rules.
- [`responsive-platforms.md`](responsive-platforms.md) — Windows and Android responsive behavior.
- [`states-and-feedback.md`](states-and-feedback.md) — loading, empty, error, offline, disabled, success, and degradation patterns.
- [`accessibility.md`](accessibility.md) — accessibility requirements for workout usage and general UI.
- [`ux-pr-checklist.md`](ux-pr-checklist.md) — review checklist for future UI/UX pull requests.

## Documentation rule

When a UX decision changes:

1. Update the canonical UX/UI specification if product behavior changes.
2. Update the relevant modular guide if implementation guidance changes.
3. Avoid copying the same long requirement into several files; link to the source of truth instead.

## Scope

These documents cover user-facing behavior. Technical architecture, YAML schema, health requirements, and project-management concerns remain in their existing documentation under `docs/`.
