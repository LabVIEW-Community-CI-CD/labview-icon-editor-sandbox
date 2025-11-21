# Architecture (C4 minimal set)
> Views + rationale; stakeholders + concerns; decisions referenced (ADRs).
## Context (L1)
- Users: LV Developers; CI Runners; Maintainers.
- External: GitHub Actions; G-CLI; VIPM.
## Container (L2)
- App containers: Icon Editor (LV project); Test Launcher; Build Scripts.
- CI containers: Composite workflows; self-hosted LV runners.
## Component (L3)
- Key components: Undo/Redo Core; Editor Position; Text-Based Icon; Tooling.
## Deployment (L4)
- Environments: Developer workstation (LV 2021 32/64); Self-hosted Windows runner; GitHub.
## Decisions
- See `../adr/` (e.g., ADR-2025-001).
## Correspondences
- RTM <-> Code <-> Tests: `../requirements/rtm.csv`.
