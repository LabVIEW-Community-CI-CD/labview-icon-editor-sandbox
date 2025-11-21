---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Lean tailoring to a repository-scoped document set (policy, strategy, plan, CI-generated §8 reports) driven by RTM/TRW-based coverage gates.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
---

# Test Policy (ISO/IEC/IEEE 29119-3 Tailored)

Scope: this policy applies to the LabVIEW Icon Editor project in this repository (project-level tailoring, not organization-wide). It sets the minimum bar for test planning, execution evidence, and reporting required for PRs and releases.

## Tailoring Decisions (Clause 4.1.3)
- Use RTM-driven, risk-weighted testing: priorities in `docs/requirements/rtm.csv` and TRW checkpoints in `docs/requirements/TRW_Verification_Checklist.md` drive coverage and exit criteria.
- Reduce document set to lean artifacts: policy, strategy, and test plan in `docs/testing/`; ISO 29119-3 §8 templates emitted by CI as test status (`reports/test-status-<run>.md`) and completion (`reports/test-completion-<tag>.md`) reports.
- Evidence must be produced by CI: DoD Aggregator, RTM validation/coverage, Docs Link Check, and test status/completion reports are required on PRs and tags; no manual-only gates.
- Project-only tailoring: organizational quality manuals are out of scope; exceptions must land as ADRs if they affect obligations.

## Principles
- Traceability-first: every requirement with `priority=High|Critical` shall map to a test path; coverage thresholds are enforced automatically.
- Risk-aware: residual risk is expressed via RTM priority and any open TRW findings; releases must be blocked if High/Critical gaps remain.
- Evidence is versioned: RTM, TRW checklist, test plan, and CI-generated reports live in-repo or as GitHub release assets.

## Responsibilities
- Maintainer: owns this policy, approves exceptions, and signs off on release completion reports.
- Automation QA: owns RTM integrity, TRW checklist currency, and CI evidence generation.
- Release Manager: ensures `reports/test-completion-<tag>.md` is attached to releases and matches DoD/RTM thresholds.

## Applicable Standards and References
- ISO/IEC/IEEE 29119-3 (Test Documentation): tailored document set and reporting structure.
- RTM source: `docs/requirements/rtm.csv`; TRW checkpoints: `docs/requirements/TRW_Verification_Checklist.md`.
- CI gates: `.github/workflows/dod-aggregator.yml`, `rtm-validate.yml`, `rtm-coverage.yml`, `docs-link-check.yml`, `test-report.yml`, `tag-and-release.yml`.
- Templates: `docs/testing/templates/test-report-template.md` (ISO 29119-3 §8 progress/completion template).
