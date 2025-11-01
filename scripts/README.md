# Scripts Directory

This directory contains utility scripts for the Chiro ERP project.

## 📁 Available Scripts

### PowerShell Scripts

#### `create-complete-structure.ps1`

Creates the complete consolidated ERP structure with:

-   8 consolidated services
-   36 domain structures
-   Hexagonal architecture layout
-   SAP ERP pattern alignment

**Usage:**

```powershell
.\scripts\create-complete-structure.ps1
```

#### `consolidate-microservices.ps1`

Legacy consolidation script for migrating from original 30+ microservices structure.

**Usage:**

```powershell
.\scripts\consolidate-microservices.ps1
```

#### `setup-health-checks.ps1` ✨ NEW

Generates health check classes for all remaining microservices.
Creates DatabaseHealthCheck.kt and LivenessCheck.kt for each service.

**Usage:**

```powershell
.\scripts\setup-health-checks.ps1
```

**Generates health checks for:**

-   analytics-intelligence
-   customer-relationship
-   financial-management
-   logistics-transportation
-   operations-service
-   supply-chain-manufacturing

#### `test-health-checks.ps1` ✨ NEW

Tests health endpoints for all 8 microservices.
Validates readiness probes and reports status.

**Usage:**

```powershell
# Test all services
.\scripts\test-health-checks.ps1

# Services must be running first
docker-compose up -d
.\scripts\test-health-checks.ps1
```

**Output:**

-   ✓ Healthy services (green)
-   ⚠ Unhealthy services (yellow)
-   ✗ Unreachable services (red)
-   Summary statistics
-   Docker container status

#### `start-microservices.ps1`

Starts all microservices using docker-compose.

**Usage:**

```powershell
.\scripts\start-microservices.ps1
```

### SQL Scripts

#### `init-databases.sql`

Initializes all PostgreSQL databases for the 8 microservices.
Creates users, databases, and grants permissions.

**Databases:**

-   core_db
-   analytics_db
-   commerce_db
-   crm_db
-   finance_db
-   logistics_db
-   operations_db
-   supply_db

**Usage:**
Automatically executed by docker-compose on PostgreSQL container startup.

## 🚀 Quick Start

### Initial Setup

To set up the complete ERP structure:

```powershell
cd chiro-erp
.\scripts\create-complete-structure.ps1
```

### Start Services

```powershell
# Start all services
docker-compose up -d

# Wait for services to start (60s grace period)
Start-Sleep -Seconds 60

# Test health checks
.\scripts\test-health-checks.ps1
```

### Development Workflow

```powershell
# 1. Make code changes
# 2. Rebuild specific service
docker-compose up -d --build commerce

# 3. Test health
.\scripts\test-health-checks.ps1

# 4. View logs
docker-compose logs -f commerce
```

## 📖 Related Documentation

-   [Architecture Documentation](../docs/architecture/) - Detailed architecture information
-   [Migration Documentation](../docs/migration/) - Migration strategies and plans
-   [Health Checks Guide](../docs/HEALTH-CHECKS.md) - Health check implementation details
-   [Deployment Tasks](../docs/DEPLOYMENT-OPTIMIZATION-TASKS.md) - Deployment optimization tasks
-   [Templates](../templates/) - Build and structure templates

## 🔧 Maintenance Scripts (Coming Soon)

Future scripts planned:

-   `backup-databases.ps1` - Backup all databases
-   `restore-databases.ps1` - Restore from backup
-   `generate-api-docs.ps1` - Generate OpenAPI documentation
-   `run-integration-tests.ps1` - Run integration test suite
-   `deploy-to-production.ps1` - Production deployment script
