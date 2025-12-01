#!/bin/bash
set -euo pipefail

# Startup script: start PostgreSQL if needed, ensure DB/user, run migrations (extensions first), and optionally seed.

# Load env if present
if [ -f ".env" ]; then
  set -a
  # shellcheck source=/dev/null
  . ./.env
  set +a
fi

# Defaults
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5000}"
POSTGRES_DB="${POSTGRES_DB:-myapp}"
POSTGRES_USER="${POSTGRES_USER:-appuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-dbuser123}"
DATABASE_URL="${DATABASE_URL:-postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}}"
SEED="${SEED:-false}"

echo "Starting PostgreSQL setup and migrations for ${POSTGRES_DB} on ${POSTGRES_HOST}:${POSTGRES_PORT} ..."

# Detect PG bin path
PG_VERSION=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1 || true)
if [ -n "${PG_VERSION}" ] && [ -x "/usr/lib/postgresql/${PG_VERSION}/bin/psql" ]; then
  PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"
else
  PG_BIN="" # Assume psql and friends are on PATH
fi
PSQL_BIN="${PG_BIN:+${PG_BIN}/}psql"
PG_ISREADY_BIN="${PG_BIN:+${PG_BIN}/}pg_isready"
CREATEDB_BIN="${PG_BIN:+${PG_BIN}/}createdb"
POSTGRES_SERVER_BIN="${PG_BIN:+${PG_BIN}/}postgres"
INITDB_BIN="${PG_BIN:+${PG_BIN}/}initdb"

# Helper to run psql as postgres superuser when local server and we have perms, else via DATABASE_URL
run_psql_super() {
  if id -u postgres >/dev/null 2>&1; then
    sudo -u postgres ${PSQL_BIN} -p "${POSTGRES_PORT}" -d postgres "$@"
  else
    ${PSQL_BIN} "${DATABASE_URL}" "$@"
  fi
}

# Check server status; if not running and local binaries are available, try to start minimal local server
if ! ${PG_ISREADY_BIN} -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" >/dev/null 2>&1; then
  echo "PostgreSQL not ready at ${POSTGRES_HOST}:${POSTGRES_PORT}. Attempting local start (if possible)..."
  if [ -x "${POSTGRES_SERVER_BIN}" ] && id -u postgres >/dev/null 2>&1; then
    if [ ! -f "/var/lib/postgresql/data/PG_VERSION" ]; then
      echo "Initializing data directory..."
      sudo -u postgres ${INITDB_BIN} -D /var/lib/postgresql/data
    fi
    echo "Starting local PostgreSQL server..."
    sudo -u postgres ${POSTGRES_SERVER_BIN} -D /var/lib/postgresql/data -p "${POSTGRES_PORT}" >/tmp/postgres.log 2>&1 &
    for i in {1..30}; do
      if ${PG_ISREADY_BIN} -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" >/dev/null 2>&1; then
        echo "PostgreSQL is ready."
        break
      fi
      sleep 1
    done
  else
    echo "Warning: Could not start local PostgreSQL server. Assuming external server will be reachable."
  fi
fi

# Create DB and user if possible via local superuser; otherwise best effort via URL
echo "Ensuring database and user exist..."
if id -u postgres >/dev/null 2>&1; then
  if ! sudo -u postgres ${PSQL_BIN} -p "${POSTGRES_PORT}" -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" | grep -q 1; then
    sudo -u postgres ${CREATEDB_BIN} -p "${POSTGRES_PORT}" "${POSTGRES_DB}" || true
  fi

  sudo -u postgres ${PSQL_BIN} -p "${POSTGRES_PORT}" -d postgres <<EOF
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
    CREATE ROLE ${POSTGRES_USER} WITH LOGIN PASSWORD '${POSTGRES_PASSWORD}';
  END IF;
  ALTER ROLE ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
END
\$\$;

GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
\connect ${POSTGRES_DB}

GRANT USAGE, CREATE ON SCHEMA public TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${POSTGRES_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${POSTGRES_USER};

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${POSTGRES_USER};
EOF
fi

# Apply migrations idempotently (extensions first)
echo "Applying migrations..."
MIGRATIONS_DIR="migrations"
APPLIED_COUNT=0
if [ -d "${MIGRATIONS_DIR}" ]; then
  ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (id SERIAL PRIMARY KEY, filename TEXT UNIQUE NOT NULL, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW());"

  # Apply 000_extensions.sql first to avoid CITEXT missing errors later
  if [ -f "${MIGRATIONS_DIR}/000_extensions.sql" ]; then
    FILENAME="000_extensions.sql"
    echo "Processing migration: ${FILENAME}"
    COUNT=$(${PSQL_BIN} "${DATABASE_URL}" -tAc "SELECT COUNT(1) FROM schema_migrations WHERE filename='${FILENAME}';" || echo "0")
    if [ "${COUNT}" = "0" ]; then
      ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "${MIGRATIONS_DIR}/${FILENAME}"
      ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations (filename) VALUES ('${FILENAME}');"
      echo " - Applied."
      APPLIED_COUNT=$((APPLIED_COUNT+1))
    else
      echo " - Already applied. Skipping."
    fi
  fi

  # Apply remaining migrations in lexical order excluding extensions file
  for f in $(ls -1 ${MIGRATIONS_DIR}/*.sql | sort); do
    FILENAME=$(basename "$f")
    if [ "${FILENAME}" = "000_extensions.sql" ]; then
      continue
    fi

    echo "Processing migration: ${FILENAME}"
    ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (id SERIAL PRIMARY KEY, filename TEXT UNIQUE NOT NULL, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW());"

    COUNT=$(${PSQL_BIN} "${DATABASE_URL}" -tAc "SELECT COUNT(1) FROM schema_migrations WHERE filename='${FILENAME}';" || echo "0")
    if [ "${COUNT}" != "0" ]; then
      echo " - Already applied. Skipping."
      continue
    fi

    ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "$f"
    ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations (filename) VALUES ('${FILENAME}');"
    echo " - Applied."
    APPLIED_COUNT=$((APPLIED_COUNT+1))
  done
else
  echo "No migrations directory found at ${MIGRATIONS_DIR}"
fi
echo "Migrations complete. Applied ${APPLIED_COUNT} new migration(s)."

# Seed if enabled
if [ "${SEED}" = "true" ] || [ "${SEED}" = "TRUE" ]; then
  if [ -f "seed/seed.sql" ]; then
    echo "Running seed data..."
    ${PSQL_BIN} "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "seed/seed.sql" || {
      echo "Warning: Seeding failed. Continuing."
    }
    echo "Seed completed."
  else
    echo "Seed flag set but seed/seed.sql not found. Skipping."
  fi
else
  echo "SEED flag not set to true. Skipping seed."
fi

# Write connection helper files for convenience
echo "psql ${DATABASE_URL}" > db_connection.txt

mkdir -p db_visualizer
cat > db_visualizer/postgres.env <<EOF
export POSTGRES_URL="postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"
export POSTGRES_USER="${POSTGRES_USER}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export POSTGRES_DB="${POSTGRES_DB}"
export POSTGRES_PORT="${POSTGRES_PORT}"
EOF

echo "Database setup complete."
echo "Connection: ${DATABASE_URL}"
echo "Helper: cat db_connection.txt"
