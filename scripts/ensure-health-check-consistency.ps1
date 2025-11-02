# Health Check Consistency Validator and Enforcer
# This script ensures all ChiroERP microservices have consistent health check implementations

param(
    [switch]$Fix = $false,
    [switch]$Verbose = $false,
    [switch]$Report = $false
)

$ErrorActionPreference = "Stop"

# Color functions
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Detail { param($msg) if ($Verbose) { Write-Host $msg -ForegroundColor Gray } }

# Service definitions with expected health checks
$services = @(
    @{
        Name               = "core-platform"
        Port               = 8081
        Path               = "./services/core-platform"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Database connection health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    },
    @{
        Name               = "administration"
        Port               = 8082
        Path               = "./services/administration"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    },
    @{
        Name               = "customer-relationship"
        Port               = 8083
        Path               = "./services/customer-relationship"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka", "MinIO")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    },
    @{
        Name               = "operations-service"
        Port               = 8084
        Path               = "./services/operations-service"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka", "MinIO")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    },
    @{
        Name               = "commerce"
        Port               = 8085
        Path               = "./services/commerce"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Database connection health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka", "MinIO")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    },
    @{
        Name               = "financial-management"
        Port               = 8086
        Path               = "./services/financial-management"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    },
    @{
        Name               = "supply-chain-manufacturing"
        Port               = 8087
        Path               = "./services/supply-chain-manufacturing"
        ExpectedChecks     = @(
            "Reactive PostgreSQL connections health check",
            "Redis connection health check",
            "SmallRye Reactive Messaging - readiness check"
        )
        Dependencies       = @("PostgreSQL", "Redis", "Kafka", "MinIO")
        RequiredExtensions = @(
            "quarkus-smallrye-health",
            "quarkus-redis-client",
            "quarkus-smallrye-reactive-messaging-kafka",
            "quarkus-reactive-pg-client"
        )
    }
)

Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Info "  ChiroERP Health Check Consistency Validator"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

if ($Fix) {
    Write-Warning "⚠️  FIX MODE ENABLED - Will modify build.gradle and application.properties files"
    Write-Host ""
}

# Results tracking
$results = @{
    TotalServices = $services.Count
    Passed        = 0
    Failed        = 0
    Issues        = @()
    Fixed         = 0
}

# Function to check if service is running
function Test-ServiceRunning {
    param($Port)
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/q/health/ready" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

# Function to get actual health checks
function Get-ActualHealthChecks {
    param($Port)
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$Port/q/health/ready" -TimeoutSec 5 -ErrorAction Stop
        return $response.checks | ForEach-Object { $_.name }
    }
    catch {
        return @()
    }
}

# Function to check build.gradle for extensions
function Test-BuildGradleExtensions {
    param($ServicePath, $RequiredExtensions)

    $buildGradlePath = Join-Path $ServicePath "build.gradle.kts"
    if (-not (Test-Path $buildGradlePath)) {
        $buildGradlePath = Join-Path $ServicePath "build.gradle"
    }

    if (-not (Test-Path $buildGradlePath)) {
        return @{
            Exists            = $false
            MissingExtensions = $RequiredExtensions
        }
    }

    $buildContent = Get-Content $buildGradlePath -Raw
    $missingExtensions = @()

    foreach ($extension in $RequiredExtensions) {
        if ($buildContent -notmatch [regex]::Escape($extension)) {
            $missingExtensions += $extension
        }
    }

    return @{
        Exists            = $true
        MissingExtensions = $missingExtensions
        Path              = $buildGradlePath
    }
}

# Function to add missing extensions to build.gradle
function Add-MissingExtensions {
    param($BuildGradlePath, $MissingExtensions)

    Write-Info "  📝 Adding missing extensions to $BuildGradlePath"

    $content = Get-Content $BuildGradlePath -Raw

    # Find the dependencies block
    if ($content -match "dependencies\s*\{") {
        $extensionsToAdd = @()
        foreach ($ext in $MissingExtensions) {
            $extensionsToAdd += "    implementation(`"io.quarkus:$ext`")"
        }

        # Add after dependencies { line
        $newContent = $content -replace "(dependencies\s*\{)", "`$1`n    // Health check extensions`n$($extensionsToAdd -join "`n")"

        Set-Content -Path $BuildGradlePath -Value $newContent -NoNewline
        Write-Success "    ✓ Added $($MissingExtensions.Count) extensions"
        return $true
    }
    else {
        Write-Error "    ✗ Could not find dependencies block in build.gradle"
        return $false
    }
}

# Function to update application.properties
function Update-ApplicationProperties {
    param($ServicePath)

    $propsPath = Join-Path $ServicePath "src/main/resources/application.properties"

    if (-not (Test-Path $propsPath)) {
        Write-Warning "    ⚠️  application.properties not found, creating..."
        $propsDir = Split-Path $propsPath -Parent
        if (-not (Test-Path $propsDir)) {
            New-Item -ItemType Directory -Path $propsDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $propsPath -Force | Out-Null
    }

    $content = Get-Content $propsPath -Raw

    $healthCheckProps = @"

# Health Check Configuration
quarkus.health.extensions.enabled=true
quarkus.redis.health.enabled=true
mp.messaging.health.enabled=true
"@

    # Check if health check configuration already exists
    if ($content -notmatch "quarkus.health.extensions.enabled") {
        Add-Content -Path $propsPath -Value $healthCheckProps
        Write-Success "    ✓ Added health check configuration to application.properties"
        return $true
    }
    else {
        Write-Detail "    ℹ  Health check configuration already exists"
        return $false
    }
}

# Main validation loop
Write-Info "🔍 Validating health check consistency...`n"

foreach ($service in $services) {
    Write-Host "[$($service.Name)]" -ForegroundColor Yellow -NoNewline
    Write-Host " Port $($service.Port)" -ForegroundColor Gray
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

    $serviceIssues = @()
    $isRunning = Test-ServiceRunning -Port $service.Port

    if ($isRunning) {
        Write-Success "  ✓ Service is running"

        # Get actual health checks
        $actualChecks = Get-ActualHealthChecks -Port $service.Port
        Write-Detail "  Found $($actualChecks.Count) health checks"

        # Compare with expected
        $missingChecks = @()
        foreach ($expectedCheck in $service.ExpectedChecks) {
            if ($actualChecks -notcontains $expectedCheck) {
                $missingChecks += $expectedCheck
            }
        }

        if ($missingChecks.Count -gt 0) {
            Write-Warning "  ⚠️  Missing $($missingChecks.Count) health checks:"
            foreach ($missing in $missingChecks) {
                Write-Warning "     - $missing"
            }
            $serviceIssues += @{
                Type   = "MissingHealthChecks"
                Checks = $missingChecks
            }
        }
        else {
            Write-Success "  ✓ All expected health checks present"
        }

        # Display actual checks
        Write-Detail "  Actual health checks:"
        foreach ($check in $actualChecks) {
            Write-Detail "     • $check"
        }
    }
    else {
        Write-Warning "  ⚠️  Service not running - checking build configuration only"
    }

    # Check build.gradle
    $buildCheck = Test-BuildGradleExtensions -ServicePath $service.Path -RequiredExtensions $service.RequiredExtensions

    if (-not $buildCheck.Exists) {
        Write-Error "  ✗ build.gradle not found at $($service.Path)"
        $serviceIssues += @{
            Type = "MissingBuildFile"
        }
    }
    elseif ($buildCheck.MissingExtensions.Count -gt 0) {
        Write-Warning "  ⚠️  Missing $($buildCheck.MissingExtensions.Count) Quarkus extensions in build.gradle:"
        foreach ($missing in $buildCheck.MissingExtensions) {
            Write-Warning "     - $missing"
        }
        $serviceIssues += @{
            Type       = "MissingExtensions"
            Extensions = $buildCheck.MissingExtensions
            BuildPath  = $buildCheck.Path
        }

        # Fix if requested
        if ($Fix) {
            $fixed = Add-MissingExtensions -BuildGradlePath $buildCheck.Path -MissingExtensions $buildCheck.MissingExtensions
            if ($fixed) {
                $results.Fixed++
                Update-ApplicationProperties -ServicePath $service.Path | Out-Null
            }
        }
    }
    else {
        Write-Success "  ✓ All required extensions present in build.gradle"
    }

    # Summary for this service
    if ($serviceIssues.Count -eq 0) {
        Write-Success "  ✅ Service is consistent`n"
        $results.Passed++
    }
    else {
        Write-Error "  ❌ Service has $($serviceIssues.Count) issue(s)`n"
        $results.Failed++
        $results.Issues += @{
            Service = $service.Name
            Issues  = $serviceIssues
        }
    }
}

# Generate report
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Info "  Consistency Check Summary"
Write-Info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Total Services: $($results.TotalServices)" -ForegroundColor White
Write-Success "Passed: $($results.Passed)"
Write-Error "Failed: $($results.Failed)"

if ($Fix -and $results.Fixed -gt 0) {
    Write-Success "Fixed: $($results.Fixed) services"
}

Write-Host ""

if ($results.Failed -gt 0) {
    Write-Warning "⚠️  Issues found in $($results.Failed) service(s):"
    Write-Host ""

    foreach ($issue in $results.Issues) {
        Write-Host "  [$($issue.Service)]" -ForegroundColor Yellow
        foreach ($svcIssue in $issue.Issues) {
            switch ($svcIssue.Type) {
                "MissingHealthChecks" {
                    Write-Host "    • Missing health checks: $($svcIssue.Checks -join ', ')" -ForegroundColor Red
                }
                "MissingExtensions" {
                    Write-Host "    • Missing extensions: $($svcIssue.Extensions -join ', ')" -ForegroundColor Red
                }
                "MissingBuildFile" {
                    Write-Host "    • Build file not found" -ForegroundColor Red
                }
            }
        }
    }

    Write-Host ""

    if (-not $Fix) {
        Write-Info "💡 Run with -Fix flag to automatically add missing extensions:"
        Write-Host "   .\scripts\ensure-health-check-consistency.ps1 -Fix" -ForegroundColor Gray
    }
}
else {
    Write-Success "✅ All services are consistent!"
}

Write-Host ""

# Generate detailed report if requested
if ($Report) {
    $reportPath = "./docs/health-check-consistency-report.md"
    Write-Info "📄 Generating detailed report: $reportPath"

    $reportContent = @"
# Health Check Consistency Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Total Services:** $($results.TotalServices)
**Passed:** $($results.Passed)
**Failed:** $($results.Failed)

## Summary

| Service | Status | Issues |
|---------|--------|--------|
"@

    foreach ($service in $services) {
        $status = if ($results.Issues | Where-Object { $_.Service -eq $service.Name }) { "❌ Failed" } else { "✅ Passed" }
        $issueCount = ($results.Issues | Where-Object { $_.Service -eq $service.Name }).Issues.Count
        $reportContent += "`n| $($service.Name) | $status | $issueCount |"
    }

    $reportContent += @"


## Detailed Issues

"@

    foreach ($issue in $results.Issues) {
        $reportContent += @"

### $($issue.Service)

"@
        foreach ($svcIssue in $issue.Issues) {
            switch ($svcIssue.Type) {
                "MissingHealthChecks" {
                    $reportContent += "**Missing Health Checks:**`n"
                    foreach ($check in $svcIssue.Checks) {
                        $reportContent += "- $check`n"
                    }
                }
                "MissingExtensions" {
                    $reportContent += "**Missing Quarkus Extensions:**`n"
                    foreach ($ext in $svcIssue.Extensions) {
                        $reportContent += "- ``$ext```n"
                    }
                }
            }
        }
    }

    $reportContent += @"


## Next Steps

1. Run ``.\scripts\ensure-health-check-consistency.ps1 -Fix`` to automatically add missing extensions
2. Rebuild affected services: ``.\gradlew clean build``
3. Restart services: ``docker-compose restart <service-name>``
4. Verify health checks: ``.\scripts\test-health-checks.ps1``
"@

    Set-Content -Path $reportPath -Value $reportContent
    Write-Success "✓ Report saved to $reportPath"
}

# Exit code
if ($results.Failed -gt 0) {
    exit 1
}
else {
    exit 0
}
