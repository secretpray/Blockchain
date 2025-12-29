.PHONY: help setup dev server console db-migrate db-rollback db-reset db-seed clean routes quality rubocop rubocop-fix brakeman bundler-audit pre-pr cache-clear git-status deploy

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

##@ General

help: ## Display this help message
	@echo "$(BLUE)Blockchain Auth - Available Commands$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

setup: ## Initial project setup (install gems, setup db, assets)
	@echo "$(BLUE)==== Installing gems =====$(NC)"
	bundle install
	@echo "\n$(BLUE)==== Setting up database =====$(NC)"
	bin/rails db:create
	bin/rails db:migrate
	@echo "\n$(BLUE)==== Setting up Solid Cache/Queue/Cable =====$(NC)"
	bin/rails db:cache:setup
	bin/rails db:queue:setup
	bin/rails db:cable:setup
	@echo "\n$(GREEN)✅ Setup complete! Run 'make dev' to start the app.$(NC)"

##@ Development

dev: ## Start development server with all services (Puma + Tailwind + Solid Queue)
	bin/dev

fresh: ## Clean assets and caches, then start development server
	@echo "$(BLUE)==== Cleaning assets =====$(NC)"
	bin/rails assets:clobber
	@echo "\n$(BLUE)==== Clearing caches =====$(NC)"
	bin/rails tmp:cache:clear
	bin/rails runner "Rails.cache.clear"
	@echo "\n$(BLUE)==== Starting development server =====$(NC)"
	bin/dev

server: ## Start Rails server only (without bin/dev)
	bin/rails server

console: ## Start Rails console
	bin/rails console

##@ Database

db-migrate: ## Run database migrations
	bin/rails db:migrate

db-rollback: ## Rollback last migration
	bin/rails db:rollback

db-reset: ## Reset database (drop, create, migrate, seed)
	bin/rails db:drop db:create db:migrate db:seed
	@echo "$(GREEN)✅ Database reset complete!$(NC)"

db-seed: ## Seed database with sample data
	bin/rails db:seed

##@ Cache Management

cache-clear: ## Clear Rails cache (Solid Cache)
	bin/rails tmp:cache:clear
	bin/rails runner "Rails.cache.clear"
	@echo "$(GREEN)✅ Cache cleared!$(NC)"

cache-setup: ## Setup Solid Cache tables
	bin/rails db:cache:setup

cache-stats: ## Show cache statistics (Solid Cache)
	@bin/rails runner "puts 'Solid Cache entries: ' + SolidCache::Entry.count.to_s" 2>/dev/null || echo "$(YELLOW)Run 'make cache-setup' first$(NC)"

##@ Quality & Security

pre-pr: ## Run all checks before creating PR (bundler-audit + rubocop + brakeman)
	@echo "$(BLUE)==== Running Bundler Audit =====$(NC)"
	bundle exec bundler-audit check --update
	@echo "\n$(BLUE)==== Running RuboCop =====$(NC)"
	bundle exec rubocop
	@echo "\n$(BLUE)==== Running Brakeman =====$(NC)"
	bundle exec brakeman -q
	@echo "\n$(GREEN)✅ All pre-PR checks passed! Ready to create PR.$(NC)"

quality: ## Run all quality checks (alias for pre-pr)
	@$(MAKE) --no-print-directory pre-pr

rubocop: ## Run RuboCop (style checker)
	bundle exec rubocop

rubocop-fix: ## Auto-fix RuboCop offenses
	bundle exec rubocop -A
	@echo "$(GREEN)✅ RuboCop auto-fix complete!$(NC)"

brakeman: ## Run Brakeman security scanner
	bundle exec brakeman

brakeman-report: ## Generate Brakeman HTML report
	bundle exec brakeman -o tmp/brakeman_report.html
	@echo "$(GREEN)✅ Report saved to tmp/brakeman_report.html$(NC)"

bundler-audit: ## Check for vulnerable gem versions
	bundle exec bundler-audit check --update

##@ PWA & Assets

pwa-check: ## Verify PWA manifest and service worker
	@echo "$(BLUE)==== Checking PWA files =====$(NC)"
	@test -f app/views/pwa/manifest.json.erb && echo "$(GREEN)✅ manifest.json.erb found$(NC)" || echo "$(RED)❌ manifest.json.erb missing$(NC)"
	@test -f app/views/pwa/service-worker.js && echo "$(GREEN)✅ service-worker.js found$(NC)" || echo "$(RED)❌ service-worker.js missing$(NC)"

assets-precompile: ## Precompile assets for production
	bin/rails assets:precompile

assets-clean: ## Clean precompiled assets
	bin/rails assets:clobber

##@ Testing & SIWE

siwe-test: ## Test SIWE authentication flow manually
	@echo "$(BLUE)==== SIWE Authentication Test =====$(NC)"
	@echo "1. Start server: make dev"
	@echo "2. Open http://localhost:3000"
	@echo "3. Connect MetaMask wallet"
	@echo "4. Sign message to authenticate"
	@echo "\n$(YELLOW)Manual testing required - no automated tests yet.$(NC)"

##@ Deployment

deploy: ## Deploy to production using Kamal
	kamal deploy

deploy-setup: ## Initial Kamal setup (first time)
	kamal setup

deploy-logs: ## Show deployment logs
	kamal app logs

deploy-console: ## Connect to production console
	kamal app exec -i --reuse bin/rails console

##@ Maintenance

clean: ## Clean temporary files and logs
	rm -rf tmp/cache/*
	rm -rf tmp/pids/*
	rm -rf log/*.log
	@echo "$(GREEN)✅ Cleaned temporary files!$(NC)"

routes: ## Display all routes
	bin/rails routes

routes-grep: ## Search routes (usage: make routes-grep QUERY=api)
	bin/rails routes | grep "$(QUERY)"

credentials-edit: ## Edit Rails encrypted credentials
	EDITOR='code --wait' bin/rails credentials:edit

##@ Git

git-status: ## Show git status
	git status

git-branches: ## Show git branches
	git branch -a

git-clean-branches: ## Delete merged branches
	git branch --merged | grep -v "\*" | grep -v "main" | grep -v "master" | xargs -n 1 git branch -d

##@ Information

info: ## Show project information
	@echo "$(BLUE)==== Blockchain Auth - Project Info =====$(NC)"
	@echo "Ruby version:    $$(ruby -v)"
	@echo "Rails version:   $$(bin/rails -v)"
	@echo "PostgreSQL:      $$(psql --version | head -1)"
	@echo "Bundler:         $$(bundle -v)"
	@echo "\n$(YELLOW)Protocols:$(NC)"
	@echo "  - EIP-4361 (SIWE)"
	@echo "  - EIP-191 (Signed Messages)"
	@echo "  - PWA with Service Worker"
	@echo "\n$(YELLOW)Stack:$(NC)"
	@echo "  - Hotwire (Turbo + Stimulus)"
	@echo "  - Solid Cache/Queue/Cable"
	@echo "  - Tailwind CSS"
	@echo "  - Kamal deployment"
