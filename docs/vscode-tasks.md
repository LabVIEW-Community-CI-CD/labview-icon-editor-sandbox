# VS Code task shortlist

Curated workspace tasks for the local workflows we actually reach for. The headless/defaulted and release/draft helpers were removed to keep the palette small; use the underlying scripts in `.github/actions` or `scripts/` when you need automation.

- **Analyze VI Package (Pester)** – runs the analyzer (`.github/actions/analyze-vi-package/run-local.ps1`) against a `.vip` artifact; prompts for the artifact path and minimum LabVIEW version.
- **Build/Package VIP** – choose mode via `buildMode` input:
  - `full`: runs `.github/actions/build/Build.ps1` (apply VIPC, build both lvlibps, package 64-bit VIP).
  - `package-only`: runs `scripts/build-vip-single-arch.ps1` to prune the other arch and package a single-arch VIP; expects the target lvlibp to exist.
- **Build lvlibp (LabVIEW)** – builds the packed library with the resolved package version and selected bitness.
- **Set Dev Mode (LabVIEW)** / **Revert Dev Mode (LabVIEW)** – toggles development mode for the chosen LabVIEW bitness.

Run from `Terminal -> Run Task…` in VS Code (or `Ctrl/Cmd+Shift+B`), then pick the task.
