#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick script to test Kafka endpoints in dev mode
.DESCRIPTION
    Stops the Docker container and starts the service in dev mode for testing
#>

Write-Host "🧪 Testing Kafka Endpoints - Quick Setup" -ForegroundColor Cyan
Write-Host ""

# Stop the containerized service
Write-Host "Step 1: Stopping administration container..." -ForegroundColor Yellow
docker stop chiro-erp-administration-1 2>&1 | Out-Null
Write-Host "  ✅ Container stopped" -ForegroundColor Green

# Rebuild the service
Write-Host ""
Write-Host "Step 2: Rebuilding administration service..." -ForegroundColor Yellow
./gradlew :services:administration:clean :services:administration:build --no-daemon
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Build successful" -ForegroundColor Green

# Start in dev mode
Write-Host ""
Write-Host "Step 3: Starting in dev mode..." -ForegroundColor Yellow
Write-Host ""
Write-Host "📝 Service will be available at:" -ForegroundColor Cyan
Write-Host "   Health: http://localhost:8082/q/health" -ForegroundColor White
Write-Host "   Kafka Ping: http://localhost:8082/api/test/kafka/ping" -ForegroundColor White
Write-Host "   Kafka Send: http://localhost:8082/api/test/kafka/send?message=test" -ForegroundColor White
Write-Host ""
Write-Host "💡 Open tests/api-tests.http in VS Code and click 'Send Request' above the endpoints" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Set Kafka to use localhost:9093 for dev mode (host access port)
$env:KAFKA_BOOTSTRAP_SERVERS = "localhost:9093"

./gradlew :services:administration:quarkusDev
