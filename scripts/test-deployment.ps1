# ChiroERP Deployment Testing Script
# Validates health checks, resource limits, and service connectivity

param(
    [Parameter(Mandatory = $false)]
    [switch]$StartServices = $false,

    [Parameter(Mandatory = $false)]
    [switch]$StopServices = $false,

    [Parameter(Mandatory = $false)]
    [switch]$FullTest = $false
)

$ErrorActionPreference = "Continue"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  ChiroERP Deployment Test Suite" -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Test results
$testResults = @{
    ConfigValidation         = $false
    DockerAvailable          = $false
    ResourcesAvailable       = $false
    ServicesStarted          = $false
    HealthChecksPass         = $false
    ResourceLimitsConfigured = $false
}

# ===========================================
# Test 1: Docker Compose Configuration
# ===========================================
Write-Host "[Test 1/6] Validating Docker Compose Configuration..." -ForegroundColor Yellow

try {
    $configTest = docker-compose config --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Docker Compose configuration is valid" -ForegroundColor Green
        $testResults.ConfigValidation = $true
    }
    else {
        Write-Host "  ❌ Docker Compose configuration has errors:" -ForegroundColor Red
        Write-Host "     $configTest" -ForegroundColor Red
    }
}
catch {
    Write-Host "  ❌ Failed to validate configuration: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# ===========================================
# Test 2: Docker System Check
# ===========================================
Write-Host "[Test 2/6] Checking Docker System..." -ForegroundColor Yellow

try {
    $dockerVersion = docker --version
    Write-Host "  ✅ Docker is available: $dockerVersion" -ForegroundColor Green

    $dockerInfo = docker info --format "json" | ConvertFrom-Json
    $cpus = $dockerInfo.NCPU
    $memoryGB = [math]::Round($dockerInfo.MemTotal / 1GB, 2)

    Write-Host "  📊 Available Resources:" -ForegroundColor Cyan
    Write-Host "     CPUs: $cpus cores" -ForegroundColor White
    Write-Host "     Memory: $memoryGB GB" -ForegroundColor White

    # Check against requirements
    $requiredCPUs = 12.75
    $requiredMemoryGB = 12

    if ($cpus -ge $requiredCPUs -and $memoryGB -ge $requiredMemoryGB) {
        Write-Host "  ✅ System meets minimum requirements" -ForegroundColor Green
        $testResults.ResourcesAvailable = $true
    }
    else {
        Write-Host "  ⚠️  Warning: System below recommended requirements" -ForegroundColor Yellow
        Write-Host "     Recommended: $requiredCPUs CPUs, $requiredMemoryGB GB RAM" -ForegroundColor Yellow
        if ($cpus -ge 8 -and $memoryGB -ge 8) {
            Write-Host "     System can run with reduced performance" -ForegroundColor Yellow
            $testResults.ResourcesAvailable = $true
        }
        else {
            Write-Host "  ❌ Insufficient resources to run deployment" -ForegroundColor Red
        }
    }

    $testResults.DockerAvailable = $true
}
catch {
    Write-Host "  ❌ Docker is not available: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# ===========================================
# Test 3: Resource Limits Configuration
# ===========================================
Write-Host "[Test 3/6] Verifying Resource Limits Configuration..." -ForegroundColor Yellow

try {
    $composeContent = Get-Content "docker-compose.yml" -Raw

    # Count services with deploy.resources
    $servicesWithLimits = ([regex]::Matches($composeContent, "deploy:\s+resources:")).Count
    $restartPolicies = ([regex]::Matches($composeContent, "restart:\s+unless-stopped")).Count

    Write-Host "  📊 Configuration Analysis:" -ForegroundColor Cyan
    Write-Host "     Services with resource limits: $servicesWithLimits" -ForegroundColor White
    Write-Host "     Services with restart policies: $restartPolicies" -ForegroundColor White

    if ($servicesWithLimits -ge 16) {
        Write-Host "  ✅ All services have resource limits configured" -ForegroundColor Green
        $testResults.ResourceLimitsConfigured = $true
    }
    else {
        Write-Host "  ⚠️  Warning: Only $servicesWithLimits/16 services have resource limits" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ❌ Failed to verify resource limits: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# ===========================================
# Test 4: Start Services (if requested)
# ===========================================
if ($StartServices -or $FullTest) {
    Write-Host "[Test 4/6] Starting Services..." -ForegroundColor Yellow
    Write-Host "  ⏳ This may take several minutes..." -ForegroundColor Cyan

    try {
        docker-compose up -d

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Services started successfully" -ForegroundColor Green
            $testResults.ServicesStarted = $true

            # Wait for services to initialize
            Write-Host "  ⏳ Waiting 30 seconds for services to initialize..." -ForegroundColor Cyan
            Start-Sleep -Seconds 30
        }
        else {
            Write-Host "  ❌ Failed to start services" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ❌ Error starting services: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "[Test 4/6] Service Startup Check..." -ForegroundColor Yellow

    try {
        $runningContainers = docker-compose ps --services --filter "status=running" 2>$null
        $containerCount = ($runningContainers | Measure-Object).Count

        if ($containerCount -gt 0) {
            Write-Host "  ℹ️  $containerCount services are currently running" -ForegroundColor Cyan
            Write-Host "  💡 Use -StartServices flag to start all services" -ForegroundColor Gray
            $testResults.ServicesStarted = $true
        }
        else {
            Write-Host "  ℹ️  No services are currently running" -ForegroundColor Cyan
            Write-Host "  💡 Use -StartServices flag to start services" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ℹ️  Could not check running services" -ForegroundColor Cyan
    }
}

Write-Host ""

# ===========================================
# Test 5: Health Checks
# ===========================================
Write-Host "[Test 5/6] Testing Health Check Endpoints..." -ForegroundColor Yellow

$microservices = @(
    @{Name = "core-platform"; Port = 8081 }
    @{Name = "administration"; Port = 8082 }
    @{Name = "customer-relationship"; Port = 8083 }
    @{Name = "operations-service"; Port = 8084 }
    @{Name = "commerce"; Port = 8085 }
    @{Name = "financial-management"; Port = 8086 }
    @{Name = "supply-chain-manufacturing"; Port = 8087 }
)

$healthyServices = 0
$totalServices = $microservices.Count

foreach ($service in $microservices) {
    $url = "http://localhost:$($service.Port)/q/health/ready"

    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            Write-Host "  ✅ $($service.Name) is healthy (port $($service.Port))" -ForegroundColor Green
            $healthyServices++
        }
        else {
            Write-Host "  ❌ $($service.Name) returned status $($response.StatusCode)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ⚠️  $($service.Name) is not accessible (port $($service.Port))" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  📊 Health Check Summary: $healthyServices/$totalServices services healthy" -ForegroundColor Cyan

if ($healthyServices -eq $totalServices) {
    Write-Host "  ✅ All services are healthy!" -ForegroundColor Green
    $testResults.HealthChecksPass = $true
}
elseif ($healthyServices -eq 0) {
    Write-Host "  ℹ️  Services are not running or still starting up" -ForegroundColor Cyan
    Write-Host "  💡 Start services with: docker-compose up -d" -ForegroundColor Gray
}
else {
    Write-Host "  ⚠️  Some services are not healthy" -ForegroundColor Yellow
}

Write-Host ""

# ===========================================
# Test 6: Container Resource Usage
# ===========================================
Write-Host "[Test 6/6] Checking Container Resource Usage..." -ForegroundColor Yellow

try {
    $stats = docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}" 2>$null

    if ($stats) {
        Write-Host "  📊 Current Resource Usage:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  {0,-45} {1,10} {2,20}" -f "CONTAINER", "CPU %", "MEMORY" -ForegroundColor White
        Write-Host "  {0,-45} {1,10} {2,20}" -f "---------", "-----", "------" -ForegroundColor White

        foreach ($line in $stats) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line -split '\|'
            if ($parts.Count -ge 3) {
                $name = $parts[0].Trim()
                $cpu = $parts[1].Trim()
                $mem = $parts[2].Trim()

                Write-Host "  {0,-45} {1,10} {2,20}" -f $name, $cpu, $mem -ForegroundColor White
            }
        }

        Write-Host ""
        Write-Host "  ✅ Container stats retrieved successfully" -ForegroundColor Green
        Write-Host "  💡 Run .\scripts\monitor-resources.ps1 for continuous monitoring" -ForegroundColor Gray
    }
    else {
        Write-Host "  ℹ️  No containers running to check stats" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "  ⚠️  Could not retrieve container stats" -ForegroundColor Yellow
}

Write-Host ""

# ===========================================
# Stop Services (if requested)
# ===========================================
if ($StopServices) {
    Write-Host "[Cleanup] Stopping Services..." -ForegroundColor Yellow

    try {
        docker-compose down

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Services stopped successfully" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠️  Some issues occurred while stopping services" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ❌ Error stopping services: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

# ===========================================
# Test Summary
# ===========================================
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

Write-Host "Results: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })
Write-Host ""

foreach ($test in $testResults.GetEnumerator()) {
    $icon = if ($test.Value) { "✅" } else { "❌" }
    $color = if ($test.Value) { "Green" } else { "Red" }
    Write-Host "  $icon $($test.Key)" -ForegroundColor $color
}

Write-Host ""

# ===========================================
# Recommendations
# ===========================================
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Recommendations" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $testResults.ServicesStarted) {
    Write-Host "📝 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Start services: docker-compose up -d" -ForegroundColor White
    Write-Host "   2. Monitor startup: docker-compose logs -f" -ForegroundColor White
    Write-Host "   3. Check health: .\scripts\test-deployment.ps1" -ForegroundColor White
    Write-Host "   4. Monitor resources: .\scripts\monitor-resources.ps1" -ForegroundColor White
}
elseif (-not $testResults.HealthChecksPass) {
    Write-Host "📝 Services are running but not all are healthy:" -ForegroundColor Yellow
    Write-Host "   1. Check logs: docker-compose logs <service-name>" -ForegroundColor White
    Write-Host "   2. Wait longer (services may still be starting)" -ForegroundColor White
    Write-Host "   3. Check resource usage: docker stats" -ForegroundColor White
}
else {
    Write-Host "✅ All systems operational!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Monitoring Commands:" -ForegroundColor Yellow
    Write-Host "   • Resource monitoring: .\scripts\monitor-resources.ps1" -ForegroundColor White
    Write-Host "   • View logs: docker-compose logs -f" -ForegroundColor White
    Write-Host "   • Check status: docker-compose ps" -ForegroundColor White
    Write-Host "   • Stop services: docker-compose down" -ForegroundColor White
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
