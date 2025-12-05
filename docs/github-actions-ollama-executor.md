# GitHub Actions for Ollama Executor

## Overview

Two GitHub Actions workflows provide automated testing and build capabilities for the Ollama Executor.

## Workflows

### Smoke Test Hard Gate (`ollama-executor-smoke.yml`)

Purpose: Quality gate that blocks PR merges if critical tests fail.

#### Build triggers

- Pull requests modifying:
  - `scripts/ollama-executor/**`
  - `.devcontainer/**`
  - `install-ollama.ps1`
- Pushes to `main` or `develop`

#### Build workflow jobs

##### Smoke workflow jobs

#### `smoke-test` (Multi-OS Matrix)

Runs critical tests on Linux, Windows, and macOS:

- Command vetting tests (26 cases)
- Simulation mode tests (4 scenarios)
- Conversation scenario tests
- Timeout/failure tests
- Security fuzzing (1,000+ attack vectors)
- Regression tests (2 tracked bugs)
- Fast test suite

Artifacts:

- Test results (JSON/XML)
- Test reports (HTML)
- Handshake JSON (validated by composite action)

#### `security-gate` (Hard Gate)

Hard gate that blocks merge on failure.

- Runs comprehensive security fuzzing
- Verifies no regressions in fixed bugs
- Exit code 1 = merge blocked

#### `performance-baseline`

- Runs performance benchmarks
- Uploads baseline for tracking
- Does not block merge (warning only)

#### `summary`

- Aggregates all results
- Posts summary comment to PR with gate status, coverage, and log links

Example PR Comment

```markdown
## 🧪 Ollama Executor Smoke Test Results

| Test Category | Status |
|---------------|--------|
| Smoke Tests (Multi-OS) | ✅ success |
| Security Hard Gate | ✅ success |
| Performance Baseline | ✅ success |

### Test Coverage
- ✅ Command vetting (26 test cases)
- ✅ Simulation mode (4 scenarios)
- ✅ Security fuzzing (1000+ attack vectors)
- ✅ Regression tracking (all fixed bugs)
- ✅ Cross-platform (Linux, Windows, macOS)

🎉 **All gates passed!** This PR is ready to merge.
```

---

### Build Automation (`ollama-executor-build.yml`)

Purpose: Automated builds using the locked Ollama executor.

#### Triggers

- `workflow_dispatch` with parameters
- Pull requests touching build/executor scripts

#### Inputs (workflow_dispatch)

- `goal`: Build goal description (e.g., "Build Source Distribution LV2025 64-bit")
- `max_turns`: Maximum conversation turns (default: 10)
- `simulation`: Use simulation mode (default: true)

#### Jobs

#### `ollama-build-simulation`

Runs on PRs and when `simulation=true`.

- Uses mock Ollama server
- Enables simulation mode (no real LabVIEW)
- Runs `Drive-Ollama-Executor.ps1`
- Creates stub artifacts fast

Environment defaults:

```yaml
OLLAMA_EXECUTOR_MODE: sim
OLLAMA_SIM_DELAY_MS: 50
OLLAMA_SIM_CREATE_ARTIFACTS: true
OLLAMA_HOST: http://localhost:11436
OLLAMA_MODEL_TAG: llama3-8b-local
OLLAMA_REQUIREMENTS_APPLIED: OEX-PARITY-001,OEX-PARITY-002,OEX-PARITY-003,OEX-PARITY-004
```

#### `ollama-build-real`

Runs when `simulation=false` (dispatch only) on a Windows LV runner.

- Uses real Ollama service (port 11435) and LabVIEW
- Runs `Run-Ollama-Host.ps1` (locked executor path)
- Enforces seed image preflight; records LV version/bitness in summary
- Validates handshake JSON via composite action

#### `multi-platform-build` (Matrix)

Runs on PRs in simulation mode.

- LabVIEW versions: 2021, 2025
- Bitness: 32-bit, 64-bit
- Uses mock server + executor to create platform-specific artifacts

#### `reset-source-dist-sim`

Runs the locked Source Distribution reset flow against the mock host in simulation mode and uploads the reset summary plus logs.

#### `vi-history-sim`

Runs the locked VI History flow against the mock host in simulation mode and uploads VI history reports and its handshake file.

#### `comment-results`

Posts build summary to PR.

---

## Usage Examples

### Run Smoke Tests (Automatic on PR)

1) Open a PR touching executor or devcontainer files.
2) Smoke test workflow runs automatically.
3) Review PR comment and artifacts for results.

### Simulate a Build (Manual)

1) Actions → "Ollama Executor Build Automation".
2) Run workflow with `simulation=true`.
3) Download simulated artifacts and logs.

### Real Build with Ollama (Manual)

1) Actions → "Ollama Executor Build Automation".
2) Run workflow with `simulation=false` on a Windows LV runner.
3) Wait for completion and download real artifacts.

---

## Artifacts

### Smoke Test Artifacts

- `test-results-{os}`: JSON/XML
- `test-reports-{os}`: HTML
- `ollama-executor-logs`: Logs and handshake JSON

### Build Artifacts

- `ollama-build-artifacts-simulation`: Simulated outputs
- `ollama-build-artifacts-real`: Real outputs
- `build-lv{version}-{bitness}bit`: Matrix outputs
- `ollama-executor-logs`: Execution logs

Retention: tests 30d, perf 90d, builds 7–30d.

---

## Integration with Existing Workflows

### Compatibility

- Runs alongside other CI; ports 11435 (real) and 11436 (mock) avoid conflicts.

### Canonical entry point

- Real paths (agent/build/smoke real lanes) run `scripts/orchestration/Run-Ollama-Host.ps1` with seed image preflight and handshake validation.
- Simulation lanes (agent sim, build sim, matrix sim, smoke sim) run the executor against the mock host and must pass `.github/actions/validate-ollama-handshake`.
- Handshake validator enforces `artifacts/labview-icon-api-handshake.json` keys: `zipSha256`, `pplSha256`, `zipRelPath`, `pplRelPath`, `mode`, `requirements`.
- Defaults across workflows: `OLLAMA_EXECUTOR_MODE=sim`, `OLLAMA_SIM_CREATE_ARTIFACTS=true`, `OLLAMA_SIM_DELAY_MS=50`, mock host `http://localhost:11436`, model `llama3-8b-local`; real host uses port 11435.

### When to Use

Use Smoke Test for:

- PRs touching executor or security-sensitive code.
- Validating security fixes and regressions.

Use Build Automation for:

- Testing build script changes.
- Validating cross-platform builds (sim).
- Creating artifacts or proving executor flows.

Do NOT use for:

- Production LabVIEW release builds.
- Critical release artifacts needing formal validation.

---

## Failure Scenarios

### Smoke Test Failures

Security gate fails:

- Cause: Vulnerability found.
- Action: Review fuzzing results and fix.
- Impact: PR blocked.

Regression gate fails:

- Cause: Previously fixed bug reappeared.
- Action: Review regression logs and restore fix.
- Impact: PR blocked.

Smoke test fails:

- Cause: Basic functionality broken.
- Action: Review logs, fix, re-run.
- Impact: PR blocked.

### Build Automation Failures

Simulation build fails:

- Cause: Script syntax/logic issue.
- Action: Review executor logs, fix script.
- Impact: Warning only (PR not blocked).

Real build fails:

- Cause: Ollama service or LabVIEW build error.
- Action: Check service/logs, verify runner prereqs.
- Impact: Real artifacts missing.

Multi-platform build fails:

- Cause: Platform-specific issue.
- Action: Review failing platform logs.
- Impact: Some artifacts missing.

---

## Monitoring and Debugging

### View Detailed Logs

1) Actions tab → workflow run → failed job → outputs.

### Download Artifacts

1) Workflow run summary → Artifacts section → download.

### Re-run Failed Jobs

1) Workflow run → "Re-run failed jobs" (or all jobs).

---

## Performance

Smoke Test:

- Multi-OS: ~5 minutes total
- Security gate: ~2 minutes
- Performance baseline: ~1 minute

Build Automation:

- Simulation: ~2 minutes
- Real: ~10–30 minutes
- Multi-platform: ~2 minutes (parallel)

---

## Future Enhancements

Planned:

- [ ] Code coverage reporting
- [ ] Performance regression detection
- [ ] Notifications on failures
- [ ] Status check integration
- [ ] Custom Ollama models per workflow

Possible:

- [ ] Scheduled nightly builds
- [ ] Cross-repo build triggers
- [ ] Build artifact caching
- [ ] Parallel real builds

---

## Troubleshooting

### "Ollama service unhealthy"

- Check Ollama image availability
- Verify GHCR credentials
- Check service container logs

### "Mock server failed to start"

- Review `MockOllamaServer.ps1` syntax
- Check port 11436 availability
- Verify scenario file exists

### "Simulation artifacts not created"

- Check `OLLAMA_SIM_CREATE_ARTIFACTS=true`
- Verify `SimulationProvider.ps1`
- Review working directory path

### "Security gate always fails"

- Run `pwsh scripts/ollama-executor/Test-SecurityFuzzing.ps1`
- Check for new vulnerabilities
- Review command vetting logic

---
