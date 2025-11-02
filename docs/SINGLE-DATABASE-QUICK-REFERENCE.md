# Single Database Quick Reference

## 🎯 Quick Start

### Fresh Installation

```powershell
# Just start - schemas auto-created
docker-compose up -d
```

### Migrate from Multiple DBs

```powershell
.\scripts\migrate-to-single-database.ps1
# Select option 1 for fresh start
```

## 📊 Architecture

### Before vs After

```
BEFORE: 8 Databases                 AFTER: 8 Schemas
├── core_db                         ├── core_schema
├── analytics_db                    ├── analytics_schema
├── commerce_db                     ├── commerce_schema
├── crm_db                          ├── crm_schema
├── finance_db                      ├── finance_schema
├── logistics_db                    ├── logistics_schema
├── operations_db                   ├── operations_schema
└── supply_db                       └── supply_schema
```

## 🔗 Connection Strings

### Format

```
postgresql://localhost:5432/chiro_erp?currentSchema=<schema_name>
```

### Examples

```properties
# Core Platform
postgresql://localhost:5432/chiro_erp?currentSchema=core_schema

# Commerce
postgresql://localhost:5432/chiro_erp?currentSchema=commerce_schema

# Finance
postgresql://localhost:5432/chiro_erp?currentSchema=finance_schema
```

## 🛠️ Common Commands

### View Schemas

```powershell
docker exec chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "\dn"
```

### View Tables by Schema

```sql
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname LIKE '%_schema'
ORDER BY schemaname, tablename;
```

### Check Schema Sizes

```sql
SELECT
    schemaname,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))::bigint) as size
FROM pg_tables
WHERE schemaname LIKE '%_schema'
GROUP BY schemaname
ORDER BY sum(pg_total_relation_size(schemaname||'.'||tablename)) DESC;
```

### Active Connections

```sql
SELECT
    current_schema,
    usename,
    COUNT(*)
FROM pg_stat_activity
WHERE datname = 'chiro_erp'
GROUP BY current_schema, usename;
```

## 🔒 Security

### Schema Ownership

| Schema            | Owner           |
| ----------------- | --------------- |
| core_schema       | core_user       |
| analytics_schema  | analytics_user  |
| commerce_schema   | commerce_user   |
| crm_schema        | crm_user        |
| finance_schema    | finance_user    |
| logistics_schema  | logistics_user  |
| operations_schema | operations_user |
| supply_schema     | supply_user     |

### Permissions

-   Each user can ONLY access their own schema
-   No cross-schema access by default
-   Public schema has no tables

## 💾 Backup & Restore

### Full Backup

```powershell
docker exec chiro-erp-postgresql-1 pg_dump -U postgres chiro_erp > backup.sql
```

### Schema-Specific Backup

```powershell
docker exec chiro-erp-postgresql-1 pg_dump -U postgres -d chiro_erp -n core_schema > core_backup.sql
```

### Restore Full Database

```powershell
Get-Content backup.sql | docker exec -i chiro-erp-postgresql-1 psql -U postgres -d chiro_erp
```

### Restore Single Schema

```powershell
Get-Content core_backup.sql | docker exec -i chiro-erp-postgresql-1 psql -U core_user -d chiro_erp
```

## 🧪 Testing

### Health Checks

```powershell
.\scripts\test-health-checks.ps1
```

### Verify Schema Creation

```powershell
.\scripts\migrate-to-single-database.ps1
# Select option 3
```

### Test Service Connection

```powershell
docker exec chiro-erp-postgresql-1 psql -U core_user -d chiro_erp -c "SET search_path TO core_schema; SELECT current_schema();"
```

## 📈 Monitoring

### Database Size

```sql
SELECT pg_size_pretty(pg_database_size('chiro_erp'));
```

### Connection Count

```sql
SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'chiro_erp';
```

### Table Counts

```sql
SELECT
    schemaname,
    COUNT(*) as table_count,
    COUNT(*) FILTER (WHERE schemaname = current_schema) as in_current_schema
FROM pg_tables
WHERE schemaname LIKE '%_schema'
GROUP BY schemaname;
```

### Slow Queries by Schema

```sql
SELECT
    current_schema,
    query,
    calls,
    total_exec_time,
    mean_exec_time
FROM pg_stat_statements
WHERE current_schema LIKE '%_schema'
ORDER BY mean_exec_time DESC
LIMIT 10;
```

## ⚠️ Troubleshooting

### Tables in Wrong Schema

```sql
-- Move table to correct schema
ALTER TABLE public.mytable SET SCHEMA core_schema;
```

### Permission Denied

```sql
-- Grant schema access
GRANT USAGE ON SCHEMA core_schema TO core_user;
GRANT ALL ON ALL TABLES IN SCHEMA core_schema TO core_user;
```

### Connection Issues

Check connection string has schema parameter:

```
?currentSchema=schema_name
```

Check user has connect permission:

```sql
GRANT CONNECT ON DATABASE chiro_erp TO core_user;
```

## 📚 Documentation

-   **Full Migration Guide:** `docs/SINGLE-DATABASE-MIGRATION.md`
-   **Summary:** `docs/SINGLE-DATABASE-RESTRUCTURE-SUMMARY.md`
-   **Database Strategy:** `docs/DATABASE-STRATEGY.md`
-   **Scripts README:** `scripts/README.md`

## ✅ Benefits

-   ✅ **70% less memory** - 1 DB instance instead of 8+
-   ✅ **Faster startup** - Less initialization
-   ✅ **Easier backups** - Single backup command
-   ✅ **Simpler management** - One DB to monitor
-   ✅ **Better performance** - Shared query planner
-   ✅ **Same isolation** - Schemas maintain separation

## 🔄 Rollback

```powershell
# Stop services
docker-compose down

# Restore backup
docker exec -i chiro-erp-postgresql-1 psql -U postgres < backup.sql

# Revert config
git checkout HEAD~1 -- scripts/ services/

# Restart
docker-compose up -d
```

---

**Last Updated:** November 2, 2025
**Database:** PostgreSQL 15
**Pattern:** Single Database with Schema Separation
