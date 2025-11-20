# Software Requirements Specification (SRS) — Tag‑and‑Release Workflow (GitHub Actions)

**Document ID:** TRW‑SRS‑001  
**Version:** 1.0.0  
**Date:** 2025-11-20  
**Status:** Draft (Tailored 29148 Conformance)  
**Information Item Type:** Software Requirements Specification (SRS) tailored per ISO/IEC/IEEE 29148:2018, Clause 9.6

---

## Revision History

| Version | Date | Author | Summary of Changes |
|---|---|---|---|
| 1.0.0 | 2025-11-20 | Project Automation | Initial 29148‑compliant rewrite of the supplied functional requirements for the Tag‑and‑Release workflow |

---

## Table of Contents

1. [Purpose](#1-purpose)  
2. [Scope](#2-scope)  
3. [Product Perspective](#3-product-perspective)  
4. [Definitions, Acronyms, and Abbreviations](#4-definitions-acronyms-and-abbreviations)  
5. [References](#5-references)  
6. [Assumptions and Dependencies](#6-assumptions-and-dependencies)  
7. [External Interfaces](#7-external-interfaces)  
8. [System Overview and Modes](#8-system-overview-and-modes)  
9. [Specified Requirements](#9-specified-requirements)  
   * 9.1 [Workflow Triggering & Scope](#91-workflow-triggering--scope)  
   * 9.2 [Versioning & Bump Logic](#92-versioning--bump-logic)  
   * 9.3 [Tag Naming & Uniqueness](#93-tag-naming--uniqueness)  
   * 9.4 [Artifact Requirements & Validation](#94-artifact-requirements--validation)  
   * 9.5 [Release Creation & Publishing](#95-release-creation--publishing)  
   * 9.6 [Error Handling, Retries & Robustness](#96-error-handling-retries--robustness)  
   * 9.7 [Observability & Logging](#97-observability--logging)  
   * 9.8 [Efficiency & Runner Behavior](#98-efficiency--runner-behavior)  
10. [Verification](#10-verification)  
11. [Requirements Traceability Matrix (to Source List)](#11-requirements-traceability-matrix-to-source-list)  
12. [Tailoring Statement](#12-tailoring-statement)  
13. [Appendix A — Version Computation Rules (Normative)](#appendix-a--version-computation-rules-normative)

---

## 1. Purpose

This Software Requirements Specification (SRS) defines the requirements for an automated **Tag‑and‑Release** workflow implemented in GitHub Actions. The workflow creates immutable tags and publishes GitHub Releases for builds that pass continuous integration (CI), in alignment with Semantic Versioning and controlled branch policies.

## 2. Scope

The workflow and requirements herein apply to a single repository hosting the product source code and CI workflows. The SRS focuses on functional behavior, decision logic, non‑destructive release operations, and observability. It excludes detailed design, runner image build steps, and organization‑level governance.

## 3. Product Perspective

The Tag‑and‑Release workflow is an automation component in the repository’s delivery pipeline. It is **triggered by a `workflow_run`** event from the upstream “CI Pipeline (Composite)” workflow and interacts with:
* Git (tags; repository history).
* GitHub Releases and the Releases/Tags APIs.
* GitHub Actions artifact storage (to fetch build outputs and release notes).

## 4. Definitions, Acronyms, and Abbreviations

- **Build Number** — Count of commits since the last reachable version tag on the branch’s ancestry.  
- **CI** — Continuous Integration.  
- **GITHUB_TOKEN** — Repository‑scoped token provided by GitHub Actions for API operations.  
- **Prerelease** — A version with a pre‑release suffix (e.g., `alpha`, `beta`, `rc`).  
- **SemVer** — Semantic Versioning `MAJOR.MINOR.PATCH` with an additional build number component for tag uniqueness (`vMAJOR.MINOR.PATCH.BUILD`).  
- **VIP package** — The single distributable `.vip` artifact to be attached to releases.  

## 5. References

- ISO/IEC/IEEE 29148:2018 — *Systems and software engineering — Life cycle processes — Requirements engineering*.  
- GitHub Actions and GitHub Releases public documentation.  

## 6. Assumptions and Dependencies

- The upstream “CI Pipeline (Composite)” workflow produces and uploads required artifacts (exactly one `.vip` and exactly one release‑notes `.md`).  
- The repository grants the workflow `contents: write` scope through `GITHUB_TOKEN`.  
- Full Git history is available to compute reachable tags and commit counts.  
- Branch‑to‑release channel mapping follows project conventions listed in §9.2.6.

## 7. External Interfaces

- **Git Interface:** reading commit history; creating annotated tags.  
- **GitHub Releases API:** creating/updating draft releases; publishing releases; attaching assets.  
- **GitHub Artifacts API:** querying and downloading workflow_run artifacts.  

## 8. System Overview and Modes

- **Stable Mode:** When the head branch is mapped to a stable channel (e.g., `main`, `develop` per configuration), versions are **without** pre‑release suffix.  
- **Prerelease Modes:** Branches mapped to prerelease channels (`release-alpha/*`, `release-beta/*`, `release-rc/*`) append `alpha.<BUILD>`, `beta.<BUILD>`, or `rc.<BUILD>` respectively.  
- **No‑Op Mode:** When triggering conditions or branch policies are not satisfied, the workflow exits with a no‑operation result without side effects.

---

## 9. Specified Requirements

### Verification Methods Legend
- **I** = Inspection (of configuration, logs, manifests)  
- **A** = Analysis/Static Evaluation (e.g., dry runs, expressions)  
- **D** = Demonstration (observing behavior in a controlled run)  
- **T** = Test (automated, with assertions)

Each requirement below is **uniquely identified** and uses normative “shall” language. It includes attributes for *Type*, *Priority*, and *Verification* (per ISO/IEC/IEEE 29148).

### 9.1 Workflow Triggering & Scope

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑001 | The workflow **shall run only** in response to a `workflow_run` of the upstream workflow named **“CI Pipeline (Composite)”**. | Functional | High | I, D |
| TRW‑002 | The workflow **shall proceed only** when the upstream `workflow_run.conclusion` equals `success`. | Functional | High | T |
| TRW‑003 | The workflow **shall proceed only** when the upstream workflow was triggered by a `push` event. | Functional | High | T |
| TRW‑004 | The workflow **shall evaluate the upstream `head_branch`** against a configurable allow‑list of patterns: `main`, `develop`, `release-alpha/*`, `release-beta/*`, `release-rc/*` (default), with support for extension via configuration. | Functional | High | A, T |
| TRW‑005 | For branches outside the allow‑list, the workflow **shall terminate** with a **no‑op outcome** and perform **no tag or release operations**. | Functional | High | T |
| TRW‑006 | The workflow **shall define a concurrency group** that ensures only one run per commit SHA is active at a time; subsequent runs for the same SHA **shall cancel** or **queue** per configuration. | Process/Quality | High | I, D |

### 9.2 Versioning & Bump Logic

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑010 | The workflow **shall compute the next version** from: (a) last reachable tag; (b) parsed semantic version; and (c) commit count since that tag as **BUILD**. | Functional | High | A, T |
| TRW‑011 | When no previous tag exists, the base version **shall default to `0.1.0`** prior to applying bump rules. | Functional | Medium | T |
| TRW‑012 | In **PR CI context**, the bump type **shall be determined by PR labels**: `major`, `minor`, or `patch`; exactly one such label shall be present; if none, **default to `patch`**; if multiple, **fail** the computation with a clear diagnostic. | Functional | High | T |
| TRW‑013 | In **push context on release branches**, the default bump type **shall be at least `patch`** unless overridden by explicit configuration. | Functional | High | T |
| TRW‑014 | The workflow **shall emit outputs**: `MAJOR`, `MINOR`, `PATCH`, `BUILD_NUMBER`, `VERSION_STRING`, and `IS_PRERELEASE`. | Interface | High | T |
| TRW‑015 | Pre‑release suffix rules **shall** be applied by branch: `release-alpha/*` → `alpha.<BUILD>`; `release-beta/*` → `beta.<BUILD>`; `release-rc/*` → `rc.<BUILD>`; other allowed stable branches → **no suffix**. | Functional | High | T |
| TRW‑016 | Stable branches **shall** produce versions **without** any pre‑release suffix; pre‑release branches **shall** include the configured suffix. | Functional | High | T |

### 9.3 Tag Naming & Uniqueness

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑020 | The tag name format **shall be** `v<MAJOR>.<MINOR>.<PATCH>.<BUILD>`. | Interface | High | I, T |
| TRW‑021 | Before creating a tag, the workflow **shall check** for an existing tag with the same name and, if present, **shall retrieve its target SHA**. | Functional | High | T |
| TRW‑022 | If the tag exists and **resolves to the same commit** SHA as the current run, the workflow **shall treat the condition as success** and **shall not** create a duplicate tag; release creation may be skipped per configuration. | Functional | High | T |
| TRW‑023 | If the tag exists and **resolves to a different commit**, the workflow **shall fail** with a clear conflict diagnostic and **shall not** move or overwrite the tag. | Functional | High | T |
| TRW‑024 | The workflow **shall prevent** different branches from generating identical tags by incorporating BUILD and (where applicable) pre‑release suffix rules in §9.2. | Quality/Design Constraint | High | A, T |

### 9.4 Artifact Requirements & Validation

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑030 | The workflow **shall rely on artifacts** uploaded by the upstream CI run associated with the triggering `workflow_run`. | Functional | High | D |
| TRW‑031 | The workflow **shall download** the artifacts of the triggering `workflow_run`. | Functional | High | T |
| TRW‑032 | The workflow **shall locate exactly one** `.vip` package and **exactly one** release notes Markdown file within the downloaded artifacts. | Functional | High | T |
| TRW‑033 | The filenames of those artifacts **shall contain** the computed `VERSION_STRING` to enforce **version–artifact consistency**. | Quality | High | T |
| TRW‑034 | If any required artifact is missing or pluralized, the workflow **shall fail** with an actionable diagnostic. | Functional | High | T |

### 9.5 Release Creation & Publishing

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑040 | The workflow **shall create a draft GitHub Release** and attach the `.vip` and release notes assets. | Functional | High | T |
| TRW‑041 | The GitHub Release **shall set** the **prerelease flag** according to `IS_PRERELEASE`. | Interface | High | T |
| TRW‑042 | When a release with the computed tag already exists, the workflow **shall update** that release record rather than create a new one. | Functional | Medium | T |
| TRW‑043 | Upon successful validation, the workflow **shall publish** the release (transition from draft) and **shall mark it as latest** per repository policy. | Functional | High | T |
| TRW‑044 | All operations **shall authenticate** using `GITHUB_TOKEN` with `contents: write`. | Interface/Security | High | I, T |

### 9.6 Error Handling, Retries & Robustness

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑050 | Tag push operations **shall be retried** (minimum 3 attempts, ≥5s back‑off between attempts). | Quality/Reliability | Medium | T |
| TRW‑051 | Release API operations **shall detect** a not‑found (404) response and **shall create** the release; other API errors **shall be handled gracefully** with diagnostics and non‑destructive behavior. | Quality/Reliability | High | T |
| TRW‑052 | The workflow **shall be non‑destructive** with respect to existing tags; it **shall never move** an existing tag ref. | Quality/Safety | High | I, T |
| TRW‑053 | Re‑runs of the workflow for the same commit and computed version **shall be idempotent**, producing no duplicate tags or releases and no conflicting state. | Quality | High | T |

### 9.7 Observability & Logging

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑060 | The workflow **shall log** at start: commit SHA, head branch, upstream `workflow_run` ID, computed `VERSION_STRING`. | Process/Usability | Medium | I, D |
| TRW‑061 | The workflow **shall log** decision outcomes: bump type, suffix rule applied, tag existence outcome, artifact discovery results. | Process/Usability | Medium | I, D |
| TRW‑062 | All failure conditions **shall include** actionable diagnostics indicating detection point, probable cause, and remediation guidance. | Process/Quality | High | I |

### 9.8 Efficiency & Runner Behavior

| ID | Requirement Statement | Type | Priority | Verification |
|---|---|---|---|---|
| TRW‑070 | The workflow **shall perform a single repository checkout** per job. | Process/Efficiency | Medium | I |
| TRW‑071 | The workflow **shall ensure full Git history** is available for tag reachability and commit counting. | Process/Correctness | High | I, T |
| TRW‑072 | The workflow **shall not leave persistent configuration side effects** on self‑hosted runners (no global git config mutations beyond the job scope). | Process/Safety | High | I |

---

## 10. Verification

Verification methods are assigned per requirement in §9. The project shall produce automated tests and/or demonstrations for high‑priority functional requirements (§§9.1–9.5), and inspections for process and safety constraints (§§9.6–9.8).

**Acceptance Criteria Examples:**
- **Tag Conflict Handling (TRW‑023):** Given an existing tag pointing to a different commit, a workflow run shall exit non‑success and include a diagnostic that identifies both SHAs. *(T)*  
- **Idempotency (TRW‑053):** Two sequential runs against the same commit and inputs shall result in exactly one tag and one release object, with the second run performing no mutations. *(T, D)*  
- **Artifact Consistency (TRW‑033):** The `.vip` and release notes filenames shall include the computed `VERSION_STRING`; runs with mismatches shall fail with a specific error code. *(T)*  

---

## 11. Requirements Traceability Matrix (to Source List)

| Source Ref (Provided List) | New ID(s) |
|---|---|
| 1.1, 1.2, 1.3 | TRW‑001, TRW‑002, TRW‑003 |
| 1.4 | TRW‑004 |
| 1.5 | TRW‑005 |
| 1.6 | TRW‑006 |
| 2.1 | TRW‑010 |
| 2.2 | TRW‑011 |
| 2.3 | TRW‑012 |
| 2.4 | TRW‑013 |
| 2.5 | TRW‑014 |
| 2.6 | TRW‑015 |
| 2.7 | TRW‑016 |
| 3.1 | TRW‑020 |
| 3.2 | TRW‑021 |
| 3.3 | TRW‑022 |
| 3.4 | TRW‑023 |
| 3.5 | TRW‑024 |
| 4.1, 4.2 | TRW‑030, TRW‑031 |
| 4.3 | TRW‑032 |
| 4.4 | TRW‑033 |
| 4.5 | TRW‑034 |
| 5.1–5.5 | TRW‑040–TRW‑044 |
| 6.1–6.4 | TRW‑050–TRW‑053 |
| 7.1–7.3 | TRW‑060–TRW‑062 |
| 8.1–8.3 | TRW‑070–TRW‑072 |

---

## 12. Tailoring Statement

This SRS follows the **ISO/IEC/IEEE 29148:2018 SRS information item content** (Clause 9.6) and applies requirement attributes and verification methods consistent with §5.2 and §6.5 of the standard. It claims **tailored conformance** limited to the software workflow scope and does not include separate BRS or StRS items. Additional organizational information items may be produced separately if required by governance.

---

## Appendix A — Version Computation Rules (Normative)

1. **Last Reachable Tag:** Determine the nearest tag reachable from `HEAD` on the head branch ancestry that matches `vMAJOR.MINOR.PATCH.BUILD` and (if present) the branch’s prerelease channel.  
2. **Commit Count as BUILD:** Count commits since that tag within the branch ancestry; assign as `BUILD`. If no tag, `BUILD = 0`.  
3. **Bump Type:** Apply rules per §9.2 (PR labels or push defaults). Increment `MAJOR`, `MINOR`, or `PATCH` starting from the last reachable version (or `0.1.0` seed). Reset lower order components on bump.  
4. **Prerelease Suffix:** Apply suffix per branch channel; stable branches have no suffix.  
5. **Outputs:** Emit `MAJOR`, `MINOR`, `PATCH`, `BUILD_NUMBER`, `VERSION_STRING`, `IS_PRERELEASE`.  
6. **Determinism:** Given identical inputs (commit SHA, branch, labels, allow‑list, and upstream artifacts), the computation is deterministic and idempotent.

