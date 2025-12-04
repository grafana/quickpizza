#!/bin/bash
set -e

# Script to initialize PostgreSQL for Grafana Cloud Database Observability
# This script enables the pg_stat_statements extension and creates the db-o11y user
# with appropriate permissions for database monitoring.
# See https://grafana.com/docs/grafana-cloud/monitor-applications/database-observability/get-started/postgres/

echo "Initializing Database Observability setup..."

# PostgreSQL admin user (used to create the monitoring user and grant permissions)
POSTGRES_USER="${POSTGRES_USER:-postgres}"

# Monitoring user configuration - should be overridden via environment variables
DB_O11Y_USER="${DB_O11Y_USER:-db-o11y}"
DB_O11Y_PASSWORD="${DB_O11Y_PASSWORD:-db-o11y-password}"

# Array of DB_O11Y_DATABASES to configure (default to POSTGRES_DB if not specified)
DB_O11Y_DATABASES="${DB_O11Y_DATABASES:-quickpizza_db}"

echo "Configuring DB_O11Y_DATABASES: $DB_O11Y_DATABASES"
echo "Monitoring user: $DB_O11Y_USER"

# Enable pg_stat_statements for each database
setup_database() {
    local db=$1
    echo "Setting up database: $db"
    
    # Enable pg_stat_statements extension
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-EOSQL
        -- Enable pg_stat_statements extension
        CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
        
        -- Verify extension is installed
        SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';
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

    -- Grant object privileges for detailed data
    GRANT pg_read_all_data TO "$DB_O11Y_USER";

    -- Disable pg_stat_statements tracking for this user
    ALTER ROLE "$DB_O11Y_USER" SET pg_stat_statements.track = 'none';
EOSQL

echo "✓ User $DB_O11Y_USER created with base privileges"

# Configure each database
for db in $DB_O11Y_DATABASES; do
    setup_database "$db"
done

echo ""
echo "✓ Database Observability setup completed successfully!"
echo ""
echo "Configuration summary:"
echo "  - User: $DB_O11Y_USER"
echo "  - DB_O11Y_DATABASES configured: $DB_O11Y_DATABASES"
echo "  - Extensions: pg_stat_statements"
echo ""
echo "Connection string for $DB_O11Y_USER user:"
for db in $DB_O11Y_DATABASES; do
    echo "  postgresql://$DB_O11Y_USER:${DB_O11Y_PASSWORD}@localhost:5432/$db"
done
echo ""
