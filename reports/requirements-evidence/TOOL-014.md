# TOOL-014 Evidence (no hardcoded csproj/cache paths; isolated artifacts)

- Run: https://github.com/LabVIEW-Community-CI-CD/labview-icon-editor-sandbox/actions/runs/19805027026 (branch `chore/actions-envfiles-upgrade-sergio`)
- Result: CI completed with zero missing-path warnings; Source Distribution artifacts and manifests published under `builds-isolated` and uploaded.
- Artifacts: `labview-icon-editor-sandbox-source-distribution` (zip + manifest.json/csv), `labview-icon-editor-sandbox-build-reports`, `labview-icon-editor-sandbox-log-stash`.
- Notes: Workflow enforces staging into `builds-isolated/builds/...` and fails fast if isolated paths are absent. Helpers invoked by CLI name; no hardcoded csproj/cache paths remain. 
