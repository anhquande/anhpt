# AnhPT Project Management Guide

This document describes how AnhPT uses GitHub Issues, labels, Projects, branches, pull requests, CI, testing, and releases to manage development work.

## Overview

AnhPT uses three GitHub Projects with separate responsibilities:

- **Roadmap** — medium- and long-term planning.
- **Sprint Board** — active implementation work.
- **Bug Tracking** — defect investigation and verification.

The same issue may appear in more than one Project when useful. For example, a major feature can remain visible in the Roadmap while its implementation work is tracked in the Sprint Board.

```mermaid
flowchart LR
    Idea[Idea or Request] --> Issue[GitHub Issue]
    Issue --> Classify[Type, Priority, Area]
    Classify --> Route{Route work}

    Route -->|Product direction| Roadmap[Roadmap]
    Route -->|Implementation| Sprint[Sprint Board]
    Route -->|Defect| Bugs[Bug Tracking]

    Roadmap --> Ready[Ready for Implementation]
    Sprint --> Ready
    Bugs --> Ready

    Ready --> Branch[Create Branch]
    Branch --> Implement[Implement Change]
    Implement --> Verify[Local Verification]
    Verify --> PR[Pull Request]
    PR --> CI[CI and Review]
    CI --> Merge[Merge]
    Merge --> Test[Post-merge Testing]
    Test --> Release{Release needed?}
    Release -->|Yes| Published[Release]
    Release -->|No| Done[Done]
    Published --> Done
```

## Choosing the Right Project

```mermaid
flowchart TD
    Start[New Issue] --> Bug{Is it a defect or regression?}
    Bug -->|Yes| BugProject[Add to Bug Tracking]
    Bug -->|No| Strategic{Is it medium or long-term product work?}
    Strategic -->|Yes| Roadmap[Add to Roadmap]
    Strategic -->|No| Sprint[Add to Sprint Board]

    Roadmap --> Active{Implementation starts now?}
    Active -->|Yes| SprintToo[Also add to Sprint Board]
    Active -->|No| KeepRoadmap[Keep in Roadmap]

    BugProject --> FixNow{Fix planned now?}
    FixNow -->|Yes| SprintBug[Also add to Sprint Board]
    FixNow -->|No| TrackBug[Keep in Bug Tracking]
```

## Roadmap Workflow

The Roadmap answers: **What should AnhPT build, improve, or investigate over time?**

Use it for major features, architecture changes, product initiatives, and release goals. Avoid filling the Roadmap with small implementation tasks.

```mermaid
stateDiagram-v2
    [*] --> Ideas
    Ideas --> Research
    Research --> Planned
    Planned --> Ready
    Ready --> InProgress
    InProgress --> Testing
    Testing --> Released
    Released --> [*]

    Ideas --> Dropped
    Research --> Dropped
    Planned --> Dropped
    Ready --> Dropped
    InProgress --> Dropped
    Dropped --> [*]
```

### Roadmap status meanings

| Status | Meaning |
| --- | --- |
| `Ideas` | Interesting idea that has not yet been evaluated. |
| `Research` | Product or technical investigation is in progress. |
| `Planned` | Approved for future development. |
| `Ready` | Defined well enough to begin implementation. |
| `In Progress` | Implementation is actively underway. |
| `Testing` | Implementation exists and is being verified. |
| `Released` | Available in an AnhPT release. |
| `Dropped` | Intentionally abandoned or no longer relevant. |

## Sprint Board Workflow

The Sprint Board answers: **What are we actively working on now or next?**

```mermaid
stateDiagram-v2
    [*] --> Backlog
    Backlog --> Ready
    Ready --> InProgress
    InProgress --> Review
    Review --> Testing
    Testing --> Done
    Done --> [*]

    Ready --> Blocked
    InProgress --> Blocked
    Review --> Blocked
    Testing --> Blocked

    Blocked --> Ready
    Blocked --> InProgress
```

### Sprint status meanings

| Status | Meaning |
| --- | --- |
| `Backlog` | Known work that is not yet scheduled. |
| `Ready` | Clear scope and acceptance criteria; implementation can start. |
| `In Progress` | Code or documentation is actively being changed. |
| `Review` | A pull request is open or implementation is awaiting review. |
| `Testing` | The merged or completed change is being verified. |
| `Blocked` | Progress cannot continue because of a dependency or unresolved problem. |
| `Done` | Implementation and required verification are complete. |

## Bug Tracking Workflow

The Bug Tracking project answers: **What is broken, how severe is it, and has the fix been verified?**

Severity and priority are intentionally separate:

- **Severity** describes impact.
- **Priority** describes how soon the issue should be handled.

```mermaid
stateDiagram-v2
    [*] --> New
    New --> NeedsReproduction
    New --> Confirmed
    NeedsReproduction --> Confirmed
    Confirmed --> Investigating
    Investigating --> ReadyToFix
    ReadyToFix --> Fixing
    Fixing --> ReadyToVerify
    ReadyToVerify --> Verified
    Verified --> Closed
    Closed --> [*]

    New --> WontFix
    Confirmed --> WontFix
    Investigating --> WontFix
    ReadyToFix --> WontFix
    WontFix --> [*]
```

### Bug status meanings

| Status | Meaning |
| --- | --- |
| `New` | Newly reported defect. |
| `Needs Reproduction` | More information or reliable reproduction steps are needed. |
| `Confirmed` | The problem has been reproduced or otherwise validated. |
| `Investigating` | Root cause is being identified. |
| `Ready to Fix` | Root cause or implementation direction is sufficiently understood. |
| `Fixing` | A fix is actively being implemented. |
| `Ready to Verify` | A proposed fix exists and needs verification. |
| `Verified` | The fix has been successfully verified. |
| `Closed` | Bug lifecycle is complete. |
| `Won't Fix` | The problem is understood but will intentionally remain unresolved. |

## Development Workflow

Every significant implementation should normally start from an Issue and end with verification.

```mermaid
flowchart TD
    Issue[Create or Select Issue] --> Ready{Definition of Ready met?}
    Ready -->|No| Refine[Clarify scope, dependencies and acceptance criteria]
    Refine --> Ready
    Ready -->|Yes| Branch[Create branch]

    Branch --> Work[Implement]
    Work --> Analyze[flutter analyze]
    Analyze --> Tests[flutter test]
    Tests --> Pass{Checks pass?}

    Pass -->|No| Work
    Pass -->|Yes| PR[Open Pull Request]
    PR --> Review[Code Review and CI]
    Review --> Approved{Approved and CI green?}
    Approved -->|No| Work
    Approved -->|Yes| Merge[Merge PR]

    Merge --> Verify[Post-merge Verification]
    Verify --> Result{Works as expected?}
    Result -->|No| FollowUp[Create or reopen issue]
    FollowUp --> Work
    Result -->|Yes| Complete[Move project item to final status]
```

## Branch and Pull Request Conventions

Use short, descriptive branch names:

```text
feat/<short-description>
fix/<short-description>
refactor/<short-description>
docs/<short-description>
```

Use conventional pull request titles:

```text
feat: add ...
fix: correct ...
refactor: simplify ...
docs: document ...
```

Reference the related issue from the pull request where applicable:

```text
Closes #123
```

## Release Workflow

AnhPT uses pull request title prefixes as part of release automation. A merged PR beginning with `feat:` or `fix:` can trigger the Android release workflow.

```mermaid
flowchart TD
    PR[Pull Request] --> Merge{Merged to main?}
    Merge -->|No| Stop[No release]
    Merge -->|Yes| Prefix{PR title prefix}

    Prefix -->|feat:| Minor[Minor version bump]
    Prefix -->|fix:| Patch[Patch version bump]
    Prefix -->|docs: / refactor: / other| Stop

    Minor --> CI[Run tests and build APK]
    Patch --> CI
    CI --> Success{Build succeeds?}
    Success -->|No| Failed[Release fails]
    Success -->|Yes| Tag[Create version tag]
    Tag --> Release[Create GitHub Release]
    Release --> APK[Publish release APK]
```

## Relationship Between the Three Projects

The Projects are different views of the same development system rather than isolated task lists.

```mermaid
flowchart LR
    Roadmap[Roadmap<br/>What should we build?] --> Sprint[Sprint Board<br/>What are we building now?]
    Bugs[Bug Tracking<br/>What is broken?] --> Sprint
    Sprint --> Result{Outcome}
    Result -->|Feature completed| RoadmapDone[Roadmap: Released]
    Result -->|Bug fixed| BugDone[Bug Tracking: Verified / Closed]
```

A typical major feature may therefore follow this path:

```text
Roadmap: Ideas -> Research -> Planned -> Ready
                         |
                         v
Sprint:               Ready -> In Progress -> Review -> Testing -> Done
                                                           |
                                                           v
Roadmap:                                                Testing -> Released
```

A typical bug fix may follow this path:

```text
Bug Tracking: New -> Confirmed -> Investigating -> Ready to Fix
                                             |
                                             v
Sprint:                                  Ready -> In Progress -> Review -> Testing -> Done
                                                                            |
                                                                            v
Bug Tracking:                                                   Ready to Verify -> Verified -> Closed
```

## Definition of Ready

An issue is ready for implementation when:

- The problem or objective is clear.
- Scope is sufficiently defined.
- Acceptance criteria are testable where applicable.
- Important dependencies are known.
- Major product or technical questions have been resolved.

```mermaid
flowchart LR
    Clear[Clear objective] --> Scope[Defined scope]
    Scope --> Criteria[Testable acceptance criteria]
    Criteria --> Dependencies[Known dependencies]
    Dependencies --> Questions[Major questions resolved]
    Questions --> Ready[READY]
```

## Definition of Done

Work is done when:

- The implementation or documentation is complete.
- Relevant tests and verification steps pass.
- `flutter analyze` and `flutter test` pass when applicable.
- Documentation is updated if behavior or developer workflow changed.
- The pull request is merged.
- Required post-merge verification is complete.

```mermaid
flowchart LR
    Implementation[Implementation complete] --> Checks[Checks pass]
    Checks --> Docs[Documentation current]
    Docs --> Merged[PR merged]
    Merged --> Verified[Post-merge verified]
    Verified --> Done[DONE]
```

## Recommended End-to-End Lifecycle

```mermaid
flowchart LR
    Idea --> Issue --> Labels --> Project --> Ready --> Branch --> Implementation --> PR --> CIReview[CI / Review] --> Merge --> Testing --> Release --> Done
```

This lifecycle is a guideline rather than a rigid rule. Small documentation changes, emergency fixes, and exploratory work may use a shorter path, but the final state should always make it clear what changed, why it changed, and whether the result was verified.
