# Single Database Migration Guide

## Overview

This guide documents the migration from a **database-per-service** pattern to a **single database with schema separation** pattern.

## Architecture Change

### Before (Database-per-Service)

```
PostgreSQL Instance
├── core_db (dedicated database)
├── analytics_db (dedicated database)
├── commerce_db (dedicated database)
├── crm_db (dedicated database)
├── finance_db (dedicated database)
├── logistics_db (dedicated database)
├── operations_db (dedicated database)
├── supply_db (dedicated database)
└── keycloak (dedicated database)
```

### After (Single Database with Schemas)

```
PostgreSQL Instance
├── chiro_erp (single shared database)
│   ├── core_schema
│   ├── analytics_schema
│   ├── commerce_schema
│   ├── crm_schema
│   ├── finance_schema
│   ├── logistics_schema
│   ├── operations_schema
│   └── supply_schema
└── keycloak (separate database for Keycloak)
```

## Benefits

### Resource Optimization

-   **Reduced Memory Usage**: One database process instead of 8+
-   **Lower CPU Overhead**: Single instance management
-   **Simplified Backups**: One database to backup instead of 8
-   **Connection Pool Efficiency**: Shared connection management

### Operational Benefits

-   **Simplified Management**: Single point of administration
-   **Easier Monitoring**: Centralized metrics and logs
-   **Better Query Performance**: Potential for cross-schema queries when needed
-   **Reduced Storage Overhead**: Single WAL, checkpoint, and vacuum process

### Development Benefits

-   **Faster Local Setup**: Less resource intensive
-   **Easier Testing**: Single database to manage in tests
-   **Simplified Migrations**: Coordinated schema updates possible
-   **Data Integrity**: Can use foreign keys across schemas if needed (with caution)

## Data Isolation

Despite using one database, **data remains isolated** through:

1. **Separate Schemas**: Each service has its own PostgreSQL schema
2. **User Permissions**: Each service user can only access their own schema
3. **Default Schema**: Connection strings specify the default schema
4. **Search Path**: Hibernate ORM configured to use specific schemas

## Configuration Changes

### Database URL Format

**Before:**

```properties
quarkus.datasource.reactive.url=postgresql://localhost:5432/service_db
```

**After:**

```properties
quarkus.datasource.reactive.url=postgresql://localhost:5432/chiro_erp?currentSchema=service_schema
quarkus.hibernate-orm.database.default-schema=service_schema
```

### Service Mappings

| Service                    | Old Database  | New Schema        | User            |
| -------------------------- | ------------- | ----------------- | --------------- |
| core-platform              | core_db       | core_schema       | core_user       |
| analytics-intelligence     | analytics_db  | analytics_schema  | analytics_user  |
| commerce                   | commerce_db   | commerce_schema   | commerce_user   |
| customer-relationship      | crm_db        | crm_schema        | crm_user        |
| financial-management       | finance_db    | finance_schema    | finance_user    |
| logistics-transportation   | logistics_db  | logistics_schema  | logistics_user  |
| operations-service         | operations_db | operations_schema | operations_user |
| supply-chain-manufacturing | supply_db     | supply_schema     | supply_user     |

## Migration Steps

### 1. Stop All Services

```powershell
docker-compose down
```

### 2. Backup Existing Data (if any)

```powershell
# Backup all databases
docker-compose up -d postgresql
docker exec -it chiro-erp-postgresql-1 pg_dumpall -U postgres > backup_all_databases.sql
docker-compose down
```

### 3. Clean Docker Volumes (Fresh Start)

```powershell
# Remove old database volumes
docker volume rm chiro-erp_postgres_data
```

Or to keep data and migrate:

```powershell
# Export data from each database
docker-compose up -d postgresql

# For each service database
$databases = @('core_db', 'analytics_db', 'commerce_db', 'crm_db', 'finance_db', 'logistics_db', 'operations_db', 'supply_db')

foreach ($db in $databases) {
    docker exec -it chiro-erp-postgresql-1 pg_dump -U postgres -d $db > "backup_$db.sql"
}

docker-compose down
```

### 4. Start PostgreSQL with New Schema

```powershell
# The init-databases.sql script will automatically create schemas
docker-compose up -d postgresql

# Wait for PostgreSQL to initialize
Start-Sleep -Seconds 10

# Verify schemas were created
docker exec -it chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "\dn"
```

Expected output:

```
        List of schemas
        Name        |     Owner
--------------------+----------------
 analytics_schema   | analytics_user
 commerce_schema    | commerce_user
 core_schema        | core_user
 crm_schema         | crm_user
 finance_schema     | finance_user
 logistics_schema   | logistics_user
 operations_schema  | operations_user
 public             | postgres
 supply_schema      | supply_user
```

### 5. Migrate Existing Data (if applicable)

If you backed up data and want to migrate it:

```powershell
# For each service, import data into the new schema
# Example for core_db -> core_schema:

# 1. Modify the backup SQL to set the schema
docker exec -i chiro-erp-postgresql-1 psql -U core_user -d chiro_erp <<EOF
SET search_path TO core_schema;
\i backup_core_db.sql
EOF

# Repeat for each service
```

Or use a migration script:

```powershell
# Create migration script
$services = @(
    @{db='core_db'; schema='core_schema'; user='core_user'},
    @{db='analytics_db'; schema='analytics_schema'; user='analytics_user'},
    @{db='commerce_db'; schema='commerce_schema'; user='commerce_user'},
    @{db='crm_db'; schema='crm_schema'; user='crm_user'},
    @{db='finance_db'; schema='finance_schema'; user='finance_user'},
    @{db='logistics_db'; schema='logistics_schema'; user='logistics_user'},
    @{db='operations_db'; schema='operations_schema'; user='operations_user'},
    @{db='supply_db'; schema='supply_schema'; user='supply_user'}
)

foreach ($svc in $services) {
    $backup = "backup_$($svc.db).sql"
    if (Test-Path $backup) {
        Write-Host "Migrating $($svc.db) to $($svc.schema)..."

        # Import into new schema
        Get-Content $backup | docker exec -i chiro-erp-postgresql-1 psql -U $svc.user -d chiro_erp -v ON_ERROR_STOP=1 --set=search_path=$($svc.schema)
    }
}
```

### 6. Start All Services

```powershell
# Start infrastructure
docker-compose up -d postgresql redis kafka

# Wait for services to be ready
Start-Sleep -Seconds 15

# Start microservices
docker-compose up -d

# Or use the startup script
.\scripts\start-microservices.ps1
```

### 7. Verify Migration

```powershell
# Check that tables were created in correct schemas
docker exec -it chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;
"

# Test health checks
.\scripts\test-health-checks.ps1

# Check application logs
docker-compose logs core-platform
docker-compose logs commerce
# ... check other services
```

## Rollback Plan

If you need to rollback to separate databases:

### 1. Restore from Backup

```powershell
# Stop all services
docker-compose down

# Restore the original backup
docker volume rm chiro-erp_postgres_data
docker-compose up -d postgresql
Start-Sleep -Seconds 10

docker exec -i chiro-erp-postgresql-1 psql -U postgres < backup_all_databases.sql
```

### 2. Revert Configuration Files

```powershell
# Use git to revert changes
git checkout HEAD~1 -- scripts/init-databases.sql
git checkout HEAD~1 -- services/*/src/main/resources/application.properties
```

### 3. Restart Services

```powershell
docker-compose up -d
```

## Schema Management Best Practices

### 1. Schema Isolation

-   Each service only accesses its own schema
-   Never hardcode schema names in queries
-   Use Hibernate's default schema configuration

### 2. Cross-Schema References

-   **Avoid direct foreign keys** across schemas
-   Use service-to-service APIs for cross-domain data
-   Store only IDs for cross-references (not foreign keys)

### 3. Schema Migrations

-   Use Liquibase/Flyway for schema versioning
-   Each service manages its own schema migrations
-   Test migrations in isolated environments

### 4. Monitoring

-   Monitor per-schema table sizes
-   Track query performance by schema
-   Set up alerts for schema-specific issues

### 5. Backups

-   Backup the entire database regularly
-   Can still export individual schemas for selective restores:
    ```bash
    pg_dump -U postgres -d chiro_erp -n core_schema > core_schema_backup.sql
    ```

## Performance Considerations

### Connection Pooling

Each service maintains its own connection pool but shares the database:

```properties
quarkus.datasource.reactive.max-size=20
quarkus.datasource.reactive.idle-timeout=PT10M
```

### Schema-Specific Tuning

```sql
-- Set per-schema configuration (if needed)
ALTER SCHEMA core_schema SET random_page_cost = 1.1;
ALTER SCHEMA analytics_schema SET work_mem = '64MB';
```

### Monitoring Queries

```sql
-- Check active connections per schema
SELECT
    current_schema,
    usename,
    application_name,
    state,
    COUNT(*)
FROM pg_stat_activity
WHERE datname = 'chiro_erp'
GROUP BY current_schema, usename, application_name, state;
```

## Security Considerations

### User Permissions

Each user can only access their schema:

```sql
-- Verify permissions
SELECT
    schemaname,
    array_agg(DISTINCT grantee) as users
FROM information_schema.schema_privileges
WHERE schemaname LIKE '%_schema'
GROUP BY schemaname;
```

### Row-Level Security

Can be added if needed:

```sql
-- Example: Enable RLS on a table
ALTER TABLE core_schema.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_isolation ON core_schema.users
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

## Troubleshooting

### Issue: Tables Created in Wrong Schema

**Symptom**: Tables appear in `public` schema instead of service schema

**Solution**:

```sql
-- Check current schema
SHOW search_path;

-- Set default schema for user
ALTER USER core_user SET search_path TO core_schema;
```

### Issue: Permission Denied

**Symptom**: `ERROR: permission denied for schema`

**Solution**:

```sql
-- Grant necessary permissions
GRANT USAGE ON SCHEMA core_schema TO core_user;
GRANT ALL ON ALL TABLES IN SCHEMA core_schema TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA core_schema GRANT ALL ON TABLES TO core_user;
```

### Issue: Cannot Connect to Database

**Symptom**: `database "service_db" does not exist`

**Solution**: Update the connection string to use `chiro_erp` database:

```properties
quarkus.datasource.reactive.url=postgresql://localhost:5432/chiro_erp?currentSchema=service_schema
```

## Testing

### Unit Tests

Tests should continue to work as they don't use the database:

```properties
%test.quarkus.datasource.active=false
```

### Integration Tests

For integration tests with database:

```properties
%test.quarkus.datasource.reactive.url=postgresql://localhost:5432/chiro_erp_test?currentSchema=test_schema
```

## Monitoring and Maintenance

### Database Size Monitoring

```sql
-- Check size per schema
SELECT
    schemaname,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))::bigint) as size
FROM pg_tables
WHERE schemaname LIKE '%_schema'
GROUP BY schemaname
ORDER BY sum(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
```

### Index Usage

```sql
-- Check index usage per schema
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname LIKE '%_schema'
ORDER BY idx_scan DESC;
```

## Conclusion

This migration simplifies the database architecture while maintaining logical separation and security. The schema-based approach provides:

-   ✅ **Resource efficiency** - Single database instance
-   ✅ **Logical isolation** - Separate schemas per service
-   ✅ **Security** - User-level access control
-   ✅ **Simplicity** - Easier management and monitoring
-   ✅ **Flexibility** - Can still do cross-schema queries when necessary (with caution)

The microservices remain **loosely coupled** and **independently deployable** - we've only changed the physical database structure, not the logical service boundaries.
