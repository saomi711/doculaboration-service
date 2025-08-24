# Doculaboration Makefile

.PHONY: help dev prod stop clean logs build test

help: ## Show this help message
	@echo "Doculaboration - Document Processing Pipeline"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: ## Start development environment
	@echo "🚀 Starting development environment..."
	@./scripts/dev.sh

prod: ## Start production environment
	@echo "🚀 Starting production environment..."
	@./scripts/prod.sh

stop: ## Stop all services
	@echo "🛑 Stopping all services..."
	@./scripts/stop.sh

clean: stop ## Stop services and remove containers, networks, images
	@echo "🧹 Cleaning up..."
	@docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.prod.yml down --rmi all --volumes --remove-orphans
	@docker system prune -f

logs: ## Show logs from all services
	@docker compose logs -f

logs-api: ## Show API logs
	@docker compose logs -f api

logs-worker: ## Show worker logs
	@docker compose logs -f worker

logs-nginx: ## Show nginx logs
	@docker compose logs -f nginx

build: ## Build all images
	@echo "🔨 Building all images..."
	@docker compose build

rebuild: ## Rebuild all images without cache
	@echo "🔨 Rebuilding all images..."
	@docker compose build --no-cache

test: ## Run tests (placeholder)
	@echo "🧪 Running tests..."
	@echo "Tests not implemented yet"

scale-workers: ## Scale workers to 3 instances
	@echo "📈 Scaling workers..."
	@docker compose up -d --scale worker=4

status: ## Show status of all services
	@echo "📊 Service status:"
	@docker compose ps

health: ## Run health check on all services
	@./scripts/health-check.sh

test-setup: ## Test the complete setup configuration
	@./scripts/test-setup.sh

monitor: ## Start production monitoring dashboard
	@./scripts/monitor.sh

backup: ## Create a backup of all data and configuration
	@./scripts/backup.sh

restore: ## Restore from backup (usage: make restore BACKUP=backup_name)
	@./scripts/restore.sh $(BACKUP)

verify: ## Verify complete installation
	@./scripts/verify-install.sh

quick-status: ## Quick status check of all services
	@./scripts/quick-status.sh

shell-api: ## Open shell in API container
	@docker compose exec api /bin/bash

shell-worker: ## Open shell in worker container
	@docker compose exec worker /bin/bash

shell-nginx: ## Open shell in nginx container
	@docker compose exec nginx /bin/sh

frontend-dev: ## Start frontend in development mode
	@echo "🎨 Starting frontend development server..."
	@cd frontend && npm install && PORT=4200 npm start

frontend-build: ## Build frontend for production
	@echo "🔨 Building frontend..."
	@cd frontend && npm run build

install: ## Install frontend dependencies
	@echo "📦 Installing dependencies..."
	@cd frontend && npm install