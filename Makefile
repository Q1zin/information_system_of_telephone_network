# Convenience targets for the ГТС information system.
# Override the target database with:  make reset DB=gts
DB ?= gts_dev
PSQL := psql -d $(DB) -v ON_ERROR_STOP=1

.PHONY: help db-up db-down migrate seed reset psql

help:
	@echo "Targets:"
	@echo "  make db-up     - start PostgreSQL + Adminer via docker compose"
	@echo "  make db-down   - stop docker compose services"
	@echo "  make migrate   - apply all SQL migrations to DB=$(DB)"
	@echo "  make seed      - load demo data into DB=$(DB)"
	@echo "  make reset     - drop, recreate, migrate and seed DB=$(DB)"
	@echo "  make psql      - open psql on DB=$(DB)"

db-up:
	docker compose up -d db adminer

db-down:
	docker compose down

migrate:
	@for f in backend/migrations/0*.sql; do \
		echo "applying $$f"; \
		$(PSQL) -q -f $$f || exit 1; \
	done
	@echo "migrations applied to $(DB)"

seed:
	$(PSQL) -q -f backend/seeds/dev_seed.sql
	@echo "demo data loaded into $(DB)"

reset:
	dropdb --if-exists $(DB)
	createdb $(DB)
	$(MAKE) migrate DB=$(DB)
	$(MAKE) seed DB=$(DB)

psql:
	psql -d $(DB)
