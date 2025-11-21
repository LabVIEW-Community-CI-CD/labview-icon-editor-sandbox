
# R1 — Codex Work Orders (Release Readiness Packet)

> **Jarvis (Root) • Mode: orchestrate • Depth: standard**  
> **Scope:** Release readiness (R1) — gates, evidence, work orders.  
> **Standards anchors:** ISO/IEC/IEEE 29119‑3 (test docs), 29119‑1 (general concepts), 42010 (architecture description), ISO 10007 (CM).

---

## A) Executive Summary (≤10 bullets)

- **Repo gist:** LabVIEW Icon Editor with CI/CD, reusable GH composite actions, unit tests, RTM, CM plan, ADRs.
- **Gate verdicts (current commit, structural + local analysis):**
  - **PR Coverage Gate / coverage:** **PASS** — RTM coverage computed from `docs/requirements/rtm.csv`: **High/Critical 100% (2/2)**; **Overall 100% (7/7)**; thresholds: High/Critical=100%, Overall=75%. Evidence below.
  - **Docs Link Check / lychee:** **N/A (needs CI run)** — workflow present.
  - **Traceability Gate / rtm:** **PASS (structure + data)** — RTM present; code/test paths resolve; validator script present.
  - **ADR Lint / adr‑lint:** **N/A (needs CI run)** — workflow present.
  - **DoD Gate / dod:** **N/A (needs CI aggregation run)** — workflow present.
  - **CM / SemVer Tag & release assets:** **N/A (runtime evidence required)** — release workflow present.
  - **Arch (C4/ADR):** **PASS (artifacts present)** — C4 views + ADR.
- **Top wins:** Rich CI suite; explicit RTM; tailored 29119 mapping; CM plan; composite actions for LV build/test.
- **Top risks:** External runner/licensing for LV; link‑check stability; human gate approvals at tag time.
- **One‑sprint headline:** “Ship R1 with automated RTM & release evidence; run lychee/adr/doD on RC; publish VIP+notes.”

**Evidence (paths + snippets):**
- `.github/scripts/check_rtm_coverage.py` — thresholds: `MIN_HIGH_COVERAGE = 1.0`; `MIN_TOTAL_COVERAGE = 0.75`.
- `.github/workflows/rtm-coverage.yml` — enforces coverage in CI.
- `docs/dod.md` — lists gates including **PR Coverage / coverage**, **Docs Link Check / lychee**, **Traceability / rtm**, **ADR Lint**, **CM SemVer Tag**.
- `docs/architecture/README.md` — “**C4 minimal set**” with Context/Container/Component/Deployment and correspondences.
- `docs/adr/ADR-2025-001.md` — “**Adopt ADRs (MADR) and repository‑root `agent.yaml`** … *Status: Accepted*.”
- `docs/cm-plan.md` — ISO 10007 alignment; baselines; release baseline via SemVer + artifacts.

---

## B) Repo Snapshot (stack/structure/CI/paths)

- **Stack:** LabVIEW (VIs, LV project); PowerShell build/test; GitHub Actions (composite + workflows).
- **Key structure:**  
  - Source: `resource/`, `vi.lib/`, `Tooling/`, `lv_icon_editor.lvproj` (see RTM code paths).  
  - Tests: `Test/Unit Tests/...` (LabVIEW VIs); `Test/ModifyVIPBDisplayInfo.Tests.ps1`.  
  - Docs: `docs/testing/*` (policy, strategy, plan, models, TCS, procedures); `docs/requirements/rtm.csv`.  
  - Architecture: `docs/architecture/*`, `docs/adr/*`.  
  - CM/DoD: `docs/cm-plan.md`, `docs/dod.md`.
- **CI/release:** `.github/workflows/*` including:  
  `rtm-coverage.yml`, `test-report.yml`, `docs-link-check.yml`, `adr-lint.yml`, `dod-aggregator.yml`, `tag-and-release.yml`.  
  Composite actions under `.github/actions/*` (e.g., `build-vip`, `run-unit-tests`).

**Evidence (paths + snippets):**
- `.github/workflows/test-report.yml` — “**Test Report / test-report**” job.
- `.github/workflows/tag-and-release.yml` — trigger via `workflow_run: ["CI Pipeline (Composite)"]` and branch allowlist.
- `.github/actions/build-vip/action.yml` — “**Build VI Package** … build the VI package.”
- `docs/testing/test-plan.md` — front‑matter `conformance: standard: ISO/IEC/IEEE 29119-3 … type: tailored`.

---

## C) Maturity (0–5) with Top Fix

| Area | Score | One‑liner | Confidence | Top Fix |
|---|---:|---|---:|---|
| **REQ (29148)** | 4 | RTM present with code/test links | High | Ensure RC TRW checklist signed‑off |
| **ARCH (42010)** | 4 | C4 + ADRs + viewpoints declared | High | Add 1 more recent ADR at RC |
| **TEST (29119)** | 4 | Tailored docs + RTM + unit tests | High | Run CI to emit §7.3/§7.4 reports |
| **CM (10007/12207)** | 4 | CM plan + SemVer release flow | Med | Dry‑run tag & asset upload |
| **DOC (15289)** | 4 | Link‑check workflow; rich docs | Med | Resolve any lychee findings |

---

## D) Findings & Gaps → Actions

- **What I found:** RTM with thresholds; all 7 rows covered; High/Critical 2/2.  
  **Why it matters:** Risk‑based testing & completion criteria per 29119‑1/‑3.  
  **Good looks like:** High/Critical=100%; Total≥75%; CI gate green.  
  **Actions:** Keep RTM current; enforce on PRs/tags.

- **What I found:** C4 views + viewpoints and ADRs.  
  **Why it matters:** Architecture description with viewpoints/decisions per 42010.  
  **Good looks like:** Views+viewpoints+correspondences, ADR rationale.  
  **Actions:** Add ADR at RC if any change; link RTM ↔ Views.

- **What I found:** CM plan + release workflow.  
  **Why it matters:** Baselines/change control per ISO 10007.  
  **Good looks like:** SemVer tag; artifacts + notes uploaded; status accounting.  
  **Actions:** Execute tag workflow on RC; archive lychee/DoD/RTM artifacts.

- **What I found:** Link‑check/ADR‑lint/DoD aggregator present.  
  **Why it matters:** DoD gate aggregates (policy).  
  **Good looks like:** All green on PR and tag.  
  **Actions:** Run lychee/adr‑lint on R1‑RC branch; fix links/phrases.

**Evidence (paths + snippets):**
- `docs/dod.md` — “**PR Coverage Gate / coverage** … **Traceability Gate / rtm** … **ADR Lint / adr‑lint** … **Docs Link Check / lychee** … **CM / SemVer Tag**.”
- `.github/scripts/check_rtm_coverage.py` — `MIN_HIGH_COVERAGE = 1.0`; `MIN_TOTAL_COVERAGE = 0.75`.
- `docs/architecture/README.md` — “**C4 minimal set** … **Correspondences**: RTM <-> Code <-> Tests.”

---

## E) Backlog (Quick / Near / Mid)

| Horizon | Action | Impact | Effort | Owner | Std |
|---|---|---|---|---|---|
| **Quick** | Run **lychee** & **adr‑lint** on `release-rc/*`; fix any findings | Stabilize docs | S | Docs | 29119‑3 §5; 15289 |
| **Quick** | Generate §7.3 **Test Status** on PR; §7.4 **Completion** on tag | Release evidence | S | QA | 29119‑3 §7 | 
| **Near** | Dry‑run **tag-and-release** with SemVer | Tag hygiene | M | Rel Mgr | 10007 §5.4 |
| **Near** | Add 1 ADR if scope shifts | Trace decisions | S | Arch | 42010 §6/§8 |
| **Mid** | Expand performance/portability tests | NFR coverage | M | QA | 29119‑1 §4.2 |

---

## F) Coverage Verdict (29119)

- **RTM coverage (computed local):** Total **7/7 = 100%**; **High/Critical 2/2 = 100%**.  
  - File parsed: `docs/requirements/rtm.csv`.  
  - **Completion criteria:** High/Critical ≥100%; Total ≥75% (enforced by CI).  
- **Files parsed:** `rtm.csv`; test paths under `Test/Unit Tests/...` (exist).

---

## G) CM Notes (10007/12207)

- **Baselines:** Source (`lv_icon_editor.lvproj`, `resource/`, `Test/`); Requirements (`docs/requirements/rtm.csv`); Architecture/decisions (`docs/adr/*`); Release (tags `vX.Y.Z` + artifacts).  
- **Change control:** GH PRs + `tag-and-release.yml` with branch allowlist.  
- **Status accounting:** Upload lychee, DoD summary, test reports as artifacts; link in release notes.  
- **CMP Outline:** Objectives/scope; roles; baselines; change/waiver; reports; audits.

---

## H) Templates On Request

- SRS, Test Plan/Report, CM Plan, Architecture packet — already scaffolded under `docs/testing/*`, `docs/cm-plan.md`, `docs/architecture/*`.

---

## I) Compliance Trace (Finding → Std §clause)

| Finding | Clause (paraphrase) |
|---|---|
| Tailored test docs mapped and recorded | 29119‑3 **tailored conformance** & §5–§8 info items |
| Views + viewpoints + decisions recorded | 42010 **AD requires viewpoints, views, decisions** |
| CM plan, baselines, change control | ISO 10007 **CM planning, baselines, change control** |
| Risk‑based testing + completion criteria | 29119‑1 **strategy, risk‑based testing; completion criteria** |

---

## J) Assumptions & Constraints

- LabVIEW runtime/licensing and self‑hosted Windows runners available for CI.  
- GitHub permissions (release/tag) configured.  
- RC branch policy aligned with release workflow.

---

## K) Sub‑Agent Work Orders (Codex)

**S1 — Enforce RTM Coverage on PR/RC**  
- **Goal:** Keep High/Critical=100%; Total≥75%.  
- **Scope:** `docs/requirements/rtm.csv`; unit tests; CI gates.  
- **Inputs:** RTM CSV; `check_rtm_coverage.py`; `validate_rtm.py`.  
- **Design Notes:** Risk‑based per 29119‑1; §7 reports per 29119‑3.  
- **Deliverables:** Green CI steps; **test-status.md** (PR), **test-report.md** (tag).  
- **Exit:** CI shows thresholds met; artifacts uploaded.

**S2 — Docs Link Check & ADR Lint**  
- **Goal:** Zero broken links; ADRs current.  
- **Scope:** `docs/**/*.md`, `README.md`, `docs/adr/*`.  
- **Deliverables:** Lychee report; ADR‑lint log; PR fixes.  
- **Exit:** CI green on `lychee` and `adr-lint`.

**S3 — Tag & Release Dry‑Run**  
- **Goal:** Validate SemVer tag + VIP artifact upload.  
- **Scope:** `.github/workflows/tag-and-release.yml`; composite actions `build-vip`.  
- **Deliverables:** RC tag (`vX.Y.Z-rc.N`); release draft with assets.  
- **Exit:** Assets present; notes generated; no manual edits required.

**S4 — Test Evidence Generation (29119‑3 §7.3/§7.4)**  
- **Goal:** Emit progress/completion reports.  
- **Scope:** `.github/scripts/generate_test_status.py`, `generate_test_report.py`.  
- **Deliverables:** `test-status.md` (PR), `test-report.md` (tag) artifacts; links in release notes.  
- **Exit:** Artifacts uploaded and linked.

**S5 — Architecture Packet Refresh**  
- **Goal:** Current C4 + ADR index.  
- **Scope:** `docs/architecture/*`, `docs/adr/*`.  
- **Deliverables:** Updated C4 images/markdown; ≥1 recent ADR (if changes).  
- **Exit:** ADR lint green; C4 references RTM correspondences.

**S6 — CM Evidence & Status Accounting**  
- **Goal:** Archive gate outputs.  
- **Scope:** Lychee JSON, DoD summary, RTM coverage logs, test reports.  
- **Deliverables:** Linked artifacts in release; **reports/** readme.  
- **Exit:** Release contains links to all evidence.

**S7 — Runner Readiness**  
- **Goal:** Ensure LV runners OK.  
- **Scope:** `docs/ci/actions/runner-setup-guide.md`; GH env vars/secrets.  
- **Deliverables:** Checklist completed; test job run on runner.  
- **Exit:** CI composite passes on self‑hosted.

---

## L) Ready‑to‑Send Agent Packet

**Objective:** Ship **R1** with green gates and traceable evidence.  
**Scope:** RTM coverage; docs link check; ADR lint; DoD aggregator; tag & release.  
**Pre‑req:** Runner ready; GH permissions; secrets set.  
**RUNBOOK (exact):**
1. Create `release-rc/R1` branch; open PR.
2. Ensure **PR gates** green: `rtm-coverage`, `test-report`, `docs-link-check`, `adr-lint`, `dod-aggregator`.
3. When green, **merge to main**; CI composite completes.
4. Workflow **tag-and-release** runs; verify assets and notes.
5. Attach artifacts: `test-report.md`, DoD summary, lychee JSON; link in release notes.
6. Create final tag `vX.Y.Z`; publish release.

**Acceptance:** All gates green; assets uploaded; RTM High/Critical=100%, Total≥75%; C4/ADR updated; CM evidence linked.  
**Guardrails:** No manual edits to generated files on tag commit; only PRs.  
**Rollback:** If any gate fails, revert tag; fix and re‑tag.  
**Return Payload:** Release URL; artifact links; final `test-report.md` and DoD summary.

---

## PatchPack (unified diff)

> Add a lightweight **R1 Release Checklist** and a short **reports/README.md** for artifact pointers.

```diff
*** /dev/null
--- a/docs/release/r1-checklist.md
+## R1 Release Checklist
+- [ ] PR: RTM coverage gate green (High/Critical=100%, Total≥75%)
+- [ ] PR: Docs link check green
+- [ ] PR: ADR lint green
+- [ ] PR: DoD aggregator green
+- [ ] RC Tag: `tag-and-release` ran; VIP artifacts uploaded
+- [ ] RC Tag: `test-report.md` attached to release
+- [ ] Final Tag: `vX.Y.Z` published with notes and evidence links

*** /dev/null
--- a/reports/README.md
+## CI Evidence Pointers
+- Lychee JSON: see `lychee/` artifact
+- DoD summary: see `dod-summary/` artifact
+- Test status/report: see `test-status.md` / `test-report.md` artifacts
+- RTM coverage: CI logs from `rtm-coverage` job
```

---

## CHECKLIST (gates & artifacts)

- **PR Coverage Gate / coverage:** thresholds enforced; RTM updated; CI green.  
- **Docs Link Check / lychee:** no broken links; report archived.  
- **Traceability Gate / rtm:** validator & coverage scripts pass.  
- **ADR Lint / adr‑lint:** ADRs pass linting.  
- **DoD Gate / dod:** aggregator green.  
- **CM / SemVer Tag:** tag+assets present; notes generated; evidence linked.  
- **ARCH (C4/ADR):** C4 + ADR refreshed; correspondences intact.

---

## EXIT CRITERIA

- All gates green; release tag published with VIP artifacts and **linked** evidence.  
- RTM coverage at/above thresholds.  
- C4/ADR/CM docs current and referenced from release notes.

---

### Standards anchors (citations)

- 29119‑3 tailored conformance & §5–§8 info items (test docs). fileciteturn0file5  
- 42010 viewpoints, views, decisions & correspondences (architecture description). fileciteturn0file6  
- 29119‑1 risk‑based testing & test strategy/coverage concepts. fileciteturn0file7  
- ISO 10007 CM planning, baselines, change control, status accounting. fileciteturn0file9

