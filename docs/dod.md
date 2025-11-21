# Definition of Done (DoD) - Aggregated Gates
- **PR Coverage Gate / coverage**: >=100% High/Critical RTM test presence and >=75% overall RTM test presence (tailored RTM via `.github/scripts/check_rtm_coverage.py`).
- **Traceability Gate / rtm**: Each Critical requirement has >=1 Test and Code link.
- **ADR Lint / adr-lint**: No banned phrases; decisions up to date.
- **Docs Link Check / lychee**: No broken links.
- **CM / SemVer Tag**: Release tag is `vX.Y.Z`; artifacts + notes uploaded.
- **Arch (C4/ADR)**: Minimal C4 updated; >=1 recent ADR.
## Evidence Artifacts
- `lychee/` report; `Tooling/deployment/release_notes.md`; RTM coverage gate log; `docs/requirements/TRW_Verification_Checklist.xlsx`; `docs/requirements/rtm.csv`.
## Owners
- Maintainers; Automation QA; Release Manager.

RUNBOOK (exact)

Local (dev/QA):

python3 docs/requirements/sync_trw_csv_to_xlsx.py

python3 .github/scripts/validate_rtm.py

python3 .github/scripts/check_rtm_coverage.py

pwsh -File .github/actions/unit-tests/unit_tests.ps1 -RelativePath "$PWD"

(optional) run Missing-In-Project action wrapper on runner to sanity-check LV project.

CI (PR): Docs Link Check / lychee runs; Traceability Gate / rtm runs; Coverage Gate / coverage runs; unit tests via existing actions.

Release: merge to release-*/main -> CI; Tag and Release creates vX.Y.Z; upload artifacts (VIP, notes).

Artifacts to attach: test results (test-results.json), RTM coverage gate log (workflow), Tooling/deployment/release_notes.md, TRW_Verification_Checklist.xlsx.

CHECKLIST (acceptance/gates)

PR Coverage Gate / coverage: `.github/scripts/check_rtm_coverage.py` shows >=100% High/Critical and >=75% overall RTM test presence (CI workflow green); Test Completion Report attached.

Docs Link Check / lychee: green.

Traceability Gate / rtm: green (all Critical reqs map to code+test).

ADR Lint / adr-lint: green (existing script).

CM SemVer: R1 tag vX.Y.Z; release page includes notes + artifacts.

Arch: docs/architecture/README.md updated; ADR link present.

Expected artifacts: lychee report, RTM CSV, XLSX, unit test results, RTM coverage gate log, release notes.

EXIT CRITERIA

All gates green on PR to release/* and final tag vX.Y.Z produced; artifacts present; no broken links; RTM validated.
