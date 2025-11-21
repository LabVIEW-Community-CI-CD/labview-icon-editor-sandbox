---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Strategy aligns to the tailored document set and CI-first execution model that enforce RTM/TRW-driven coverage and reporting at the project level.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
document_control:
  unique_id: TEST-STRATEGY-001
  issuer: Automation QA
  approval_authority: Maintainer
  status: active
  change_history:
    - version: 1.0.0
      date: 2025-11-20
      description: Added §5.2 document control header, glossary reference, and change log starter.
  intro: >
    Project-level test strategy for the LabVIEW Icon Editor repository that operationalizes the policy into test levels, risk handling, and reporting cadence.
  scope: >
    Applies to all testing activities and CI workflows in this repository and informs the project test plan and generated §8 reports.
  references:
    - docs/testing/policy.md
    - docs/testing/test-plan.md
    - docs/requirements/rtm.csv
    - docs/requirements/TRW_Verification_Checklist.md
  glossary: docs/testing/glossary.md
---

# Test Strategy (ISO/IEC/IEEE 29119-3 Tailored)

Scope: project-level strategy for the LabVIEW Icon Editor in this repository. It operationalizes the Test Policy and drives the Test Plan for PRs and releases.

## §5.2 Document Control
| Field | Value |
| --- | --- |
| Unique ID | `TEST-STRATEGY-001` |
| Issuer | Automation QA |
| Approval Authority | Maintainer |
| Status | Active |
| Change History | 2025-11-20 v1.0.0 - Added §5.2 header, glossary link, and change log. |
| Intro | Project-level test strategy that converts the policy into test levels, risk handling, and reporting cadence. |
| Scope | Applies to testing activities and CI workflows in this repository; informs the project plan and generated §8 reports. |
| References | `docs/testing/policy.md`; `docs/testing/test-plan.md`; `docs/requirements/rtm.csv`; `docs/requirements/TRW_Verification_Checklist.md` |
| Glossary | [`docs/testing/glossary.md`](./glossary.md) |

## Approach
- Levels: LabVIEW unit tests under `Test/` plus targeted workflow/automation checks (RTM validation, coverage, ADR lint, link checks). Functional regression is anchored by RTM IDs and TRW checklist items.
- Design inputs: requirements in `docs/requirements/rtm.csv` (priority, verification method) and TRW checkpoints in `docs/requirements/TRW_Verification_Checklist.md`.
- Coverage thresholds: High/Critical requirements require 100% test presence; overall RTM requires >=75% test presence (enforced by `.github/scripts/check_rtm_coverage.py`).
- Execution model: CI-first. Unit tests run on self-hosted LabVIEW runners; RTM and documentation gates run on Ubuntu runners. Local execution mirrors CI via the DoD runbook in `docs/dod.md`.
- Reporting: CI emits ISO 29119-3 §8-aligned progress reports (`reports/test-status-<run>.md`) on PRs and completion reports (`reports/test-completion-<tag>.md`) on tags/releases.

## Risk and Prioritization
- Risk signal: RTM `priority` plus any open TRW checklist findings. High/Critical gaps block releases. Medium/Low gaps are tracked but may defer if recorded in RTM and surfaced in status reports.
- Mitigation: missing coverage or broken traceability must be fixed or waived by a Maintainer via ADR if they affect exit criteria.

## Environments and Data
- Test environments: self-hosted LabVIEW runners `test-2021-x64`/`test-2021-x86` for execution; Ubuntu runners for analysis gates.
- Test artifacts: `test-results.json` (unit tests), RTM CSV/XLSX, TRW checklist, generated reports in `reports/`.

## Roles
- Maintainer: accepts/blocks merges based on test status reports and coverage thresholds.
- Automation QA: maintains RTM/traceability, reviews test evidence, and curates the templates under `docs/testing/templates/`.
- Release Manager: requires a passing completion report tied to the release tag before publishing.

## Entry/Exit Hooks
- Entry (development/PR): DoD Aggregator green, RTM validation, RTM coverage, ADR lint, Docs Link Check; test status report uploaded for the run.
- Exit (release): tag-and-release workflow succeeds, completion report attached for the tag, RTM thresholds met, no broken links.

## Change History
| Date | Version | Description |
| --- | --- | --- |
| 2025-11-20 | 1.0.0 | Added §5.2 document control header, glossary reference, and change log starter. |
