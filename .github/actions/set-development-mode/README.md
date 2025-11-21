# Set Development Mode 🔧

Execute **`Set_Development_Mode.ps1`** to prepare the repository for active development.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Repository root path. |
| `minimum_supported_lv_version` | No (default `2021`) | `2023` | LabVIEW major.minor version to target. |

## Quick-start
```yaml
- uses: ./.github/actions/set-development-mode
  with:
    repository_path: ${{ github.workspace }}
    minimum_supported_lv_version: "2021"
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
