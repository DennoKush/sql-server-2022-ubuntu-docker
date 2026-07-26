# =============================================================================
# SQL Server 2022 Docker deployment — convenience targets.
# All targets simply wrap the scripts/ and docker compose commands
# documented in README.md; none of them run automatically.
# =============================================================================

.DEFAULT_GOAL := help

.PHONY: help check env config pull start stop restart status logs health verify test-db backup restore down destroy

help: ## Show this help message
	@echo "SQL Server 2022 Docker deployment — available targets:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

check: ## Read-only: check system prerequisites
	./scripts/check-prerequisites.sh

env: ## Interactively create .env (refuses to overwrite an existing one)
	./scripts/generate-env.sh

config: ## Read-only: print the resolved docker compose configuration
	docker compose config

pull: ## Download the SQL Server 2022 image
	docker compose pull

start: ## Start (or create) the SQL Server container
	./scripts/start.sh

stop: ## Stop the container without removing data
	./scripts/stop.sh

restart: ## Restart the container in place
	./scripts/restart.sh

status: ## Read-only: show container status
	./scripts/status.sh

logs: ## Read-only: follow container logs (Ctrl-C to stop)
	./scripts/logs.sh

health: ## Read-only: run full health check
	./scripts/health-check.sh

verify: ## Read-only: run sql/verify-installation.sql
	./scripts/test-connection.sh

test-db: ## Create the DockerTestDB fixture used for persistence testing
	./scripts/create-test-database.sh

backup: ## Back up a database. Usage: make backup DB=DockerTestDB
	./scripts/backup-database.sh $(DB)

restore: ## Restore a backup. Usage: make restore FILE=backups/x.bak DB=DockerTestDB
	./scripts/restore-database.sh $(FILE) $(DB)

down: ## Remove the container, KEEP the data volume (docker compose down)
	./scripts/uninstall.sh --keep-data

destroy: ## DANGER: remove the container AND permanently delete the data volume
	@echo "WARNING: 'make destroy' permanently deletes all databases."
	@echo "This delegates to the protected uninstall script, which requires"
	@echo "typed confirmation before doing anything irreversible."
	./scripts/uninstall.sh --delete-data
