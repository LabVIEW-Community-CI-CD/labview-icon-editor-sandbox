# VS Code task shortlist

Curated workspace tasks for the local workflows we actually reach for. The headless/defaulted and release/draft helpers were removed to keep the palette small; use the underlying scripts in `.github/actions` or `scripts/` when you need automation.

- **Analyze VI Package (Pester)** – runs the analyzer (`.github/actions/analyze-vi-package/run-local.ps1`) against a `.vip` artifact; prompts for the artifact path and minimum LabVIEW version.
- **Build VI Package (Build.ps1)** – full pipeline (apply VIPC, build both lvlibps, package 64-bit VIP) via `.github/actions/build/Build.ps1` with version/metadata prompts.
- **Package VIP (single-arch, package-only)** – packages one arch via `scripts/build-vip-single-arch.ps1`, pruning the other arch from a temp VIPB before invoking `build_vip.ps1`; asks for semver, build number, commit hash, and target bitness, and expects the target lvlibp to exist.
- **Build lvlibp (LabVIEW)** – builds the packed library with the resolved package version and selected bitness.
- **Set Dev Mode (LabVIEW)** / **Revert Dev Mode (LabVIEW)** – toggles development mode for the chosen LabVIEW bitness.

Run from `Terminal -> Run Task…` in VS Code (or `Ctrl/Cmd+Shift+B`), then pick the task.
