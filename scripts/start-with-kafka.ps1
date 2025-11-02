#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Rebuild services and start them with Kafka messaging enabled
.DESCRIPTION
    This script rebuilds all services, ensures Kafka is running, and starts services in dev mode for testing
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Service = "administration",

    [Parameter(Mandatory = $false)]
    [switch]$RebuildAll = $false
)

Write-Host "🚀 Starting Microservices with Kafka" -ForegroundColor Cyan
Write-Host ""

# Step 1: Ensure Docker is running
Write-Host "Step 1: Checking Docker..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "  ✅ Docker is running" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Step 2: Check Kafka
Write-Host ""
Write-Host "Step 2: Checking Kafka..." -ForegroundColor Yellow
$kafkaRunning = docker ps --filter "name=kafka" --format "{{.Names}}" | Select-String "kafka"
if ($kafkaRunning) {
    Write-Host "  ✅ Kafka is running" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  Kafka is not running. Starting Kafka..." -ForegroundColor Yellow
    docker-compose up -d kafka
    Start-Sleep -Seconds 10
    Write-Host "  ✅ Kafka started" -ForegroundColor Green
}

# Step 3: Build services
if ($RebuildAll) {
    Write-Host ""
    Write-Host "Step 3: Rebuilding all services..." -ForegroundColor Yellow
    ./gradlew clean build
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ Build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ All services built successfully" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "Step 3: Rebuilding $Service service..." -ForegroundColor Yellow
    ./gradlew ":services:$($Service):clean" ":services:$($Service):build"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ Build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ $Service service built successfully" -ForegroundColor Green
}

# Step 4: Start service in dev mode
Write-Host ""
Write-Host "Step 4: Starting $Service service in dev mode..." -ForegroundColor Yellow
Write-Host "  📝 Service will be available at: http://localhost:808X" -ForegroundColor Cyan
Write-Host "  📝 Health check: http://localhost:808X/q/health" -ForegroundColor Cyan
Write-Host "  📝 Test Kafka: http://localhost:808X/api/test/kafka/send?message=test" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the service" -ForegroundColor Gray
Write-Host ""

./gradlew ":services:$($Service):quarkusDev"
