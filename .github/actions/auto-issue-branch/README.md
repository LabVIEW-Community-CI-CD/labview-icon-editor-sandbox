# Auto Issue Branch Creator

Creates a branch for an issue when the issue has all required metadata:
- Title of 30 characters or fewer
- Milestone assigned
- At least one assignee
- Labeled with `feature`, `bug`, or `task`
- Added to a project

Branches are named `issue-<number>-<short-title>` and are only created for
`feature` or `bug` issues. The issue type also determines a semantic version bump
(`feature` => major, `bug` => minor).
