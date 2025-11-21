
# Analyze VI Package (Pester policy suite)

This repo contains:
- `VIPReader.psm1` — helper functions that read a `.vip` directly and parse its `spec`.
- `Analyze-VIP.Tests.ps1` — Pester tests mapped 1:1 to policy requirement IDs.
- `Requirements.md` — normative requirements (policy, version-agnostic).
- `action.yml` — GitHub composite action **Analyze VI Package** to run the tests in CI.

## Local run
```powershell
pwsh -NoProfile -File ./Analyze-VIP.Tests.ps1 -VipPath "/mnt/data/work/ni_icon_editor-0.0.2.16.vip" -MinLabVIEW "21.0"
```

## GitHub Actions usage
```yaml
jobs:
  analyze:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./vip-analyzer
        with:
          vip_path: "/mnt/data/work/ni_icon_editor-0.0.2.16.vip"
          min_labview: "21.0"
```

