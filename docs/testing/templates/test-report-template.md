# Test Report Template (ISO/IEC/IEEE 29119-3 §8 – Progress & Completion)

Use this skeleton for CI-generated reports (`reports/test-status-<run>.md` for PRs, `reports/test-completion-<tag>.md` for releases). Tokens (`<...>`) are replaced by `generate_test_status.py`.

1) **§8.1 Context and Scope**
   - Run/tag: `<run_or_tag>`
   - Event/branch: `<event>`; commit `<sha_short>`
   - Scope: LabVIEW Icon Editor repository; project-level tailoring.

2) **§8.2 Summary and Status**
   - Completion: `<PASS|FAIL>` at UTC `<timestamp>`.
   - Coverage: High/Critical `<x>/<y> = <pct>`; Overall `<x>/<y> = <pct>`; thresholds: 100% / 75%.
   - Suites exercised: `<suite_list>`.

3) **§8.3 Variances and Blocking Issues**
   - RTM gaps: `<list of missing test paths or "none">`.
   - Other blockers: `<link or "none">`.

4) **§8.4 Risks and Mitigations**
   - Risk signal from RTM `priority` and TRW checklist.
   - Mitigation/owner: `<actions>` by `<owner>`.

5) **§8.5 Evidence**
   - RTM: `docs/requirements/rtm.csv`; TRW: `docs/requirements/TRW_Verification_Checklist.md`.
   - CI gates: DoD Aggregator, RTM validation/coverage, ADR lint, Docs Link Check, unit tests.
   - Report source: `<report_path>`.

6) **§8.6 Next Steps**
   - For PRs: fix listed gaps or proceed to merge if PASS.
   - For releases: confirm completion report is attached to the GitHub Release assets.
