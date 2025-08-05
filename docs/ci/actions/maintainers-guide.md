# Maintainers Guide

## Introduction

Maintainers of the LabVIEW Icon Editor project handle day-to-day repository upkeep, oversee contributions, and coordinate with NI’s Open-Source Program. This guide outlines the responsibilities and processes for maintainers.

*(For details on overall project governance—Steering Committee roles and the BDFL approach—see [**`GOVERNANCE.md`**](../../../GOVERNANCE.md).)*

## Role of Maintainers

- **Code Reviews and Merging** – Review incoming pull requests for quality, style, and alignment with project goals. Only maintainers (and the Steering Committee) have write access to merge PRs. All merges follow the rule of passing CI and at least one maintainer approval.  
- **Issue Triage** – Regularly monitor GitHub Issues and Discussions. Label issues appropriately (e.g., bugs, enhancements, “Workflow: Open to contribution”), and close or consolidate duplicates.
- **Community Support** – Engage on Discord and Discussion forums to answer contributor questions. Help new contributors find starter issues.
- **Releases** – Work with NI release engineers or the Open-Source Program Manager to coordinate publishing new versions. Maintainers ensure that the `develop` branch is ready for release merges into `main`.

## Creating Feature Branches

When an issue is approved for work, maintainers must create a branch tied directly to that issue so the CI pipeline can validate its status.

1. **Name the branch** `issue-<number>-<short-description>` (for example, `issue-123-fix-toolbar`).
2. **Set the issue’s Status** field to `In Progress`. The [composite CI workflow](../../../.github/workflows/ci-composite.yml) checks this field and will skip most jobs if the issue is not marked in progress.
3. **Branch from `develop`** and push the branch to the main repository so contributors can begin work.
4. **Open PRs** from the `issue-<number>` branch into `develop` (or another target as appropriate).

This process ensures that each feature branch is traceable to a GitHub issue and that CI only runs for actively tracked work.

## Admin Tasks and Final Merges

Certain actions require NI administrative oversight or special approval:

- **Experiment Branch Approval** – When a long-lived experiment branch is ready to distribute artifacts (VIPs), a maintainer coordinates with the NI Open-Source Program Manager (OSPM) to run the “approve-experiment” workflow. This enables CI artifact publishing for that experiment branch.
- **Finalizing Experiment Merges** – After an experiment concludes, maintainers help prepare the final merge into `develop`. This includes ensuring a proper version label (major/minor/patch) is applied and that any “NoCI” labels or temporary settings are cleaned up. The OSPM or designated NI staff will typically give the final go-ahead for the merge after Steering Committee approval.  
- **Critical Hotfixes** – In rare cases (e.g., a critical issue in an official release), maintainers may create or approve a `hotfix/*` branch targeting `main`. Such hotfixes should be done in coordination with NI (to ensure the fix is included in official builds). After merging into `main`, the changes should also be merged back into `develop` to keep branches in sync.

## Best Practices for Maintainers

- **Consistency** – Follow the project’s coding standards and guidelines (see CONTRIBUTING.md) when reviewing or writing code. This sets an example for external contributors.  
- **Communication** – Keep the community informed. If you merge a significant PR or introduce a new requirement (e.g., a new build step), mention it in the project’s Discussion forum or release notes.  
- **Transparency** – Except for confidential matters (like security issues before disclosure), conduct discussions in public channels (issues, PRs, discussions) rather than private emails. This ensures community members can stay informed and contribute.  
- **Inclusive Culture** – Encourage contributions of all kinds (code, docs, testing). Recognize and thank community members for their efforts. If someone’s PR isn’t up to standard, provide constructive feedback and guidance rather than closing without explanation.  
- **Upstream Sync** – Keep your local repository and any forks you maintain updated with the latest `develop` branch. This helps in testing and in guiding contributors (so you catch integration issues early).

## Continuous Improvement

Maintainers are also responsible for improving project infrastructure over time:
- Propose and implement workflow enhancements (for CI, code quality checks, etc.). 
- Update documentation when processes change or new tools are adopted. 
- Mentor new maintainers as the team grows, sharing knowledge about the project’s history and decisions.

By adhering to this guide, maintainers ensure that the LabVIEW Icon Editor project remains healthy, collaborative, and aligned with both community needs and NI’s quality standards.
