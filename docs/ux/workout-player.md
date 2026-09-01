# Workout Player wireframe

## Portrait

```text
┌────────────────────────────────┐
│ ━━━━━━━━━━━━●━━━━━━━━━━━━━━━━ │
│ 08:40                    24:00 │
│ ×  Current step     🔊 👁 📹 ▦ │
│                                │
│ ┌────────────────────────────┐ │
│ │          00:24             │ │
│ │                            │ │
│ │                            │ │
│ │     DEMONSTRATION          │ │
│ │       / CAMERA             │ │
│ │                     ┌────┐ │ │
│ │                     │cam │ │ │
│ │                     └────┘ │ │
│ │                            │ │
│ │       Current step         │ │
│ └────────────────────────────┘ │
│                                │
│ ────────────────────────────── │
│ ┌──────┐  Squat                │
│ │thumb │  00:30              ↑ │
│ └──────┘                       │
└────────────────────────────────┘
```

Interactions:

- tap/click media: Pause/Resume;
- swipe up: next resolved step;
- swipe down: previous resolved step;
- tap upcoming-step preview: next step;
- Space/Enter: Pause/Resume;
- Up/Down arrows: next/previous step;
- speaker: mute/unmute workout sound;
- layout icon: switch camera/demo presentation without restarting camera.

## Timeline relationship

The current media stage and upcoming-step preview should feel like adjacent content items in a vertical feed. Use a thin separator and small spacing only; do not show a `NEXT` heading.

One gesture changes at most one logical runtime step. Nested repeats follow the resolved `SessionEngine` sequence.

## Landscape

In landscape, media should consume nearly the entire usable viewport. Progress and controls remain compact at the top. The upcoming-step preview may remain as a shallow bottom strip so it does not compete with demonstration/camera content.

## State overlays

Use the same centered overlay region for:

- remaining current-step time;
- `READY` countdown;
- `PAUSED` plus remaining time;
- `FINISHING GUIDE`.

A transient large play/pause icon appears only after direct media interaction and fades quickly.
