# Set Development Mode 🔧

Execute **`Set_Development_Mode.ps1`** to prepare the repository for active development.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `relative_path` | **Yes** | `${{ github.workspace }}` | Repository root path. |
| `scripts_folder` | **Yes** | `pipeline/scripts` | Folder containing `Set_Development_Mode.ps1`. |

## Quick-start
```yaml
- uses: ./.github/actions/set-development-mode
  with:
    relative_path: ${{ github.workspace }}
    scripts_folder: pipeline/scripts
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
