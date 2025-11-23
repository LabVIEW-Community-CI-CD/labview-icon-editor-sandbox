# VS Code task shortlist

Curated workspace tasks for the local workflows we actually reach for. The headless/defaulted and release/draft helpers were removed to keep the palette small; use the underlying scripts in `.github/actions` or `scripts/` when you need automation.

- **Analyze VI Package (Pester)** – runs the analyzer (`.github/actions/analyze-vi-package/run-local.ps1`) against a `.vip` artifact; prompts for the artifact path and minimum LabVIEW version.
- **Build VI Package (Build.ps1)** – wraps `.github/actions/build/Build.ps1` with version/metadata prompts for local packaging.
- **Build VIP (stemmed artifact naming)** – builds a single-arch VIP via `scripts/build-vip-single-arch.ps1`, which prunes the other arch from the VIPB copy before invoking `build_vip.ps1`; asks for semver, build number, commit hash, and target bitness.
- **Build lvlibp (LabVIEW)** – builds the packed library with the resolved package version and selected bitness.
- **Set Dev Mode (LabVIEW)** / **Revert Dev Mode (LabVIEW)** – toggles development mode for the chosen LabVIEW bitness.

Run from `Terminal -> Run Task…` in VS Code (or `Ctrl/Cmd+Shift+B`), then pick the task.
