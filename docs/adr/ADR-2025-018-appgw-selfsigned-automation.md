# ADR-2025-018: Automate self-signed TLS cert generation for App Gateway backends

## Status
Accepted

## Context
- Azure Application Gateway backends often need TLS even in dev/test.
- Using the public registry or external CAs is undesirable for closed/offline scenarios.
- Manual self-signed cert creation is error-prone and inconsistent across contributors.

## Decision
- Provide a repository script to generate a deterministic self-signed certificate (PFX + CER) for a given backend DNS name, and emit operator instructions for backend binding and App Gateway trust import.
- Scope: dev/test environments; the CER is intended to be uploaded to App Gateway’s HTTP setting as a trusted root, and the PFX bound on the backend server.
- No external CA dependency; everything is created locally via PowerShell.
- Code signing: the helper script **shall be Authenticode-signed** with an internal code-signing cert, and operators should verify the signature before execution. Optional: publish detached signatures for generated PFX/CER artifacts when distributing them.

## Consequences
- Pros: repeatable cert generation; clear operator guidance; no dependency on external CA or registry; supports offline/air-gapped setups.
- Cons: self-signed certs are not suitable for production; requires elevated PowerShell to write to LocalMachine store; backend binding still needs to be performed by the operator; requires maintaining and trusting an internal code-signing cert.

## Implementation
- Script added: `scripts/certs/create-appgw-selfsigned.ps1`
  - Inputs: `-DnsName`, `-OutputDir`, optional `-CertName`, `-ValidDays`, `-PfxPassword`.
  - Outputs: PFX and CER files and printed next steps for backend binding and App Gateway trust.
- Requirement added: TRW-211 (section 17.1) covering generation and operator instructions.

## Alternatives considered
- Rely on public CA: rejected for offline/controlled environments.
- Manual cert creation: rejected due to inconsistency and lack of automation.
- Using the fallback to external registries: rejected for determinism and compliance.
