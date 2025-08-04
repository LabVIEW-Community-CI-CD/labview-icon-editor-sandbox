# LabVIEW Icon Editor

[![CI](https://github.com/ni/labview-icon-editor/actions/workflows/ci.yml/badge.svg)](https://github.com/ni/labview-icon-editor/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/ni/labview-icon-editor?label=release)](https://github.com/ni/labview-icon-editor/releases/latest)
[![Discord](https://img.shields.io/discord/1319915996789739540?label=chat&logo=discord&style=flat)](https://discord.gg/q4d3ggrFVA)
![Coding hours](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/ni/labview-icon-editor/metrics/badge.json)

---

## 🧭 Table of Contents (Users) <a id="table-of-contents-users"></a>
- 📌 [Overview](#overview)
- 📦 [How to Install](#how-to-install)

## 🧑‍💻 Table of Contents (Collaborators) <a id="table-of-contents-collaborators"></a>
- 🧩 [Key Components](#key-components)
- 🚀 [Getting Started and Contributing](#getting-started-and-contributing)
- 🌱 [Feature and Experiment Workflows](#feature-and-experiment-workflows)
- 📚 [Documentation](#documentation)
- 📄 [License and CLA](#license-and-cla)
- 💬 [Contact and Discord](#contact-and-discord)

---

## 📌 Overview <a id="overview"></a>

The **LabVIEW Icon Editor** is an open-source, MIT-licensed project that releases VI Packages with the latest community-driven features. When **LabVIEW** is built for an official release, it automatically pulls the latest version of the Icon Editor from this repo’s `main` branch—currently targeting **LabVIEW 2026 Q1**.

This means that your contributions—whether features, fixes, or docs—can ship with **official LabVIEW distributions**.

- 🛠 Built entirely in G.
- ⚙️ GitHub Actions orchestrate PowerShell-based CI workflows for testing, packaging, and publishing `.vip` artifacts.
- 🔁 This project pioneered CI/CD pipelines, documentation, and foundational infrastructure that will eventually migrate to a centralized dependency repository so that it can expand along with other concepts (e.g. lvenv).

NI’s Open-Source Program encourages **community collaboration** to evolve and improve this tooling that streamlines the way the LabVIEW community tests NI-governed features.

---

## 📦 How to Install <a id="how-to-install"></a>

> **Prerequisites:**  
> • LabVIEW 2021 SP1 or newer  

1. **Download** the latest `.vip` file from the [releases page](https://github.com/ni/labview-icon-editor/releases/latest).  
2. **Open VIPM** in Administrator mode.  
3. **Install** by double-clicking the `.vip` file or opening it via *File ▶ Open Package* in VIPM.  
4. **Verify** the installation by creating a new VI and opening the Icon Editor.

---

## 🧩 Key Components <a id="key-components"></a>

1. **Source Files**  
   - VI-based.

2. **PowerShell Automation**
   - Built on [G-CLI](https://github.com/G-CLI/G-CLI).
   - Supports repeatable builds, releases, and CI tasks.
   - Easy to use in local or GitHub-hosted runners.

3. **CI/CD Workflows**
   - [CI Workflow Overview](docs/ci-workflows.md#jobs-in-ci-workflow) — explains the jobs in the `ci.yml` pipeline.
   - [Build VI Package](docs/ci/actions/build-vi-package.md).
   - [Development Mode Toggle](docs/ci/actions/development-mode-toggle.md).

---

## 🚀 Getting Started and Contributing <a id="getting-started-and-contributing"></a>

We welcome both **code** and **non-code** contributions—from bug fixes and performance improvements to documentation or testing.

- 📑 **CLA Required** – External contributors must sign a Contributor License Agreement before we can merge your pull request.  
- 🧭 **Steering Committee** – A mix of members of LabVIEW research and development (R&D) and community volunteers who guide the roadmap and have merge authority.
- 🔄 **Issues and Experiments** – Look for issues labeled “[Workflow: Open to contribution](https://github.com/ni/labview-icon-editor/labels/Workflow%3A%20Open%20to%20contribution)”.
- 🧪 **Long-Lived Features** – For experimental branches, see [**`EXPERIMENTS.md`**](docs/ci/experiments.md).

More contribution info is in [**`CONTRIBUTING.md`**](CONTRIBUTING.md).

---

## 🌱 Feature and Experiment Workflows <a id="feature-and-experiment-workflows"></a>

### Standard Feature Workflow

1. **Discuss or Propose an Issue**  
   - Use [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions) or [Discord](https://discord.gg/q4d3ggrFVA)

2. **Assignment**  
   - Once approved by LabVIEW R&D, the issue is labeled “[Workflow: Open to contribution](https://github.com/ni/labview-icon-editor/labels/Workflow%3A%20Open%20to%20contribution)”.  
   - A volunteer comments on the issue to request assignment.  
   - An NI Maintainer creates a feature branch and assigns the issue.

3. **Branch Setup**  
   - Fork + clone the repo.  
   - Check out the feature branch and implement your changes.

4. **Build Method**  
   - Choose either:
     - [Manual Setup](./docs/manual-instructions.md)  
     - [PowerShell Scripts](./docs/powershell-cli-instructions.md)

5. **Submit PR**  
   - CI will build and publish a testable `.vip`.  
   - Reviewers verify and collaborate with you until it’s ready.

6. **Merge and Release**
   - Merges go to `develop`, then to `main` during the next release cycle.

### Experimental Workflow

- Used for large or multi-week features.  
- Docker VI Analyzer and CodeQL run automatically.
- Manual approval required for `.vip` publishing (`approve-experiment` event).  
- Sub-branches for alpha/beta/RC are optional.

More info in [**`EXPERIMENTS.md`**](docs/ci/experiments.md)

---

## 📚 Documentation <a id="documentation"></a>

Explore the `/docs` folder for technical references:

- 📦 [Build VI Package](docs/ci/actions/build-vi-package.md)
- 🧪 [Development Mode Toggle](docs/ci/actions/development-mode-toggle.md)
- 🚢 [Multichannel Release Workflow](docs/ci/actions/multichannel-release-workflow.md)
- 🖥 [Runner Setup Guide](docs/ci/actions/runner-setup-guide.md)
- 🧬 [Injecting Repo/Org Metadata](docs/actions/injecting-repo-org-to-vi-package.md)
- 🧯 [Troubleshooting and FAQ](docs/ci/troubleshooting-faq.md)
- 🔬 [Experiments](docs/ci/experiments.md)
- 🛡️ [Maintainers Guide](docs/ci/actions/maintainers-guide.md)
- 🧱 [Troubleshooting Experiments](docs/ci/actions/troubleshooting-experiments.md)
- 🏛️ [**`GOVERNANCE.md`**](GOVERNANCE.md)

---

## 📄 License and CLA <a id="license-and-cla"></a>

- **MIT License** – [LICENSE](LICENSE).
- **Contributor License Agreement** – Required before we can merge your contributions.

By contributing, you grant NI the right to distribute your changes with LabVIEW.

---

## 💬 Contact and Discord <a id="contact-and-discord"></a>

- 🗨 [Discord Server](https://discord.gg/q4d3ggrFVA) – ask questions, propose ideas, get feedback.
- 📂 [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions) – for formal proposals or workflows.

---

### 🙏 Thanks for Contributing!
Your ideas, tests, and code shape the Icon Editor experience across **LabVIEW 2021–2026** and beyond.
