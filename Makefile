# Copyright The Linux Foundation and each contributor to LFX.
# SPDX-License-Identifier: MIT

# Variables
PLAYBOOKS_DIR=playbooks
SCRIPTS_DIR=scripts

# Playbook paths
PROJECTS_ROOT_ACCESS=$(PLAYBOOKS_DIR)/projects/root_project_access
PROJECTS_BASE=$(PLAYBOOKS_DIR)/projects/base_projects
PROJECTS_EXTRA=$(PLAYBOOKS_DIR)/projects/extra_projects
PROJECTS_RECREATE_ROOT=$(PLAYBOOKS_DIR)/projects/recreate_root_project
COMMITTEES_BASE=$(PLAYBOOKS_DIR)/committees/base_committees
MAILING_LISTS=$(PLAYBOOKS_DIR)/mailing_lists/tlf_mailing_lists
V1_MEETINGS=$(PLAYBOOKS_DIR)/v1_meetings/umbrella_board_meeting

.PHONY: help setup check-env check-loader-env check-nats-env load load-projects load-committees load-mailing-lists load-meetings recreate-root reset clean

# Default target
help:
	@echo "LFX v2 Mock Data Tool"
	@echo ""
	@echo "Setup:"
	@echo "  setup          - Print setup instructions"
	@echo "  check-env      - Verify standard load environment variables are set"
	@echo ""
	@echo "Load data:"
	@echo "  load           - Load all standard playbooks"
	@echo "  load-projects  - Load only project playbooks"
	@echo "  load-committees - Load only committee playbooks"
	@echo "  load-mailing-lists - Load mailing list playbooks"
	@echo "  load-meetings  - Load v1 meeting playbooks"
	@echo "  recreate-root  - Recreate ROOT project KV entries"
	@echo ""
	@echo "Maintenance:"
	@echo "  reset          - Wipe all data (NATS KV, OpenSearch, caches)"
	@echo "  clean          - Clean temporary files"
	@echo ""
	@echo "Quick start:"
	@echo "  eval \"\$$(./scripts/setup-env.sh)\""
	@echo "  make load"

# Setup instructions
setup:
	@echo "Run this command to set up your environment:"
	@echo ""
	@echo "  eval \"\$$(./scripts/setup-env.sh)\""
	@echo ""
	@echo "Then verify with: make check-env"

# Check required environment variables for NATS-only playbooks
check-nats-env:
	@if [ -z "$$NATS_URL" ]; then \
		echo "❌ NATS_URL is not set"; \
		echo "Run: eval \"\$$(./scripts/setup-env.sh)\""; \
		exit 1; \
	fi

# Check required environment variables for API and NATS playbooks
check-loader-env: check-nats-env
	@if [ -z "$$JWT_RSA_SECRET" ]; then \
		echo "❌ JWT_RSA_SECRET is not set"; \
		echo "Run: eval \"\$$(./scripts/setup-env.sh)\""; \
		exit 1; \
	fi
	@echo "✅ Loader environment variables are set"
	@echo "  NATS_URL: $$NATS_URL"
	@echo "  JWT_RSA_SECRET: <set>"

# Check required environment variables for the standard project load
check-env: check-loader-env
	@if [ -z "$$OPENFGA_STORE_ID" ]; then \
		echo "❌ OPENFGA_STORE_ID is not set"; \
		echo "Run: eval \"\$$(./scripts/setup-env.sh)\""; \
		exit 1; \
	fi
	@echo "✅ Standard load environment variables are set"
	@echo "  OPENFGA_STORE_ID: $$OPENFGA_STORE_ID"

# Load all standard playbooks
load: check-env
	@echo "==> Loading all standard playbooks..."
	uv run lfx-v2-mockdata \
		--jwt-rsa-secret "$$JWT_RSA_SECRET" \
		-t $(PROJECTS_ROOT_ACCESS) $(PROJECTS_BASE) $(PROJECTS_EXTRA) $(COMMITTEES_BASE) $(MAILING_LISTS) $(V1_MEETINGS)

# Load only project playbooks
load-projects: check-env
	@echo "==> Loading project playbooks..."
	uv run lfx-v2-mockdata \
		--jwt-rsa-secret "$$JWT_RSA_SECRET" \
		-t $(PROJECTS_ROOT_ACCESS) $(PROJECTS_BASE) $(PROJECTS_EXTRA)

# Load only committee playbooks
load-committees: check-loader-env
	@echo "==> Loading committee playbooks..."
	uv run lfx-v2-mockdata \
		--jwt-rsa-secret "$$JWT_RSA_SECRET" \
		-t $(COMMITTEES_BASE)

# Load mailing list playbooks
load-mailing-lists: check-loader-env
	@echo "==> Loading mailing list playbooks..."
	uv run lfx-v2-mockdata \
		--jwt-rsa-secret "$$JWT_RSA_SECRET" \
		-t $(MAILING_LISTS)

# Load v1 meeting playbooks
load-meetings: check-loader-env
	@echo "==> Loading v1 meeting playbooks..."
	uv run lfx-v2-mockdata \
		--jwt-rsa-secret "$$JWT_RSA_SECRET" \
		-t $(V1_MEETINGS)

# Recreate ROOT project KV entries
recreate-root: check-nats-env
	@echo "==> Recreating ROOT project KV entries..."
	uv run lfx-v2-mockdata \
		-t $(PROJECTS_RECREATE_ROOT)

# Reset all data
reset:
	@echo "==> Running data reset..."
	./$(SCRIPTS_DIR)/reset-data.sh

# Clean temporary files
clean:
	@echo "==> Cleaning temporary files..."
	@rm -rf .pytest_cache __pycache__ .mypy_cache .ruff_cache
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "==> Clean complete"
