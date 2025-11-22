# Run Unit Tests ✅

Invoke **`RunUnitTests.ps1`** to execute LabVIEW unit tests and output a result table.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Workspace root; version is resolved from the repo VIPB. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |

## Quick-start
```yaml
- uses: ./.github/actions/run-unit-tests
  with:
    repository_path: ${{ github.workspace }}
    supported_bitness: 64
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
