# CLAUDE.md

This file provides guidance to Claude Code when working with the LFX v2 mock data loader.

> **Central LFX skills:**
> - Start with `/lfx-skills:lfx` for cross-repo tasks, "where does X live" questions, owner/peer repo routing, or missing checkouts.
> - Use `/lfx-skills:lfx-platform-architecture` after routing when you need platform composition or write/read/access-check flows across FGA, indexer, query, Heimdall, OpenFGA, Helm, or ArgoCD.
> - Repo-local docs own concrete subjects, payloads, contracts, chart values, and domain behavior. If the plugin is missing, install with `/plugin marketplace add linuxfoundation/lfx-skills` then `/plugin install lfx-skills@lfx-skills`.

## Repo Role

This repo owns local mock-data playbooks and reset/load workflows for the LFX v2 platform. It populates services through API calls, NATS request/reply calls, and direct NATS KV operations for local development.

## Local Stack Prerequisites

The platform itself is owned by [`lfx-v2-helm`](https://github.com/linuxfoundation/lfx-v2-helm) (`charts/lfx-platform`). It must be installed and running before mock data loads can succeed — NATS, OpenFGA, Heimdall, OpenSearch, and the resource services all come from there. Install or troubleshoot the local stack in that repo, not this one.

## Canonical Workflow

For loading or resetting local fixture data, use the `/load-mock-data` skill. It owns the load/reset workflow including JWT/Heimdall setup, OpenFGA store discovery, mode selection (API / NATS req-rep / NATS KV), and verification.

Use `README.md`, `Makefile`, `playbooks/`, and `scripts/setup-env.sh` as the source of truth for load order, reset behavior, and environment setup.

## Common Commands

```bash
eval "$(./scripts/setup-env.sh)"   # one-time per shell
make check-env
make load
make reset
make recreate-root                 # only after manual KV wipes or failed ROOT recreation
```

## Boundaries

- Keep fixture generation and reset/load orchestration in this repo.
- Do not add service implementation rules here; service contracts belong in the owning service repos.
- Platform install and infra (NATS, OpenFGA, Heimdall, OpenSearch) belong in `lfx-v2-helm`.
- Deployed environment values and secret references belong in `lfx-v2-argocd`.
- Treat destructive reset behavior carefully and preserve the explicit confirmation flow.
