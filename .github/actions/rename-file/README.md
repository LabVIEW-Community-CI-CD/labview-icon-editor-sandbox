# Rename File ✏️

Use **`Rename-file.ps1`** to rename a file within the repository.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `current_filename` | **Yes** | `resource/plugins/lv_icon.lvlibp` | Existing file path. |
| `new_filename` | **Yes** | `lv_icon_x64.lvlibp` | New file name or path. |
| `scripts_folder` | **Yes** | `pipeline/scripts` | Folder containing `Rename-file.ps1`. |

## Quick-start
```yaml
- uses: ./.github/actions/rename-file
  with:
    current_filename: resource/plugins/lv_icon.lvlibp
    new_filename: lv_icon_x64.lvlibp
    scripts_folder: pipeline/scripts
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
