# VS Code task shortlist

Curated workspace tasks for the local workflows we actually reach for. The headless/defaulted and release/draft helpers were removed to keep the palette small; use the underlying scripts in `.github/actions` or `scripts/` when you need automation.

- **Analyze VI Package (Pester)** – runs the analyzer (`.github/actions/analyze-vi-package/run-local.ps1`) against a `.vip` artifact; prompts for the artifact path and minimum LabVIEW version.
- **Build/Package VIP** – choose artifact type via `buildMode` input:
  - `vip+lvlibp`: runs `.github/actions/build/Build.ps1` (apply VIPC, build both lvlibps, package 64-bit VIP).
  - `vip-single`: runs `scripts/build-vip-single-arch.ps1` to prune the other arch and package a single-arch VIP; expects the target lvlibp to exist.
- **Build lvlibp (LabVIEW)** – builds the packed library with the resolved package version and selected bitness.
- **Set Dev Mode (LabVIEW)** / **Revert Dev Mode (LabVIEW)** – toggles development mode for the chosen LabVIEW bitness.

Run from `Terminal -> Run Task…` in VS Code (or `Ctrl/Cmd+Shift+B`), then pick the task.

## What each task does

- **Analyze VI Package (Pester)**  
  - Runs `.github/actions/analyze-vi-package/run-local.ps1` against the provided `.vip` path.  
  - Uses the `minLv` input to set the minimum LabVIEW version for the analyzer.

- **Build/Package VIP**  
  - Input `buildMode=full`: executes `.github/actions/build/Build.ps1`, which:  
    - Applies the VIPC, builds lvlibp for 32- and 64-bit, updates display info, then calls `build_vip.ps1` to package the 64-bit VIP.  
    - Derives LabVIEW version from the VIPB, stamps metadata (company, author, semver, build), and writes release notes.  
  - Input `buildMode=package-only`: executes `scripts/build-vip-single-arch.ps1`, which:  
    - Copies the VIPB, removes the non-target lvlibp entries, adds an exclusion for the removed arch, and calls `build_vip.ps1`.  
    - Assumes the target lvlibp already exists (use the lvlibp build task first).  
    - Builds a single-arch VIP with your semver, build number, commit, and release notes.

- **Build lvlibp (LabVIEW)**  
  - Resolves the package LabVIEW version via `scripts/get-package-lv-version.ps1`.  
  - Calls `.github/actions/build-lvlibp/Build_lvlibp.ps1` to create the packed library for the selected bitness.

- **Set Dev Mode / Revert Dev Mode (LabVIEW)**  
  - Calls the respective `run-dev-mode.ps1` wrappers to toggle development mode for the chosen bitness.  
  - No packaging or builds occur; this only changes LabVIEW’s dev-mode state.
