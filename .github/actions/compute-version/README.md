# Compute Version

This composite action determines the semantic version for the build based on commit history, branch naming conventions and pull request labels.

## Inputs
- `github_token`: GitHub token with repository access.

## Outputs
- `VERSION`: Full version string (e.g. `v1.2.3-build4`).
- `MAJOR`, `MINOR`, `PATCH`: Numeric version components.
- `BUILD`: Commit-based build number.
- `IS_PRERELEASE`: `true` when branch naming implies prerelease.

## Example
```yaml
- id: version
  uses: ./.github/actions/compute-version
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
- run: echo "Version is ${{ steps.version.outputs.VERSION }}"
```
