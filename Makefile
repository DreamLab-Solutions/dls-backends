SHELL := /bin/bash
COMPOSE := docker compose -f ../../dev/compose/local-infra.compose.yml

.PHONY: help up down logs ps reset doctor sync-env

help: ## Show available targets
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

sync-env: ## Render paperless env from .env
	@if [ -f .env ]; then \
		if ! grep -q '^VAULT_MASTER_KEY=' .env; then \
			key=$$(openssl rand -base64 32); \
			echo "VAULT_MASTER_KEY=$$key" >> .env; \
		else \
			current=$$(grep '^VAULT_MASTER_KEY=' .env | sed 's/^VAULT_MASTER_KEY=//'); \
			if [ -z "$$current" ]; then \
				key=$$(openssl rand -base64 32); \
				if command -v sed >/dev/null 2>&1; then \
					sed -i.bak "s/^VAULT_MASTER_KEY=.*/VAULT_MASTER_KEY=$$key/" .env && rm -f .env.bak; \
				else \
					tmp=$$(mktemp); \
					awk -v key="$$key" 'BEGIN{done=0} /^VAULT_MASTER_KEY=/{print "VAULT_MASTER_KEY="key; done=1; next} {print} END{if(!done) print "VAULT_MASTER_KEY="key}' .env > $$tmp && mv $$tmp .env; \
				fi; \
			fi; \
		fi; \
	fi
	./infra/scripts/sync-paperless-env.js

up: sync-env ## Start the full stack
	$(COMPOSE) up -d

down: ## Stop the stack
	$(COMPOSE) down

logs: ## Tail logs for all services
	$(COMPOSE) logs -f

ps: ## Show container status
	$(COMPOSE) ps

reset: ## Stop and remove volumes
	$(COMPOSE) down -v

doctor: ## Validate local setup and print URLs
	./infra/scripts/doctor.sh
