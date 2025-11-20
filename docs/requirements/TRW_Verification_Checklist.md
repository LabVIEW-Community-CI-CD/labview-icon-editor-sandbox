# TRW Verification Checklist

_Generated: 2025-11-20_

## TRW-001 — 9.1 Workflow Triggering & Scope

**Requirement:** The workflow **shall run only** in response to a `workflow_run` of the upstream workflow named **“CI Pipeline (Composite)”**.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Inspection, Demonstration

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Only `workflow_run` is declared with `workflows: [CI Pipeline (Composite)]` and `types: [completed]`.

**Agent Procedure:**
- [ ] Open `.github/workflows/tag-and-release.yml`.
- [ ] Verify `on.workflow_run.workflows` includes `CI Pipeline (Composite)` and `on.workflow_run.types` includes `completed`.
- [ ] Confirm no other event triggers (`push`, `pull_request`, schedule) are defined for this workflow.
**Evidence to Collect:** Workflow YAML snippet showing the `on: workflow_run` section.; Screenshot or log of event payload proving trigger source.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 109

---

## TRW-002 — 9.1 Workflow Triggering & Scope

**Requirement:** The workflow **shall proceed only** when the upstream `workflow_run.conclusion` equals `success`.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Workflow runs when `conclusion=success` and does not run (or exits early) when `conclusion≠success`.

**Agent Procedure:**
- [ ] Create a controlled upstream run with `conclusion=success` and another with `conclusion=failure` (e.g., dispatch or replay).
- [ ] Observe tag-and-release workflow behavior for both upstream runs.
**Evidence to Collect:** Two run URLs with conclusions and downstream run status.; Logs showing conditional gate `github.event.workflow_run.conclusion == 'success'`.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 110

---

## TRW-003 — 9.1 Workflow Triggering & Scope

**Requirement:** The workflow **shall proceed only** when the upstream workflow was triggered by a `push` event.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Downstream workflow proceeds only when upstream `event` is `push`; other events are skipped.

**Agent Procedure:**
- [ ] Ensure the job has an early `if:` guard: `github.event.workflow_run.event == 'push'`.
- [ ] Trigger an upstream run caused by `push` and one by `pull_request`; observe behavior.
**Evidence to Collect:** YAML snippet with `if: ${{ github.event.workflow_run.event == 'push' }}`.; Run logs/screens showing skip on non-push events.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 111

---

## TRW-004 — 9.1 Workflow Triggering & Scope

**Requirement:** The workflow **shall evaluate the upstream `head_branch`** against a configurable allow‑list of patterns: `main`, `develop`, `release-alpha/*`, `release-beta/*`, `release-rc/*` (default), with support for extension via configuration.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Analysis/Simulation, Test

**Primary Method (select):** Analysis/Simulation

**Acceptance Criteria:**
- Branches in allow-list proceed; others are blocked with a clear diagnostic.

**Agent Procedure:**
- [ ] Identify the allow-list patterns (e.g., `main`, `develop`, `release-*`).
- [ ] Verify gate logic evaluates `github.event.workflow_run.head_branch` against the list.
- [ ] Test with branches matching and not matching the list.
**Evidence to Collect:** Config file or YAML `if` expression showing pattern check.; Run logs from both allowed and disallowed branches.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 112

---

## TRW-005 — 9.1 Workflow Triggering & Scope

**Requirement:** For branches outside the allow‑list, the workflow **shall terminate** with a **no‑op outcome** and perform **no tag or release operations**.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- No tags or releases created; logs indicate no-op by branch policy.

**Agent Procedure:**
- [ ] Execute a run from a branch not in the allow-list.
- [ ] Confirm the workflow exits with a no-op and performs no tag or release operations.
**Evidence to Collect:** Run log capturing no-op decision.; Release/tags UI showing no changes.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 113

---

## TRW-006 — 9.1 Workflow Triggering & Scope

**Requirement:** The workflow **shall define a concurrency group** that ensures only one run per commit SHA is active at a time; subsequent runs for the same SHA **shall cancel** or **queue** per configuration.

**Type / Priority:** Process/Quality / High

**Verification Methods (from SRS):** Inspection, Demonstration

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- At most one active run per commit; either queued or cancelled per configuration.

**Agent Procedure:**
- [ ] Open workflow YAML and locate `concurrency:`.
- [ ] Verify `group` includes the commit SHA (e.g., `${{ github.sha }}`) and `cancel-in-progress: true` (or per policy).
- [ ] Trigger two runs for the same commit and observe deduping/queuing.
**Evidence to Collect:** YAML snippet of `concurrency` block.; Run timeline screenshots showing queuing/cancellation.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 114

---

## TRW-010 — 9.2 Versioning & Bump Logic

**Requirement:** The workflow **shall compute the next version** from: (a) last reachable tag; (b) parsed semantic version; and (c) commit count since that tag as **BUILD**.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Analysis/Simulation, Test

**Primary Method (select):** Analysis/Simulation

**Acceptance Criteria:**
- Version is computed from last tag, parsed semver, and commit count as build number.

**Agent Procedure:**
- [ ] Fetch full git history (`fetch-depth: 0`).
- [ ] Resolve last reachable tag and parse semantic version; determine commit count since tag.
- [ ] Compute next version candidate.
**Evidence to Collect:** Logs with last tag, parsed parts, and commit count.; Printed `VERSION_STRING`.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 120

---

## TRW-011 — 9.2 Versioning & Bump Logic

**Requirement:** When no previous tag exists, the base version **shall default to `0.1.0`** prior to applying bump rules.

**Type / Priority:** Functional / Medium

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- When no prior tag exists, version defaults to configured base (e.g., `0.1.0`).

**Agent Procedure:**
- [ ] Delete tags locally/in test repo to simulate no previous tag.
- [ ] Run version computation routine.
**Evidence to Collect:** Log excerpt showing base version fallback path.; `VERSION_STRING` value in output.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 121

---

## TRW-012 — 9.2 Versioning & Bump Logic

**Requirement:** In **PR CI context**, the bump type **shall be determined by PR labels**: `major`, `minor`, or `patch`; exactly one such label shall be present; if none, **default to `patch`**; if multiple, **fail** the computation with a clear diagnostic.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Bump type follows labels; multiple label case fails; none defaults to `patch`.

**Agent Procedure:**
- [ ] Create a PR with label `major`, then with `minor`, then with `patch`.
- [ ] Create a PR with multiple bump labels to observe failure.
- [ ] Create a PR with no bump labels to observe default.
**Evidence to Collect:** CI logs mapping label to bump type.; Failure log for multiple labels.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 122

---

## TRW-013 — 9.2 Versioning & Bump Logic

**Requirement:** In **push context on release branches**, the default bump type **shall be at least `patch`** unless overridden by explicit configuration.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Push on release branches yields at least a `patch` bump by default.

**Agent Procedure:**
- [ ] Push commits to a release branch (e.g., `release-alpha/x`).
- [ ] Observe default bump type selection (≥ patch) unless overridden in config.
**Evidence to Collect:** Logs showing selected bump type and branch context.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 123

---

## TRW-014 — 9.2 Versioning & Bump Logic

**Requirement:** The workflow **shall emit outputs**: `MAJOR`, `MINOR`, `PATCH`, `BUILD_NUMBER`, `VERSION_STRING`, and `IS_PRERELEASE`.

**Type / Priority:** Interface / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- `MAJOR`, `MINOR`, `PATCH`, `BUILD_NUMBER`, `VERSION_STRING`, and `IS_PRERELEASE` are exported and visible to subsequent steps.

**Agent Procedure:**
- [ ] Run the version step and capture exported outputs.
**Evidence to Collect:** Job output or `GITHUB_OUTPUT` file contents.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 124

---

## TRW-015 — 9.2 Versioning & Bump Logic

**Requirement:** Pre‑release suffix rules **shall** be applied by branch: `release-alpha/*` → `alpha.<BUILD>`; `release-beta/*` → `beta.<BUILD>`; `release-rc/*` → `rc.<BUILD>`; other allowed stable branches → **no suffix**.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Suffixes match `alpha.<BUILD>`, `beta.<BUILD>`, `rc.<BUILD>`; stable has none.

**Agent Procedure:**
- [ ] Execute the workflow on `release-alpha/*`, `release-beta/*`, and `release-rc/*` branches and on a stable branch.
- [ ] Verify suffix formation per branch and that stable branches have no suffix.
**Evidence to Collect:** Computed version strings for each branch case.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 125

---

## TRW-016 — 9.2 Versioning & Bump Logic

**Requirement:** Stable branches **shall** produce versions **without** any pre‑release suffix; pre‑release branches **shall** include the configured suffix.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Stable branches produce suffix-free versions; prerelease branches include suffix.

**Agent Procedure:**
- [ ] Trigger runs on stable vs prerelease branches.
- [ ] Confirm that only prerelease branches append a suffix.
**Evidence to Collect:** Logs showing `IS_PRERELEASE` and final version strings.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 126

---

## TRW-020 — 9.3 Tag Naming & Uniqueness

**Requirement:** The tag name format **shall be** `v<MAJOR>.<MINOR>.<PATCH>.<BUILD>`.

**Type / Priority:** Interface / High

**Verification Methods (from SRS):** Inspection, Test

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Tag string matches exact pattern `vX.Y.Z.N`.

**Agent Procedure:**
- [ ] Confirm tag format logic produces `v<MAJOR>.<MINOR>.<PATCH>.<BUILD>` (with optional suffix in version, not in tag).
- [ ] Generate example tags from computed version.
**Evidence to Collect:** Printed tag value; regex check result.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 132

---

## TRW-021 — 9.3 Tag Naming & Uniqueness

**Requirement:** Before creating a tag, the workflow **shall check** for an existing tag with the same name and, if present, **shall retrieve its target SHA**.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- If tag exists, corresponding object SHA is retrieved.

**Agent Procedure:**
- [ ] Query repository for tag existence (via `git ls-remote --tags` or API).
- [ ] Capture SHA if present.
**Evidence to Collect:** Command output or API response showing tag and SHA.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 133

---

## TRW-022 — 9.3 Tag Naming & Uniqueness

**Requirement:** If the tag exists and **resolves to the same commit** SHA as the current run, the workflow **shall treat the condition as success** and **shall not** create a duplicate tag; release creation may be skipped per configuration.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Existing tag on same commit is treated as success; no duplicate operations performed.

**Agent Procedure:**
- [ ] Create a tag on the same commit and rerun workflow.
- [ ] Observe that run treats it as success and optionally skips release creation per config.
**Evidence to Collect:** Logs indicating detection of same-commit tag and skip path.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 134

---

## TRW-023 — 9.3 Tag Naming & Uniqueness

**Requirement:** If the tag exists and **resolves to a different commit**, the workflow **shall fail** with a clear conflict diagnostic and **shall not** move or overwrite the tag.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Workflow fails with explicit diagnostic; tag is not moved or overwritten.

**Agent Procedure:**
- [ ] Create a tag with the same name but pointing to a different commit.
- [ ] Run the workflow and observe failure and no overwrite.
**Evidence to Collect:** Logs with the two SHAs and failure status.; Tag ref still points to original commit.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 135

---

## TRW-024 — 9.3 Tag Naming & Uniqueness

**Requirement:** The workflow **shall prevent** different branches from generating identical tags by incorporating BUILD and (where applicable) pre‑release suffix rules in §9.2.

**Type / Priority:** Quality/Design Constraint / High

**Verification Methods (from SRS):** Analysis/Simulation, Test

**Primary Method (select):** Analysis/Simulation

**Acceptance Criteria:**
- Different branches do not produce identical tags; collision path is blocked.

**Agent Procedure:**
- [ ] Run two branches that could compute the same version (e.g., ensure build numbers or suffixes disambiguate).
- [ ] Verify the workflow prevents identical tag generation across branches.
**Evidence to Collect:** Logs showing branch-safe versioning decision.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 136

---

## TRW-030 — 9.4 Artifact Requirements & Validation

**Requirement:** The workflow **shall rely on artifacts** uploaded by the upstream CI run associated with the triggering `workflow_run`.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Demonstration

**Primary Method (select):** Demonstration

**Acceptance Criteria:**
- Workflow downloads artifacts from upstream run.

**Agent Procedure:**
- [ ] Verify presence of artifact download step referencing the upstream `workflow_run` ID.
**Evidence to Collect:** Logs of artifact download with run ID.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 142

---

## TRW-031 — 9.4 Artifact Requirements & Validation

**Requirement:** The workflow **shall download** the artifacts of the triggering `workflow_run`.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Artifacts are retrieved to the runner workspace.

**Agent Procedure:**
- [ ] Enumerate artifacts available from `workflow_run` and download them.
**Evidence to Collect:** Artifact list and local file tree snapshot.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 143

---

## TRW-032 — 9.4 Artifact Requirements & Validation

**Requirement:** The workflow **shall locate exactly one** `.vip` package and **exactly one** release notes Markdown file within the downloaded artifacts.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Exactly one of each required artifact is located.

**Agent Procedure:**
- [ ] Search the artifacts for exactly one `.vip` package and exactly one release-notes markdown file.
**Evidence to Collect:** File list with counts; names of selected files.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 144

---

## TRW-033 — 9.4 Artifact Requirements & Validation

**Requirement:** The filenames of those artifacts **shall contain** the computed `VERSION_STRING` to enforce **version–artifact consistency**.

**Type / Priority:** Quality / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Both filenames contain the computed version string.

**Agent Procedure:**
- [ ] Compare computed `VERSION_STRING` against artifact filenames.
**Evidence to Collect:** Screenshot or log of filename match check.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 145

---

## TRW-034 — 9.4 Artifact Requirements & Validation

**Requirement:** If any required artifact is missing or pluralized, the workflow **shall fail** with an actionable diagnostic.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Workflow fails when artifacts are missing/duplicated, with specific error code/message.

**Agent Procedure:**
- [ ] Simulate missing or pluralized artifacts by removing or duplicating files.
- [ ] Run the workflow to observe failure with actionable diagnostics.
**Evidence to Collect:** Failure logs including diagnostic details.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 146

---

## TRW-040 — 9.5 Release Creation & Publishing

**Requirement:** The workflow **shall create a draft GitHub Release** and attach the `.vip` and release notes assets.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Draft release exists with both `.vip` and release notes attached.

**Agent Procedure:**
- [ ] Call the Releases API (or use action) to create a draft release with assets.
**Evidence to Collect:** Release page URL and asset list.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 152

---

## TRW-041 — 9.5 Release Creation & Publishing

**Requirement:** The GitHub Release **shall set** the **prerelease flag** according to `IS_PRERELEASE`.

**Type / Priority:** Interface / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Release `prerelease` flag matches computed `IS_PRERELEASE`.

**Agent Procedure:**
- [ ] Ensure `prerelease` flag in release object follows `IS_PRERELEASE`.
- [ ] Verify both true and false cases.
**Evidence to Collect:** API response or UI screenshot for both cases.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 153

---

## TRW-042 — 9.5 Release Creation & Publishing

**Requirement:** When a release with the computed tag already exists, the workflow **shall update** that release record rather than create a new one.

**Type / Priority:** Functional / Medium

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Existing release is updated in place; no duplicate release is created.

**Agent Procedure:**
- [ ] If a release with the computed tag exists, update it rather than creating a new one.
**Evidence to Collect:** Release history showing updates, not new creation.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 154

---

## TRW-043 — 9.5 Release Creation & Publishing

**Requirement:** Upon successful validation, the workflow **shall publish** the release (transition from draft) and **shall mark it as latest** per repository policy.

**Type / Priority:** Functional / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Release is published and marked latest (if applicable).

**Agent Procedure:**
- [ ] Transition a draft to published and set as latest per repo policy.
**Evidence to Collect:** Release status in UI/API.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 155

---

## TRW-044 — 9.5 Release Creation & Publishing

**Requirement:** All operations **shall authenticate** using `GITHUB_TOKEN` with `contents: write`.

**Type / Priority:** Interface/Security / High

**Verification Methods (from SRS):** Inspection, Test

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- `GITHUB_TOKEN` scopes allow required operations.

**Agent Procedure:**
- [ ] Confirm `GITHUB_TOKEN` permissions include `contents: write`.
- [ ] Attempt an operation requiring those permissions and confirm success.
**Evidence to Collect:** Permission settings and successful API call logs.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 156

---

## TRW-050 — 9.6 Error Handling, Retries & Robustness

**Requirement:** Tag push operations **shall be retried** (minimum 3 attempts, ≥5s back‑off between attempts).

**Type / Priority:** Quality/Reliability / Medium

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- Tag push is retried (e.g., 3 attempts, 5s delay) before final failure/success.

**Agent Procedure:**
- [ ] Attempt to push tag with a simulated transient error and verify retry mechanism (e.g., mock failure or use retryable command).
**Evidence to Collect:** Logs showing retry count and delays.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 162

---

## TRW-051 — 9.6 Error Handling, Retries & Robustness

**Requirement:** Release API operations **shall detect** a not‑found (404) response and **shall create** the release; other API errors **shall be handled gracefully** with diagnostics and non‑destructive behavior.

**Type / Priority:** Quality/Reliability / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- 404 triggers creation path; other errors are surfaced with graceful handling.

**Agent Procedure:**
- [ ] Invoke release API to fetch by tag; if 404, create release; handle other codes per policy.
**Evidence to Collect:** Logs for 404 branch and for non-404 error handling.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 163

---

## TRW-052 — 9.6 Error Handling, Retries & Robustness

**Requirement:** The workflow **shall be non‑destructive** with respect to existing tags; it **shall never move** an existing tag ref.

**Type / Priority:** Quality/Safety / High

**Verification Methods (from SRS):** Inspection, Test

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Existing tags are never moved automatically.

**Agent Procedure:**
- [ ] Create an existing tag and attempt to move it; verify the workflow refuses to force-update.
**Evidence to Collect:** Git command logs; tag ref remains unchanged.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 164

---

## TRW-053 — 9.6 Error Handling, Retries & Robustness

**Requirement:** Re‑runs of the workflow for the same commit and computed version **shall be idempotent**, producing no duplicate tags or releases and no conflicting state.

**Type / Priority:** Quality / High

**Verification Methods (from SRS):** Test

**Primary Method (select):** Test

**Acceptance Criteria:**
- No duplicate tags/releases are created on re-runs; operations are idempotent.

**Agent Procedure:**
- [ ] Re-run the workflow for the same commit and inputs twice.
**Evidence to Collect:** Run history and resulting refs/releases (no duplicates).

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 165

---

## TRW-060 — 9.7 Observability & Logging

**Requirement:** The workflow **shall log** at start: commit SHA, head branch, upstream `workflow_run` ID, computed `VERSION_STRING`.

**Type / Priority:** Process/Usability / Medium

**Verification Methods (from SRS):** Inspection, Demonstration

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- All required context fields are logged in a structured way.

**Agent Procedure:**
- [ ] Check logs include commit SHA, branch, workflow_run ID, and version string.
**Evidence to Collect:** Log excerpts with the four fields present.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 171

---

## TRW-061 — 9.7 Observability & Logging

**Requirement:** The workflow **shall log** decision outcomes: bump type, suffix rule applied, tag existence outcome, artifact discovery results.

**Type / Priority:** Process/Usability / Medium

**Verification Methods (from SRS):** Inspection, Demonstration

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Each decision point emits a structured log entry.

**Agent Procedure:**
- [ ] Confirm decision logs for bump, suffix rules, tag existence, and artifact discovery.
**Evidence to Collect:** Collected log entries covering all decision items.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 172

---

## TRW-062 — 9.7 Observability & Logging

**Requirement:** All failure conditions **shall include** actionable diagnostics indicating detection point, probable cause, and remediation guidance.

**Type / Priority:** Process/Quality / High

**Verification Methods (from SRS):** Inspection

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Failures include actionable diagnostics (errors, causes, next steps).

**Agent Procedure:**
- [ ] Induce a few failure modes and check that detailed diagnostics are emitted.
**Evidence to Collect:** Failure logs for representative cases.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 173

---

## TRW-070 — 9.8 Efficiency & Runner Behavior

**Requirement:** The workflow **shall perform a single repository checkout** per job.

**Type / Priority:** Process/Efficiency / Medium

**Verification Methods (from SRS):** Inspection

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Only one checkout step is present.

**Agent Procedure:**
- [ ] Ensure repository uses a single `actions/checkout` per job.
**Evidence to Collect:** Workflow YAML highlighting checkout usage.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 179

---

## TRW-071 — 9.8 Efficiency & Runner Behavior

**Requirement:** The workflow **shall ensure full Git history** is available for tag reachability and commit counting.

**Type / Priority:** Process/Correctness / High

**Verification Methods (from SRS):** Inspection, Test

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Full git history is available to the job.

**Agent Procedure:**
- [ ] Verify `fetch-depth: 0` or equivalent full-history fetch is configured.
**Evidence to Collect:** Checkout step config and `git rev-list` depth proof.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 180

---

## TRW-072 — 9.8 Efficiency & Runner Behavior

**Requirement:** The workflow **shall not leave persistent configuration side effects** on self‑hosted runners (no global git config mutations beyond the job scope).

**Type / Priority:** Process/Safety / High

**Verification Methods (from SRS):** Inspection

**Primary Method (select):** Inspection

**Acceptance Criteria:**
- Runner state is clean post-run (no orphaned files/tokens/config).

**Agent Procedure:**
- [ ] Run on a self-hosted runner and verify no persistent configuration side effects remain after completion.
**Evidence to Collect:** Before/after runner state diff, cleanup logs.

**Owner/Role:** Automation QA (Agent)  
**Phase/Gate:** CI Integration  
**Status:** Not Started  
**Last Updated:** 2025-11-20

**Test Case ID / Link:**   
**Upstream Trace:**   
**Downstream Trace:**   
**Notes:** Derived from SRS line 181

---
