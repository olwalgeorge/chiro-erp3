# Single Database Migration Script
# This script helps migrate from multiple databases to a single database with schemas

Write-Host "=== ChiroERP Single Database Migration ===" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
$dockerRunning = docker info 2>$null
if (-not $dockerRunning) {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Function to wait for PostgreSQL
function Wait-ForPostgres {
    Write-Host "Waiting for PostgreSQL to be ready..." -ForegroundColor Yellow
    $maxAttempts = 30
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        docker exec chiro-erp-postgresql-1 pg_isready -U postgres 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ PostgreSQL is ready" -ForegroundColor Green
            return $true
        }
        $attempt++
        Start-Sleep -Seconds 2
        Write-Host "." -NoNewline
    }

    Write-Host ""
    Write-Host "❌ PostgreSQL did not become ready in time" -ForegroundColor Red
    return $false
}

# Ask user what they want to do
Write-Host "Migration Options:" -ForegroundColor Cyan
Write-Host "1. Fresh Start (Clean migration, no data preservation)"
Write-Host "2. Backup Current Data (Backup existing databases before migration)"
Write-Host "3. View Current Schema Status"
Write-Host "4. Cancel"
Write-Host ""

$choice = Read-Host "Select option (1-4)"

switch ($choice) {
    "1" {
        # Fresh start - clean migration
        Write-Host ""
        Write-Host "=== Fresh Start Migration ===" -ForegroundColor Cyan

        # Stop all services
        Write-Host "Stopping all services..." -ForegroundColor Yellow
        docker-compose down

        # Remove old volumes
        Write-Host "Removing old database volumes..." -ForegroundColor Yellow
        docker volume rm chiro-erp_postgres_data 2>$null

        # Start PostgreSQL
        Write-Host "Starting PostgreSQL with new schema configuration..." -ForegroundColor Yellow
        docker-compose up -d postgresql

        if (-not (Wait-ForPostgres)) {
            exit 1
        }

        # Verify schemas were created
        Write-Host ""
        Write-Host "Verifying schema creation..." -ForegroundColor Yellow
        docker exec chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "\dn"

        Write-Host ""
        Write-Host "✅ Fresh migration complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Start infrastructure: docker-compose up -d redis kafka"
        Write-Host "2. Start services: docker-compose up -d"
        Write-Host "3. Test health checks: .\scripts\test-health-checks.ps1"
    }

    "2" {
        # Backup current data
        Write-Host ""
        Write-Host "=== Backup Current Data ===" -ForegroundColor Cyan

        # Create backup directory
        $backupDir = ".\backups\$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

        Write-Host "Backup directory: $backupDir" -ForegroundColor Yellow

        # Start PostgreSQL if not running
        Write-Host "Ensuring PostgreSQL is running..." -ForegroundColor Yellow
        docker-compose up -d postgresql

        if (-not (Wait-ForPostgres)) {
            exit 1
        }

        # Backup all databases
        Write-Host ""
        Write-Host "Creating full backup..." -ForegroundColor Yellow
        docker exec chiro-erp-postgresql-1 pg_dumpall -U postgres > "$backupDir\full_backup.sql"

        # Backup individual databases
        $databases = @('core_db', 'analytics_db', 'commerce_db', 'crm_db', 'finance_db', 'logistics_db', 'operations_db', 'supply_db')

        foreach ($db in $databases) {
            Write-Host "Backing up $db..." -ForegroundColor Yellow
            docker exec chiro-erp-postgresql-1 pg_dump -U postgres -d $db 2>$null > "$backupDir\backup_$db.sql"

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ $db backed up" -ForegroundColor Green
            }
            else {
                Write-Host "  ⚠️  $db not found or empty" -ForegroundColor DarkYellow
            }
        }

        Write-Host ""
        Write-Host "✅ Backup complete!" -ForegroundColor Green
        Write-Host "Backups saved to: $backupDir" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "To complete migration, run this script again and select option 1 (Fresh Start)" -ForegroundColor Yellow
    }

    "3" {
        # View current status
        Write-Host ""
        Write-Host "=== Current Schema Status ===" -ForegroundColor Cyan

        # Check if PostgreSQL is running
        $postgresRunning = docker ps --filter "name=chiro-erp-postgresql" --format "{{.Names}}" 2>$null

        if (-not $postgresRunning) {
            Write-Host "❌ PostgreSQL is not running" -ForegroundColor Red
            Write-Host "Start it with: docker-compose up -d postgresql" -ForegroundColor Yellow
            exit 1
        }

        Write-Host ""
        Write-Host "Databases:" -ForegroundColor Cyan
        docker exec chiro-erp-postgresql-1 psql -U postgres -c "\l" | Select-String -Pattern "core_db|analytics_db|commerce_db|crm_db|finance_db|logistics_db|operations_db|supply_db|chiro_erp"

        Write-Host ""
        Write-Host "Checking if chiro_erp database exists..." -ForegroundColor Yellow
        $chiroDbExists = docker exec chiro-erp-postgresql-1 psql -U postgres -lqt 2>$null | Select-String -Pattern "chiro_erp"

        if ($chiroDbExists) {
            Write-Host "✅ chiro_erp database found" -ForegroundColor Green
            Write-Host ""
            Write-Host "Schemas in chiro_erp:" -ForegroundColor Cyan
            docker exec chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "\dn"

            Write-Host ""
            Write-Host "Tables by schema:" -ForegroundColor Cyan
            docker exec chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "SELECT schemaname, COUNT(*) as table_count FROM pg_tables WHERE schemaname LIKE '%_schema' GROUP BY schemaname ORDER BY schemaname;"
        }
        else {
            Write-Host "⚠️  chiro_erp database not found - migration not yet complete" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Active connections:" -ForegroundColor Cyan
        docker exec chiro-erp-postgresql-1 psql -U postgres -c "SELECT datname, usename, application_name, state, COUNT(*) FROM pg_stat_activity WHERE datname IS NOT NULL GROUP BY datname, usename, application_name, state ORDER BY datname;"
    }

    "4" {
        Write-Host "Migration cancelled." -ForegroundColor Yellow
        exit 0
    }

    default {
        Write-Host "Invalid option selected." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "For detailed migration guide, see: .\docs\SINGLE-DATABASE-MIGRATION.md" -ForegroundColor Cyan
