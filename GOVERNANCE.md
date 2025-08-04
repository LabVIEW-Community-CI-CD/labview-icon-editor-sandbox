# Governance

## Scope and Purpose

The LabVIEW Icon Editor is an **open-source** project under NI’s Open-Source Program. This document outlines how the project is managed, defining who makes decisions, how contributors engage in governance, and how changes to these policies can be made. The goal is to maintain a welcoming, collaborative environment while ensuring the quality and continuity of the Icon Editor as it integrates into official LabVIEW releases.

## Roles and Responsibilities

**Steering Committee** — The Steering Committee consists of NI staff and select community contributors who have demonstrated long-term commitment. The committee guides the project’s direction and has authority over major decisions. They evaluate proposals (feature ideas, experiments) and determine which are aligned with the roadmap. The Steering Committee also approves when an experimental branch is ready to be merged or a release is cut. All Steering Committee members are expected to act in the best interest of both NI and the community, balancing innovation with stability.

**Maintainers** — Maintainers (as detailed in the [Maintainers Guide](docs/ci/actions/maintainers-guide.md)) are responsible for day-to-day project maintenance: reviewing and merging pull requests, triaging issues, and managing the CI/CD infrastructure. Many maintainers are part of NI’s development team for LabVIEW, though experienced community members can also become maintainers with Steering Committee approval. Maintainers ensure that contributions meet the project’s standards and that the repository stays healthy and active. In governance matters, maintainers often implement and enforce policies decided by the Steering Committee.

**BDFL (Benevolent Dictator for Life)** — NI designates an ultimate decision-maker for cases where consensus cannot be reached. In practice, this role is fulfilled by NI’s Open-Source Program leadership or a lead LabVIEW research and development (R&D) manager overseeing the Icon Editor project. The BDFL has the authority to make final decisions on contentious issues or critical direction changes. However, this power is used sparingly — the preference is to resolve issues through discussion and Steering Committee consensus. The BDFL concept ensures that the project can move forward even if there is a stalemate.

**Contributors** — Anyone from the community who contributes (code, documentation, testing, feedback) is a contributor. Contributors are encouraged to participate in discussions and can influence the project by contributing quality work and constructive ideas. While contributors do not have formal decision-making power, their feedback is highly valued. Many governance improvements and new features originate from contributor suggestions.

## Decision-Making Process

The project strives for **consensus-based decision-making**:
- For routine matters (e.g., merging a non-controversial PR, fixing a bug), maintainers can decide and act, especially if it aligns with established goals.
- For significant changes (new features, architectural changes, changes in supported LabVIEW versions), a GitHub Issue or Discussion is used to gather input. The Steering Committee discusses these, often asynchronously on GitHub or in periodic meetings.
- **Consensus** means the majority of the Steering Committee agrees and no maintainer has a strong objection. If consensus emerges, the decision is documented (e.g., the issue is tagged as "approved" or notes from a meeting are posted).

If consensus cannot be reached in a reasonable time frame:
- The issue is escalated to the BDFL (the NI-appointed lead). The BDFL will consider all arguments and then make a decision.
- Once the BDFL decision is made, the Steering Committee and maintainers execute accordingly (e.g., merge or close a proposal).

Decisions on critical topics (for example, changing the project’s license or its fundamental integration approach with LabVIEW) require NI management approval in addition to the above process, because the Icon Editor ships with LabVIEW. These cases are rare and will be clearly communicated.

All decisions, whether by consensus or BDFL decree, are documented publicly for transparency.

## Meetings and Communication

Most governance communication happens openly:
- **GitHub Discussions/Issues** — The primary forum for proposals and ideas. This creates a public record and allows all community members to weigh in.
- **Discord Chat** — Useful for quick, informal discussions. However, final decisions or important topics raised on Discord should be summarized on GitHub for transparency.
- **Steering Committee Meetings** — The Steering Committee may have private meetings (often including NI’s Open-Source Program personnel) to discuss roadmap and sensitive matters (e.g., coordinating with LabVIEW release schedules). Key outcomes affecting the project are later posted publicly (minus any confidential NI internal details).

The project follows the NI Community Code of Conduct; all interactions should be respectful and focused on technical merit.

## Amending These Bylaws

Governance policies may evolve over time. Proposed changes to this **Governance** document (or related processes) are done via pull requests:
- A maintainer or Steering Committee member opens a PR describing the change (and the rationale).
- The Steering Committee and community discuss the PR. Ideally, changes to governance achieve broad support before adoption.
- To accept an amendment, at least a two-thirds majority of the Steering Committee must approve the PR **and** no veto is issued by the BDFL. (For example, if the Steering Committee has six members, at least four must approve.)
- If consensus is unclear, the BDFL may step in to provide a deciding vote — or may request further discussion rather than forcing a decision.

Once approved, the amended governance takes effect immediately unless the proposal specifies a transition period.

> [!NOTE]
> These governance guidelines are meant to ensure the project remains collaborative and sustainable. NI, as the original creator and primary maintainer of the LabVIEW Icon Editor, retains ultimate oversight. However, NI is committed to running this project in the open with community input. The BDFL authority (NI’s role) is a backstop rather than a day-to-day management tool.

## Acknowledgments

This governance structure was inspired by other successful open-source projects at NI and in the broader community. We aim for a balance between NI’s product requirements and community-driven innovation. As the project grows, we will revisit governance to make sure it serves the contributors and users of the LabVIEW Icon Editor well.
