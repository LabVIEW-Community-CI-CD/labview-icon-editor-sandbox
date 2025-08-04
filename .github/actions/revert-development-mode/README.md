# Revert Development Mode 🔄

Invoke **`RevertDevelopmentMode.ps1`** to restore packaged sources after development work.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `relative_path` | **Yes** | `${{ github.workspace }}` | Repository root path. |
| `scripts_folder` | **Yes** | `pipeline/scripts` | Folder containing `RevertDevelopmentMode.ps1`. |

## Quick-start
```yaml
- uses: ./.github/actions/revert-development-mode
  with:
    relative_path: ${{ github.workspace }}
    scripts_folder: pipeline/scripts
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
