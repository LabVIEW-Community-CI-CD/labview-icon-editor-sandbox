# Run Unit Tests ✅

Invoke **`RunUnitTests.ps1`** to execute LabVIEW unit tests and output a result table.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW major version. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `scripts_folder` | **Yes** | `pipeline/scripts` | Folder containing `RunUnitTests.ps1`. |

## Quick-start
```yaml
- uses: ./.github/actions/run-unit-tests
  with:
    minimum_supported_lv_version: 2024
    supported_bitness: 64
    scripts_folder: pipeline/scripts
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
