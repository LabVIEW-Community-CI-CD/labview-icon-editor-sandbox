# Maintainers Technical Guide

This guide is a technical reference for maintainers working in the LabVIEW Icon
Editor repository. It outlines the workflows and GitHub Actions used to manage
branches, run continuous integration (CI), and finalize releases.

## Feature Branch Workflow

1. Confirm the related GitHub issue is approved for work.
2. Create a branch from `develop` named `issue-<number>-<short-description>`
   (for example, `issue-123-fix-toolbar`).
3. Set the issue's **Status** field to `In Progress`. The
   [composite CI workflow](../../../.github/workflows/ci-composite.yml) skips
   most jobs when the status is not set.
4. Push the branch to the main repository and open a pull request targeting
   `develop` (or another appropriate branch).
5. Ensure CI passes and obtain at least one maintainer approval before merging.

## Workflow Administration

- **Approve experiment branches** – When an experiment branch should publish
  artifacts (VIPs), run the `approve-experiment` workflow in GitHub Actions.
  Coordinate with the NI Open-Source Program Manager (OSPM) before execution.
- **Finalize experiment merges** – Prior to merging an experiment branch into
  `develop`, apply an appropriate version label (major/minor/patch) and remove
  any temporary settings or `NoCI` labels. The OSPM or designated NI staff
  typically gives the final approval.
- **Hotfix branches** – For critical fixes on an official release, create or
  approve a `hotfix/*` branch targeting `main`. After merging into `main`, merge
  the changes back into `develop` to keep branches synchronized.

## Release Preparation

Maintainers ensure that `develop` remains in a releasable state. Coordinate with
release engineers or the OSPM to merge into `main` and publish packages when a
release is planned.

## Additional Resources

- Repository governance is described in [GOVERNANCE.md](../../../GOVERNANCE.md).
- Action-specific documentation is available in this directory's other guides.
