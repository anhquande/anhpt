# AnhPT Architecture

This directory documents the software architecture of AnhPT using the C4 model.

The goal is to keep architecture documentation lightweight, versioned with the code, and useful to both human contributors and AI agents.

## Diagram levels

- `context.puml` — C4 Level 1: AnhPT in its external environment.
- `containers.puml` — C4 Level 2: major runtime and storage responsibilities inside AnhPT.
- `workout-player-components.puml` — C4 Level 3: the main components involved in a workout session.

## Documentation roles

Use the documentation types in the repository for different questions:

| Question | Documentation |
| --- | --- |
| What systems and external actors are involved? | C4 System Context |
| What are the major architectural responsibilities? | C4 Container |
| Which components collaborate to implement a feature? | C4 Component |
| How does a user navigate between screens? | Mermaid in `docs/ux/` |
| What should an individual screen contain? | PlantUML Salt in `docs/ux/` |
| How does project work move through GitHub? | Mermaid in project-management docs |

## AI-agent workflow

Before making a structural change, an AI agent should:

1. Read the relevant C4 diagram.
2. Identify the architectural responsibility that owns the change.
3. Avoid introducing a new cross-layer dependency unless the architecture requires it.
4. Update the corresponding C4 diagram when a structural relationship changes.
5. Use the UX documentation separately for navigation and screen layout changes.

C4 diagrams are architectural maps, not exhaustive class diagrams. Keep them focused on stable responsibilities and important relationships rather than every Dart class.

## Rendering

The diagrams use the C4-PlantUML library. They can be rendered with a PlantUML-compatible IDE extension, local PlantUML tooling, or CI that has access to the C4-PlantUML library.

The source files remain the canonical architecture documentation even when rendered images are generated for convenience.
