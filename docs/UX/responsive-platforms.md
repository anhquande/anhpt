# Responsive UX: Windows and Android

## Shared structure

Windows and Android should share information architecture, terminology, feature meaning, and core visual hierarchy. Platform adaptation should change interaction mechanics and layout density, not product concepts.

## Windows

- Support mouse hover, tooltips, keyboard focus, tab navigation, and shortcuts where appropriate.
- Avoid stretching content across the entire width of large windows; use sensible max-width containers.
- Use hover only as an enhancement. Essential functionality still needs a visible/focusable path.
- Preserve media and camera aspect ratios on resize.
- Wide layouts may place related controls in columns, but should collapse predictably as the window narrows.

## Android

- Essential touch targets should be approximately 48 logical pixels where practical.
- Do not rely on hover.
- Respect safe areas, system bars, and software keyboard insets.
- Keep primary Player controls reachable and visually obvious while maximizing useful camera/demonstration space.
- Forms and dialogs must remain scrollable when the keyboard is visible.

## Breakpoint behavior

Responsive behavior should be content-driven rather than tied to one device model.

When space becomes constrained:

1. reduce non-essential horizontal padding,
2. wrap related secondary actions,
3. stack multi-column form controls,
4. move low-frequency actions into overflow if already allowed by the interaction model,
5. never hide a required feature with no alternative access path.

## Tables and dense data

On wide Windows layouts, measurement history may use aligned columns with generous space. On narrow Android layouts, preserve column meaning with compact widths, horizontal scrolling, or a carefully simplified row layout.

## Media surfaces

Camera and demonstration regions should use stable aspect-ratio-aware containers. Reflowing from side-by-side to PiP is preferable to stretching either source.

## Testing expectations

Every major UI PR should be checked at minimum on:

- a narrow Android phone layout,
- a typical Android phone layout,
- a compact Windows window,
- a wide desktop window.

Check text scaling and long translated labels where relevant.
