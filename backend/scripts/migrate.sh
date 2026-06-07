#!/usr/bin/env bash
# Applies SQL migrations (and the demo seed) once, on a fresh database.
# Used by the `migrate` service in docker-compose.
set -e

HOST="${DB_HOST:-db}"

echo "waiting for postgres at ${HOST}..."
until psql -h "$HOST" -U "$PGUSER" -d "$PGDATABASE" -c 'SELECT 1' >/dev/null 2>&1; do
    sleep 1
done

if [ -z "$(psql -h "$HOST" -U "$PGUSER" -d "$PGDATABASE" -tAc "SELECT to_regclass('public.pbx')")" ]; then
    echo "applying migrations..."
    for f in /migrations/0*.sql; do
        echo "  - $f"
        psql -h "$HOST" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -q -f "$f"
    done
    echo "seeding demo data..."
    psql -h "$HOST" -U "$PGUSER" -d "$PGDATABASE" -v ON_ERROR_STOP=1 -q -f /seeds/dev_seed.sql
    echo "migrations + seed complete."
else
    echo "schema already present, skipping migrations."
fi
