cccccccccc#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick Kafka endpoint test
.DESCRIPTION
    Tests Kafka endpoints once service is running
#>

Write-Host "🧪 Testing Kafka Endpoints" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:8082"

# Test 1: Ping endpoint
Write-Host "Test 1: Kafka Ping..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/test/kafka/ping" -Method Get
    Write-Host "  ✅ Ping successful!" -ForegroundColor Green
    Write-Host "  Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
}
catch {
    Write-Host "  ❌ Ping failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Send default message
Write-Host "Test 2: Send default Kafka message..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/test/kafka/send" -Method Get
    Write-Host "  ✅ Message sent!" -ForegroundColor Green
    Write-Host "  Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
}
catch {
    Write-Host "  ❌ Send failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Send custom message
Write-Host "Test 3: Send custom Kafka message..." -ForegroundColor Yellow
try {
    $message = "Hello from PowerShell test!"
    $response = Invoke-RestMethod -Uri "$baseUrl/api/test/kafka/send?message=$([System.Uri]::EscapeDataString($message))" -Method Get
    Write-Host "  ✅ Custom message sent!" -ForegroundColor Green
    Write-Host "  Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
}
catch {
    Write-Host "  ❌ Send failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Health check
Write-Host "Test 4: Health check..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/q/health" -Method Get
    Write-Host "  ✅ Health check passed!" -ForegroundColor Green
    Write-Host "  Status: $($response.status)" -ForegroundColor Gray
    $response.checks | ForEach-Object {
        Write-Host "    - $($_.name): $($_.status)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  ❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ Testing complete!" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Tip: Check the service logs for Kafka consumer messages" -ForegroundColor Yellow
