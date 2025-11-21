---
conformance:
  standard: ISO/IEC/IEEE 29119-3
  type: tailored
  scope: project
  rationale: >
    Plan reuses the tailored policy/strategy and CI-generated §8 reports to keep project-level coverage, reporting, and release gates aligned with RTM/TRW.
  stakeholder_approvals:
    - Maintainer (policy owner)
    - Automation QA (evidence curator)
    - Release Manager
---

# Test Plan (ISO/IEC/IEEE 29119-3 §8)

Scope: project-level plan for the LabVIEW Icon Editor repository. It reuses the Test Policy and Strategy and provides the release/PR exit criteria. Owners: Maintainer (sign-off) and Automation QA (evidence curator).

## §8.1 Context and Items Under Test
- Test items: LabVIEW Icon Editor project (`lv_icon_editor.lvproj`), supporting scripts (`.github/scripts/*.py`), and workflows under `.github/workflows/`.
- Inputs: RTM (`docs/requirements/rtm.csv`) and TRW checklist (`docs/requirements/TRW_Verification_Checklist.md`).
- Out of scope: organization-wide quality manuals; they are replaced by the project tailoring recorded here.

## §8.2 Approach and Environment
- Method: RTM-driven regression with priorities determining coverage; execution via CI and self-hosted LabVIEW runners. Design choices inherit from `docs/testing/strategy.md`.
- Environments: `test-2021-x64` and `test-2021-x86` for LabVIEW unit tests; Ubuntu runners for analysis gates and reporting.
- Documentation set: policy, strategy, and this plan; ISO 29119-3 §8 progress/completion template (`docs/testing/templates/test-report-template.md`) emitted as CI reports.

## §8.3 Deliverables
- Progress report per PR run: `reports/test-status-<run>.md`.
- Completion report per tagged release: `reports/test-completion-<tag>.md` (attached to the GitHub Release).
- Supporting artifacts: `test-results.json`, RTM CSV/XLSX, TRW checklist, DoD summary artifact, lychee report.

## §8.4 Completion Criteria (tailored)
- RTM coverage: High/Critical = 100%; overall RTM test presence >= 75% (matches `.github/scripts/check_rtm_coverage.py` thresholds).
- Traceability: `.github/scripts/validate_rtm.py` succeeds; no missing code/test links for Critical items.
- Documentation gates: Docs Link Check green; ADR lint green; DoD Aggregator green.
- Reporting: `reports/test-status-<run>.md` generated for the PR run; `reports/test-completion-<tag>.md` generated and attached for the release tag.
- Releases: tag `vX.Y.Z` created by `tag-and-release.yml` with artifacts uploaded (VIP + release notes + completion report).

## §8.5 Risks, Assumptions, and Contingencies
- Risk sources: RTM `priority` and any open TRW checklist actions. High/Critical gaps block release until closed or waived via ADR.
- Contingency: if LabVIEW runners are unavailable, freeze merges to protected branches; generate status report noting the outage and track remediation in a GitHub issue.

## §8.6 Tailoring Notes
- Document set reduced to policy/strategy/plan plus CI-generated §8 reports; design/case/procedure specs are represented by RTM rows pointing to tests.
- Waivers to coverage or traceability must be captured as ADRs and reflected in the next status/completion report.
