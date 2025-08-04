# Icon Editor GitHub Runner Setup Guide

This guide walks through setting up a self-hosted GitHub Actions runner capable of building and testing the LabVIEW Icon Editor. A self-hosted runner is required because the Icon Editor build and test process requires LabVIEW, which isn’t available on GitHub’s hosted runners.

## 1. Prepare the Runner Environment

- **LabVIEW Installation**: Install LabVIEW 2021 SP1 (32-bit and/or 64-bit as needed) on the machine that will act as the runner.  
- **VIPM Installation**: Ensure the machine has VI Package Manager (VIPM) installed, as the build produces a `.vip` (VI Package).  
- **PowerShell and Git**: Install PowerShell 7 (or newer) and Git for Windows. These tools are needed for running build scripts and pulling code.

> **Important:** The LabVIEW environment on the runner should match the target version for the Icon Editor (e.g., LabVIEW 2021–2025). The runner machine must remain online whenever you want CI jobs to run.

## 2. Configure a GitHub Actions Runner

1. **Generate Runner Token**: In your repository (or organization) on GitHub, go to **Settings → Actions → Runners**. Click **New self-hosted runner** and follow the instructions to generate a runner registration token.
2. **Download Runner Software**: Download the GitHub Actions runner software for your machine (Windows x64) from the provided link.
3. **Install and Configure**: Extract the runner software on the LabVIEW machine. From a PowerShell prompt, run `config.cmd`. Provide the repository URL (or org name), paste the token, and assign a runner name and labels (e.g., `iconeditor`).
4. **Service Setup**: (Optional) Run `.\svcinstall.cmd` to install the runner as a service, so it starts automatically with the machine.

After configuration, the runner should show as “Online” in your repo’s **Settings → Actions → Runners** list, with the labels you assigned.

## 3. Configure Runner Permissions and Secrets

- **Repository Access**: Ensure the runner is **enabled** for the `ni/labview-icon-editor` repository (this is usually the default when added at the repository level).  
- **Actions Permissions**: Under **Settings → Actions → General**, set **Workflow permissions** to “Read and write permissions” so that workflows can, for example, create releases or attach artifacts.
- **Secrets**: If any sensitive values are needed (e.g., code-signing credentials, if used), add them under **Settings → Secrets and variables → Actions**. However, for the Icon Editor, most builds can run without additional secrets thanks to fork-friendly defaults.

## 4. Running Builds and Tests on the Runner

Once the runner is online and the repository is configured, your CI workflows will automatically pick it up for jobs that specify the corresponding labels.

- Open a pull request or dispatch a workflow (like “Build VI Package”). In the GitHub Actions interface, you should see the job assigned to your self-hosted runner. 
- The runner will checkout the code, then execute the build or test scripts in the repository. Monitor the output from the runner in real-time via the Actions page.
- **Development Mode**: If your runner machine is also your development machine, be mindful of Development Mode. The “Development Mode Toggle” workflow can point LabVIEW to local source code. Ensure you disable Development Mode when running standard build/test workflows for consistent results.

## 5. Next Steps

With a self-hosted runner configured, the Icon Editor CI/CD workflows (build, test, etc.) will run in your LabVIEW environment, enabling full automation of the pipeline. For details on how the workflows function and how to troubleshoot any issues, see the [Local CI/CD Workflows guide](../../ci-workflows.md) and the [Troubleshooting and FAQ](../../ci/troubleshooting-faq.md).

If you need to stop using the runner, you can remove it via GitHub Settings or stop the service on the machine. Always **update LabVIEW and VIPM** on the runner machine as needed to keep the environment in sync with project requirements.

*(Refer back to the main [README](../../../README.md) for an overview of the project structure and contribution workflow.)*
