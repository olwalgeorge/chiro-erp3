#!/usr/bin/env pwsh
# Quick Kafka Test Script - Run this in a NEW terminal while service is running

Write-Host "🧪 Testing Administration Service" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:8082"

# Test 1: Health Check
Write-Host "Test 1: Health Check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/q/health" -Method Get -TimeoutSec 5
    Write-Host "  ✅ Service is healthy!" -ForegroundColor Green
    Write-Host "  Status: $($health.status)" -ForegroundColor Gray
}
catch {
    Write-Host "  ❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Kafka Ping
Write-Host "Test 2: Kafka Connectivity..." -ForegroundColor Yellow
try {
    $ping = Invoke-RestMethod -Uri "$baseUrl/api/test/kafka/ping" -Method Get -TimeoutSec 5
    Write-Host "  ✅ Kafka is connected!" -ForegroundColor Green
    Write-Host "  $($ping | ConvertTo-Json -Compress)" -ForegroundColor Gray
}
catch {
    Write-Host "  ❌ Kafka ping failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Send Message
Write-Host "Test 3: Send Test Message..." -ForegroundColor Yellow
try {
    $message = "Hello from PowerShell - " + (Get-Date -Format "HH:mm:ss")
    $encoded = [System.Uri]::EscapeDataString($message)
    $send = Invoke-RestMethod -Uri "$baseUrl/api/test/kafka/send?message=$encoded" -Method Get -TimeoutSec 5
    Write-Host "  ✅ Message sent successfully!" -ForegroundColor Green
    Write-Host "  Event ID: $($send.eventId)" -ForegroundColor Gray
    Write-Host "  Message: $($send.message)" -ForegroundColor Gray
}
catch {
    Write-Host "  ❌ Send failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "✨ All tests completed!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Check the service terminal to see the consumer logs" -ForegroundColor Yellow
