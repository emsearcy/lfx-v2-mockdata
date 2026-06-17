<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Mock Data NATS Usage

This repo uses NATS for local fixture setup. It does not own platform-wide NATS subject contracts.

## Usage Modes

| Mode | Use when |
| --- | --- |
| API call | The owning service exposes the behavior and end-to-end validation matters. |
| NATS request/reply | A service has a documented local request subject and existing playbooks use that path. |
| NATS KV write | Local fixture setup needs seeded state and the target bucket/key format is stable and documented by the owning service. |

## Ownership Boundary

- Subject names, payload shapes, and bucket schemas come from the owning service repo.
- This repo owns the playbook data and local orchestration needed to load it.
- Changes to service behavior must happen in the owning service repo before playbooks rely on that behavior.

## Review Checks

- Keep subject names and bucket names aligned with constants or docs in the owning service repo.
- Do not invent new NATS contracts in playbooks.
- Keep fixture IDs stable when other playbooks reference them.
- Use clear comments in playbooks for cross-resource dependencies.
