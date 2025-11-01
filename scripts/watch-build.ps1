# ChiroERP Build Progress Monitor
# Monitors Docker build and container startup progress

param(
    [Parameter(Mandatory = $false)]
    [int]$RefreshSeconds = 5
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  ChiroERP Build & Deployment Monitor" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

while ($true) {
    Clear-Host

    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  ChiroERP Build & Deployment Monitor" -ForegroundColor Cyan
    Write-Host "  Elapsed Time: $([math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)) minutes" -ForegroundColor Cyan
    Write-Host "  Updated: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""

    # Check Docker images
    Write-Host "📦 Docker Images Built:" -ForegroundColor Yellow
    $images = docker images --filter "reference=chiro-erp-*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | Out-String
    if ($images.Trim()) {
        Write-Host $images -ForegroundColor White
    }
    else {
        Write-Host "  No images built yet..." -ForegroundColor Gray
    }
    Write-Host ""

    # Check running containers
    Write-Host "🚀 Running Containers:" -ForegroundColor Yellow
    $containers = docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>$null
    if ($containers) {
        Write-Host $containers -ForegroundColor White
    }
    else {
        Write-Host "  No containers running yet..." -ForegroundColor Gray
    }
    Write-Host ""

    # Check container count
    $runningCount = (docker-compose ps -q 2>$null | Measure-Object).Count
    $totalExpected = 16

    Write-Host "📊 Progress: $runningCount / $totalExpected services" -ForegroundColor Cyan

    if ($runningCount -gt 0) {
        $percentage = [math]::Round(($runningCount / $totalExpected) * 100, 0)
        $barLength = 50
        $filled = [math]::Round(($percentage / 100) * $barLength)
        $bar = ("█" * $filled) + ("░" * ($barLength - $filled))
        Write-Host "  [$bar] $percentage%" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
    Write-Host "Next refresh in $RefreshSeconds seconds..." -ForegroundColor Gray

    # Check if all services are up
    if ($runningCount -eq $totalExpected) {
        Write-Host ""
        Write-Host "✅ All services are running!" -ForegroundColor Green
        Write-Host "Run .\scripts\test-deployment.ps1 to verify health checks" -ForegroundColor Yellow
        break
    }

    Start-Sleep -Seconds $RefreshSeconds
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Monitoring Complete" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
