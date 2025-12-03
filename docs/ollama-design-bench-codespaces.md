# Codespaces workflow: Ollama Design Bench

A step-by-step flow for using the Ollama Design Bench tasks from GitHub Codespaces. It assumes the repo devcontainer is in use and that Docker is available inside the Codespace (default for this repo).

## Prerequisites
- Open a Codespace for this repo and let the devcontainer finish building (PowerShell is the default shell and VS Code tasks are enabled automatically).
- Confirm Docker works inside the Codespace: `docker info` should succeed; if it fails, restart the Codespace or choose a larger machine type.
- Default environment inside the devcontainer: `OLLAMA_HOST=http://host.docker.internal:11435`, `OLLAMA_IMAGE=ghcr.io/svelderrainruiz/ollama-local:cpu-preloaded`, `OLLAMA_MODEL_TAG=llama3-8b-local:latest`. The Docker socket is mounted and `host.docker.internal` is pre-wired to the host gateway so sibling containers are reachable.
- Optional: forward port **11435** in Codespaces if you want to hit the Ollama API from outside VS Code (not required for the tasks themselves).

## Workflow
1) **Verify the socket**: In the devcontainer terminal, run `docker ps` to ensure the Docker daemon is reachable. If you see a permissions or connection error, restart the Codespace and re-run the command.
2) **Pull the image**: Run task **28** `Ollama: pull image` (defaults owner/tag to `svelderrainruiz/cpu-preloaded`). If you need to test a different tag, override when prompted. Network-less Codespaces can skip this when providing a `.ollama` bundle in the next step.
3) **Start the container + optional bundle import**: Run task **29** `Ollama: start container`. It publishes **11435/tcp** on the host, mounts the persistent `ollama` volume, and imports a `.ollama` bundle when provided, re-tagging it to the target model tag. On success the task prints the reachable endpoint.
4) **Health check**: Run task **27** `Ollama: health check` with host `http://host.docker.internal:11435` (default input) and the expected model tag. This fails fast if the container is stopped, the port is blocked, or the model tag is absent.
5) **Run the locked flows**: Trigger the two-turn tasks after the health check succeeds:
   - **30** `Ollama: package-build (locked)` – orchestrates package build via the allowlisted executor.
   - **31** `Ollama: source-distribution (locked)` – runs the SD build.
   - **32** `Ollama: local-sd-ppl (locked)` – runs SD→PPL orchestration.
   Each task prompts for timeouts and uses the same host/model inputs; failures emit detailed logs under `reports/logs/`.
6) **Stop and reset**: Use **33** to stop the container cleanly or **34** to stop and clear the persisted model cache volume. Repeat from step 2 when switching models or cleaning the workspace.

## Tips and troubleshooting
- **Tasks not showing up?** Ensure the window is connected to the Codespace, then run **Terminal → Run Task…**; the devcontainer forces PowerShell as the default shell and allows automatic tasks to surface the list.
- **Host unreachable**: Re-run task 29, then `docker ps` to confirm `ollama-local` is up. Verify the port-forwarding UI in Codespaces shows 11435 if you need external access.
- **Model missing**: Provide a `.ollama` bundle path when running task 29 to import offline, or run `docker exec -it ollama-local ollama pull <model>` to fetch online and retag to `OLLAMA_MODEL_TAG`.
- **Keep ports consistent**: Use `http://host.docker.internal:11435` inside the devcontainer; when forwarding to your browser, use the forwarded URL Codespaces provides for port 11435.
