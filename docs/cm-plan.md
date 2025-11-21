# Configuration Management Plan (ISO 10007 alignment)

Scope: LabVIEW Icon Editor community project CM practices mapped to ISO 10007 clauses 5.2–5.6. Applies to source, docs, tests, build artifacts, and release outputs governed in this repository.

## 5.2 CM planning and management
- Policy: All CM gates live in `docs/dod.md`; DoD Aggregator (`.github/workflows/dod-aggregator.yml`) must be green on PRs.
- Roles: Maintainers own approvals; Release Manager owns tags/releases; Automation QA owns RTM integrity and CM evidence.
- Baselines:
  - Product baselines: `lv_icon_editor.lvproj`, `resource/`, `vi.lib/` (checked-in LabVIEW code), `Test/`.
  - Requirements baseline: `docs/requirements/rtm.csv`, `docs/requirements/TRW_Verification_Checklist.xlsx|.csv`.
  - Architecture/decision baseline: `docs/adr/adr-index.md`, `docs/adr/ADR-*.md`.
  - Release baseline: SemVer tags `vX.Y.Z` plus uploaded VIP/package artifacts via `.github/workflows/tag-and-release.yml`.
- Change vehicles: pull requests; emergency fixes via hotfix branches (`hotfix/*`) with same gates.

## 5.3 Configuration identification
- Items uniquely identified by path + git commit; releases identified by SemVer tag (`vX.Y.Z`) and GitHub Release page.
- Traceability maintained in `docs/requirements/rtm.csv` (id → code_path/test_path), validated by `.github/scripts/validate_rtm.py`.
- ADRs indexed in `docs/adr/adr-index.md`; templates in `docs/adr/adr-template.md`.
- Workflows governing CM evidence: `docs-link-check.yml`, `rtm-validate.yml`, `rtm-coverage.yml`, `adr-lint.yml`, `dod-aggregator.yml`, `tag-and-release.yml`.

## 5.4 Configuration change control
- Entry: Proposed changes via PR with linked requirement/ADR; mandatory gates listed in `docs/dod.md`.
- Reviews: Maintainer approval required; breaking changes document rationale in ADRs.
- Automated controls:
  - RTM validation (`.github/scripts/validate_rtm.py`) blocks missing paths.
  - RTM coverage (`.github/scripts/check_rtm_coverage.py`) enforces ≥100% High/Critical, ≥75% overall test presence.
  - ADR lint (`.github/scripts/lint_requirements_language.py`) rejects vague language.
  - Docs link check via `lycheeverse/lychee-action@v1`.
- Emergency change: hotfix branch + expedited review; same gates must pass before merge/tag.

## 5.5 Configuration status accounting
- Status sources:
  - GitHub PR checks (DoD Aggregator summary, RTM, coverage, ADR lint, link check, unit tests).
  - RTM artifacts: `docs/requirements/rtm.csv`, `docs/requirements/TRW_Verification_Checklist.xlsx`.
  - Release records: GitHub Releases with VIP/package artifacts and notes (from `.github/workflows/tag-and-release.yml`).
  - Test/coverage evidence: `test-results.json`, RTM coverage output (workflow logs/artifact).
- Reports:
  - DoD summary artifact (aggregated gate outcomes).
  - Lychee report artifact (`lychee/*.json`).
  - Release notes (`Tooling/deployment/release_notes.md`).

## 5.6 Configuration audit
- Functional/configuration audit prerquisites: DoD Aggregator must be green (valid RTM, coverage, ADR lint, link check).
- Physical audit: release tag `vX.Y.Z` must exist and match HEAD; artifacts uploaded via tag-and-release workflow.
- RTM audits: run `.github/scripts/validate_rtm.py` and `.github/scripts/check_rtm_coverage.py` locally before PR.
- ADR audit: ensure `docs/adr/adr-index.md` updated and ADRs pass lint.

## Runbook (operational steps)
Local:
1) `python3 docs/requirements/sync_trw_csv_to_xlsx.py`
2) `python3 .github/scripts/validate_rtm.py`
3) `python3 .github/scripts/check_rtm_coverage.py`
4) `python3 .github/scripts/lint_requirements_language.py`
5) `pwsh -File .github/actions/unit-tests/unit_tests.ps1 -RelativePath \"$PWD\"`

CI/PR:
- DoD Aggregator / `dod-aggregator.yml` runs RTM validation, RTM coverage, ADR lint, docs link check; uploads DoD summary artifact.
- Dedicated gates also run: RTM validate (`rtm-validate.yml`), RTM coverage (`rtm-coverage.yml`), ADR lint (`adr-lint.yml`), Docs Link Check (`docs-link-check.yml`).

Release:
- Merge to release/*/main triggers CI; tag via `.github/workflows/tag-and-release.yml` to publish `vX.Y.Z` plus artifacts and release notes.

## References
- Definition of Done: `docs/dod.md`
- Traceability: `docs/requirements/rtm.csv`
- TRW checklist: `docs/requirements/TRW_Verification_Checklist.md`
- ADR index: `docs/adr/adr-index.md`
- Release workflow: `.github/workflows/tag-and-release.yml`
