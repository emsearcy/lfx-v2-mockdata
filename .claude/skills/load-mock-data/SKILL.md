---
name: load-mock-data
description: Use when loading or resetting local LFX v2 fixture data — running playbooks, writing to NATS/KV, calling resource service APIs, or seeding the local platform stack with test projects/committees/meetings/etc. Covers JWT/Heimdall setup, OpenFGA store discovery, and reset/load behavior.
allowed-tools: Read, Bash(make:*), Bash(kubectl:*), Bash(curl:*), Bash(nats:*), Bash(jq:*), Bash(uv:*), Bash(./scripts/setup-env.sh:*), Bash(eval:*)
---

<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# Load Mock Data

Seed the local LFX v2 platform with fixture data (projects, committees, mailing lists, meetings) for development and testing. Reset clears state between runs.

## Prerequisites

- Local LFX v2 platform must be running. The platform install lives in `lfx-v2-helm` — see `charts/lfx-platform/README.md` there. Without it, NATS / OpenFGA / Heimdall / the resource services will not be reachable.
- Python 3.12 (managed by `uv` automatically).
- `uv` package manager installed locally.
- `jwt` CLI from [jwt-cli](https://github.com/mike-engel/jwt-cli) on `$PATH`.
- `kubectl` configured against the local cluster that hosts the `lfx` namespace.
- `kubectl`, `curl`, `jq`, and (optionally) `nats` CLI for manual KV operations.

Playbooks assume the execution environment can resolve `*.lfx.svc.cluster.local` Kubernetes service URLs. If not, override the URLs via environment variables before loading.

## Step 1 — JWT / Heimdall / OpenFGA setup

Run the setup script once per shell session. It exports `NATS_URL`, `OPENFGA_STORE_ID` (looked up from the OpenFGA `/stores` API), and `JWT_RSA_SECRET` (extracted from the `heimdall-signer-cert` Kubernetes secret):

```bash
eval "$(./scripts/setup-env.sh)"
make check-env
```

`make check-env` validates the standard project-load environment: `JWT_RSA_SECRET`, `NATS_URL`, and `OPENFGA_STORE_ID`. Non-project load targets use narrower Makefile checks internally.

If the setup script fails:

- OpenFGA store discovery requires `curl http://lfx-platform-openfga.lfx.svc.cluster.local:8080/stores` to succeed. List manually if needed:

  ```bash
  curl -s "http://lfx-platform-openfga.lfx.svc.cluster.local:8080/stores" | jq
  export OPENFGA_STORE_ID="<id-from-response>"
  ```

- JWT secret extraction:

  ```bash
  export JWT_RSA_SECRET="$(kubectl get secret/heimdall-signer-cert -n lfx -o json | jq -r '.data["signer.pem"] | @base64d')"
  ```

- The `!jwt` macro auto-detects the JWKS key ID from `http://lfx-platform-heimdall.lfx.svc.cluster.local:4457/.well-known/jwks`. If unreachable from the execution environment, pass `--jwt-key-id <id>` explicitly to `lfx-v2-mockdata`.

## Step 2 — Choose load mode

Three modes — pick by what the task needs:

| Mode | Use when |
| --- | --- |
| **Service API** | The owning service exposes the endpoint and end-to-end validation matters. Default for most playbooks. |
| **NATS request/reply** | The service documents a local request subject and existing playbooks use that path. |
| **NATS KV write** | Local fixture setup needs seeded state and the bucket/key format is stable and documented by the owning service. |

Subject names, payload shapes, and bucket schemas are owned by the resource service repos — do not invent new contracts here. See `references/nats-messaging.md` for the boundary rules.

## Step 3 — Load fixtures

Most common loads (run from repo root):

```bash
make load               # All standard playbooks (projects + committees + mailing lists + v1 meetings)
make load-projects      # Project hierarchy only
make load-committees    # Committees only (requires projects loaded first)
make load-mailing-lists # Mailing lists only
make load-meetings      # v1 meeting playbooks
make recreate-root      # Recreate ROOT project KV entries after a manual KV wipe
```

Custom combinations via the underlying CLI:

```bash
uv run lfx-v2-mockdata --help
uv run lfx-v2-mockdata \
    --jwt-rsa-secret "$JWT_RSA_SECRET" \
    -t playbooks/projects/root_project_access \
       playbooks/projects/base_projects \
       playbooks/committees/base_committees
```

Order rules:

- Playbook directory order on the command line is honored.
- Within a directory, playbooks run alphabetically.
- Multiple passes resolve `!ref` cross-references, but correct order avoids retry storms.

Available playbook families: `playbooks/projects/{root_project_access,base_projects,extra_projects,recreate_root_project}`, `playbooks/committees/base_committees`, `playbooks/mailing_lists/tlf_mailing_lists`, `playbooks/v1_meetings/umbrella_board_meeting`.

## Step 4 — Reset

Wipe data and start clean:

```bash
make reset
```

This:

- Clears configured fixture NATS KV buckets (projects, committees, meetings, mailing lists, FGA sync cache, and related settings).
- Clears and recreates OpenSearch indices using the current mapping.
- Restarts the query service to clear cache.
- Deletes the project-service pod, which on restart recreates the ROOT project.
- Preserves `authelia-users` and `authelia-email-otp` buckets so local auth survives.
- Requires typing `RESET` at the confirmation prompt.

Narrow project/committee KV-only wipe (when you do not want the full reset):

```bash
for bucket in projects project-settings committees committee-settings committee-members; do
    nats kv rm -f $bucket
    nats kv add $bucket
done
# Then recreate ROOT before loading:
make recreate-root
```

## Step 5 — Verify

After loading:

```bash
make check-env                                              # env still set
nats kv ls                                                  # buckets present
nats kv get projects <project-id> 2>/dev/null | head -40    # spot-check a fixture
kubectl logs -n lfx -l app.kubernetes.io/name=project-service --tail=50  # service consumed the writes
```

For API-loaded fixtures, query through the resource service or query-service to confirm they are searchable.

## Boundaries

- This repo owns playbooks, load/reset orchestration, JWT/OpenFGA/NATS setup glue, and reset behavior.
- Service API behavior, indexer contracts, FGA tuple shapes, and bucket schemas live in the owning service repos.
- Platform infra (NATS, OpenFGA, Heimdall, OpenSearch deployment) lives in `lfx-v2-helm`.
- Deployed environment values and secret refs live in `lfx-v2-argocd`.
- Do not hardcode secrets or pre-generated JWTs in playbooks.
- Preserve the destructive-reset confirmation prompt.

## References

- `references/nats-messaging.md` — NATS subject / KV ownership boundary used by playbooks.
- `README.md` — full CLI reference and prerequisite detail.
- `Makefile` — authoritative list of load/reset targets.
- `playbooks/` — playbook YAML; comments document each playbook's role.
- `scripts/setup-env.sh` — env-var bootstrap source of truth.
- `scripts/reset-data.sh` — reset implementation.
