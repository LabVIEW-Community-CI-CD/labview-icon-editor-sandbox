# LabVIEW Icon Editor (Integration Engine)

Open-source LabVIEW Icon Editor packaged as a `.vip`, orchestrated by the Integration Engine CLIs. Runs on Windows with LabVIEW 2021 SP1 (32- or 64-bit) and VIPM.

## Quick start (VS Code tasks)
- Prereqs: LabVIEW 2021 SP1 (bitness you need), VIPM CLI on PATH, PowerShell 7+, git with full history.
- In VS Code (**Terminal → Run Task…**):
  - `01 Verify / Apply dependencies` — apply `runner_dependencies.vipc` (both bitness).
  - `02 Build LVAddon (VI Package)` — build the `.vip` and lvlibp (defaults: 0.1.0+build 1).
  - `20 Build: Source Distribution` → `21 Verify: Source Distribution` — emit and verify the SD zip/manifest.
  - Dev mode: `06/06b/06c` bind, unbind, or clear LocalHost.LibraryPaths.
  - Tooling cache/probe: `18` clear a cache entry, `19` probe helper smoke.
  - Requirements summary: renders `reports/requirements-summary.md`.
- Details: `.vscode/tasks.json`, `docs/vscode-tasks.md`.

## Ollama locked tasks (30/31/32)
Two-turn, allowlisted PowerShell executor; timeout is prompted per task.
- Prep helpers: `28` pull image, `29` health check (endpoint + model), `30` start container, `33` stop container. Prompts cover GHCR owner/tag and OLLAMA_HOST/model tag.
- Start the published CPU image manually if preferred:  
  `docker run -d --name ollama-local -p 11435:11435 -e OLLAMA_HOST=0.0.0.0:11435 -v ollama:/root/.ollama ghcr.io/<ghcr-owner>/ollama-local:<tag>` (defaults `svelderrainruiz` / `cpu-latest`)
- Pull/tag the model the tasks expect:  
  `docker exec -it ollama-local ollama pull llama3:8b`  
  `docker exec -it ollama-local ollama cp llama3:8b llama3-8b-local`
- Tasks:
  - `30 Ollama: package-build (locked)` — build the VIP.
  - `31 Ollama: source-distribution (locked)` — build the source-distribution zip.
  - `32 Ollama: local-sd-ppl (locked)` — build PPL from the source distribution.
- Traffic stays on `http://localhost:11435`; only the allowlisted command runs.

## CLIs and scripts
- IntegrationEngineCli, OrchestrationCli, DevModeAgentCli, XCli: run via `scripts/common/invoke-repo-cli.ps1` or tasks.
- Source distribution: `scripts/build-source-distribution/Build_Source_Distribution.ps1`.
- PPL from SD: `scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1`.
- Dev mode bind/unbind: `scripts/task-devmode-bind.ps1`, `scripts/clear-labview-librarypaths-all.ps1`.
- Analyze VI packages:  
  `pwsh -NoProfile -File scripts/analyze-vi-package/run-workflow-local.ps1 -VipArtifactPath "<vip or dir>" -MinLabVIEW "21.0"`

## Docs & references
- VS Code tasks: `docs/vscode-tasks.md`
- CI overview: `docs/ci-workflows.md`
- Repo structure: `docs/adr/ADR-2025-011-repo-structure.md`
- Ollama decision: `docs/adr/ADR-2025-017-ollama-locked-executor.md`
- Requirements (ISO/IEC/IEEE 29148): `docs/requirements/requirements.csv` and summary under `reports/requirements-summary.md`
- Provenance/cache: `docs/provenance-and-cache.md`
- Additional ADRs: `docs/adr/adr-index.md`

## Notes
- VIPM missing? Dependency task will fail and LVAddon build writes `vipm-skipped-placeholder.vip`; install VIPM, remove the placeholder, rerun task 02.
- Tooling cache is tiered (worktree → source → cache → publish). Use task 18 to clear a specific `<CLI>/<version>/<rid>`; task 19 exercises probe behavior.
- Devcontainer (Ollama bench): `.devcontainer/` adds Docker CLI + model cache volume; good for dotnet tooling and Ollama/executor iteration. LabVIEW/VIPM builds remain Windows-only. Defaults: `OLLAMA_HOST=http://localhost:11435`, `OLLAMA_IMAGE=ghcr.io/svelderrainruiz/ollama-local:cpu-latest`, `OLLAMA_MODEL_TAG=llama3-8b-local`.
