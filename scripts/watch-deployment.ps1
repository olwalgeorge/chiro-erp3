# Quick Deployment Monitor
# Run this while services are starting

Write-Host "🚀 ChiroERP Deployment Monitor" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Monitoring deployment progress..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

$iteration = 0
while ($true) {
    $iteration++
    Clear-Host

    Write-Host "🚀 ChiroERP Deployment Monitor - Iteration #$iteration" -ForegroundColor Cyan
    Write-Host "$(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""

    # Check container status
    try {
        $containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null

        if ($containers) {
            Write-Host "📦 Running Containers:" -ForegroundColor Green
            $containers | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        }
        else {
            Write-Host "⏳ No containers running yet... (images may be downloading)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "⚠️  Could not check container status" -ForegroundColor Yellow
    }

    Write-Host ""

    # Check images being pulled
    try {
        $pulling = docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | Select-Object -First 10
        Write-Host "📥 Available Images:" -ForegroundColor Cyan
        $pulling | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    }
    catch {
        # Ignore
    }

    Write-Host ""
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray

    Start-Sleep -Seconds 5
}
