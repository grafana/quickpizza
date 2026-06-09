#!/bin/bash
set -e

# Script to initialize PostgreSQL for Grafana Cloud Database Observability
# This script enables the pg_stat_statements extension, creates the db-o11y user
# with appropriate permissions for database monitoring, and configures
# log_line_prefix for log processing.
# See https://grafana.com/docs/grafana-cloud/monitor-applications/database-observability/get-started/postgres/

echo "Initializing Database Observability setup..."

# PostgreSQL admin user (used to create the monitoring user and grant permissions)
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Monitoring user configuration - should be overridden via environment variables
DB_O11Y_USER="${DB_O11Y_USER:-db-o11y}"
DB_O11Y_PASSWORD="${DB_O11Y_PASSWORD:-db-o11y-password}"

# Array of DB_O11Y_DATABASES to configure (default to POSTGRES_DB if not specified)
DB_O11Y_DATABASES="${DB_O11Y_DATABASES:-quickpizza_db}"

REQUIRED_LOG_LINE_PREFIX='%m:%r:%u@%d:[%p]:%l:%e:%s:%v:%x:%c:%q%a:'

echo "Configuring DB_O11Y_DATABASES: $DB_O11Y_DATABASES"
echo "Monitoring user: $DB_O11Y_USER"

# Configure log_line_prefix for log processing (requires superuser, persists across restarts)
configure_log_line_prefix() {
    echo "Checking log_line_prefix configuration..."

    local current
    current=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" -Atc \
        "SHOW log_line_prefix;")

    if [ "$current" = "$REQUIRED_LOG_LINE_PREFIX" ]; then
        echo "✓ log_line_prefix already set correctly, skipping"
        return
    fi

    echo "  Current : $current"
    echo "  Required: $REQUIRED_LOG_LINE_PREFIX"

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
        ALTER SYSTEM SET log_line_prefix = '$REQUIRED_LOG_LINE_PREFIX';
        SELECT pg_reload_conf();
EOSQL

    echo "✓ log_line_prefix updated and configuration reloaded"
}

# Enable pg_stat_statements for each database
setup_database() {
    local db=$1
    echo "Setting up database: $db"
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

        GRANT USAGE ON SCHEMA public TO "$DB_O11Y_USER";
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO "$DB_O11Y_USER";

        -- Cover tables created in the future by any role
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "$DB_O11Y_USER";
        ALTER DEFAULT PRIVILEGES FOR ROLE "$POSTGRES_USER" IN SCHEMA public GRANT SELECT ON TABLES TO "$DB_O11Y_USER";
EOSQL

    echo "✓ pg_stat_statements extension enabled for database: $db"
}

# Create the db-o11y user (only once, not per database)
# reate a monitoring user and grant required privileges
echo "Creating $DB_O11Y_USER user..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Create user if it doesn't exist
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$DB_O11Y_USER') THEN
            CREATE USER "$DB_O11Y_USER" WITH PASSWORD '$DB_O11Y_PASSWORD';
            RAISE NOTICE 'User $DB_O11Y_USER created';
        ELSE
            RAISE NOTICE 'User $DB_O11Y_USER already exists';
        END IF;
    END
    \$\$;
    
    -- Grant base monitoring privileges
    GRANT pg_monitor TO "$DB_O11Y_USER";
    GRANT pg_read_all_stats TO "$DB_O11Y_USER";

EOSQL

echo "✓ User $DB_O11Y_USER created with base privileges"

# Configure each database
for db in $DB_O11Y_DATABASES; do
    setup_database "$db"
done

configure_log_line_prefix

echo ""
echo "✓ Database Observability setup completed successfully!"
echo ""
echo "Configuration summary:"
echo "  - User: $DB_O11Y_USER"
echo "  - DB_O11Y_DATABASES configured: $DB_O11Y_DATABASES"
echo "  - Extensions: pg_stat_statements"
echo "  - Log line prefix: configured"
echo ""
echo "Connection string for $DB_O11Y_USER user:"
for db in $DB_O11Y_DATABASES; do
    echo "  postgresql://$DB_O11Y_USER:${DB_O11Y_PASSWORD}@localhost:5432/$db"
done
echo ""
