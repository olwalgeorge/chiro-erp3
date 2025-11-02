#!/usr/bin/env pwsh

# Kafka Messaging Test Script
# Tests event publishing and consumption across microservices

param(
    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails = $false
)

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  🧪 Kafka Messaging Test Suite" -ForegroundColor Cyan
Write-Host "  ChiroERP Microservices" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Test configuration
$services = @(
    @{Name = "core-platform"; Port = 8081; FriendlyName = "Core Platform" },
    @{Name = "administration"; Port = 8082; FriendlyName = "Administration" },
    @{Name = "customer-relationship"; Port = 8083; FriendlyName = "Customer Relationship" },
    @{Name = "operations-service"; Port = 8084; FriendlyName = "Operations Service" },
    @{Name = "commerce"; Port = 8085; FriendlyName = "Commerce" },
    @{Name = "financial-management"; Port = 8086; FriendlyName = "Financial Management" },
    @{Name = "supply-chain-manufacturing"; Port = 8087; FriendlyName = "Supply Chain Manufacturing" }
)

$testsPassed = 0
$testsFailed = 0
$testsSkipped = 0

# Test 1: Check Kafka is running
Write-Host "Test 1/4: Checking Kafka Infrastructure..." -ForegroundColor Yellow
try {
    $kafkaRunning = docker ps --filter "name=kafka" --format "{{.Names}}" 2>$null
    if ($kafkaRunning) {
        Write-Host "  ✅ Kafka container is running" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "  ❌ Kafka container is not running" -ForegroundColor Red
        Write-Host "     Run: docker-compose up -d kafka" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "  ⚠️  Could not check Kafka status (Docker not available?)" -ForegroundColor Yellow
    $testsSkipped++
}

Write-Host ""

# Test 2: Check service health
Write-Host "Test 2/4: Checking Service Health Endpoints..." -ForegroundColor Yellow
$healthyServices = @()
$unhealthyServices = @()

foreach ($service in $services) {
    $url = "http://localhost:$($service.Port)/q/health"

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "  ✅ $($service.FriendlyName) is healthy (port $($service.Port))" -ForegroundColor Green
            $healthyServices += $service
            $testsPassed++
        }
        else {
            Write-Host "  ❌ $($service.FriendlyName) returned status: $($response.StatusCode)" -ForegroundColor Red
            $unhealthyServices += $service
            $testsFailed++
        }
    }
    catch {
        Write-Host "  ⚠️  $($service.FriendlyName) is not responding (not started)" -ForegroundColor Yellow
        $unhealthyServices += $service
        $testsSkipped++
    }
}

Write-Host ""
Write-Host "  📊 Health Summary: $($healthyServices.Count)/$($services.Count) services healthy" -ForegroundColor Cyan

if ($healthyServices.Count -eq 0) {
    Write-Host ""
    Write-Host "  ⚠️  No services are running. Cannot test messaging." -ForegroundColor Yellow
    Write-Host "  💡 Start services with: ./gradlew :services:{service}:quarkusDev" -ForegroundColor Cyan
    exit 1
}

Write-Host ""

# Test 3: Publish test events
Write-Host "Test 3/4: Publishing Test Events..." -ForegroundColor Yellow
$publishResults = @()

foreach ($service in $healthyServices) {
    $url = "http://localhost:$($service.Port)/api/test/publish-event"
    $body = @{
        message = "Automated test from $($service.FriendlyName)"
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod `
            -Uri $url `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec 3 `
            -ErrorAction Stop

        if ($response.status -eq "Event published successfully") {
            Write-Host "  ✅ $($service.FriendlyName) published event successfully" -ForegroundColor Green
            if ($ShowDetails) {
                Write-Host "     Event Type: $($response.eventType)" -ForegroundColor Gray
                Write-Host "     Service: $($response.service)" -ForegroundColor Gray
            }
            $publishResults += @{Service = $service; Success = $true }
            $testsPassed++
        }
        else {
            Write-Host "  ❌ $($service.FriendlyName) failed: Unexpected response" -ForegroundColor Red
            $publishResults += @{Service = $service; Success = $false }
            $testsFailed++
        }
    }
    catch {
        Write-Host "  ❌ $($service.FriendlyName) failed: $($_.Exception.Message)" -ForegroundColor Red
        if ($ShowDetails) {
            Write-Host "     Error Details: $_" -ForegroundColor Gray
        }
        $publishResults += @{Service = $service; Success = $false }
        $testsFailed++
    }

    Start-Sleep -Milliseconds 500
}

Write-Host ""

# Test 4: Verify Kafka topics
Write-Host "Test 4/4: Verifying Kafka Topics..." -ForegroundColor Yellow
try {
    $topics = docker exec chiro-erp-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>$null
    if ($topics) {
        $topicCount = ($topics | Measure-Object -Line).Lines
        Write-Host "  ✅ Found $topicCount Kafka topics" -ForegroundColor Green

        if ($ShowDetails) {
            Write-Host "     Topics:" -ForegroundColor Gray
            $topics | ForEach-Object { Write-Host "       - $_" -ForegroundColor Gray }
        }        # Check if expected topics exist
        $expectedTopics = @(
            "administration-events",
            "commerce-events",
            "core-platform-events",
            "customer-relationship-events",
            "financial-management-events",
            "operations-service-events",
            "shared-events",
            "supply-chain-manufacturing-events"
        )

        $missingTopics = @()
        foreach ($expectedTopic in $expectedTopics) {
            if ($topics -notcontains $expectedTopic) {
                $missingTopics += $expectedTopic
            }
        }

        if ($missingTopics.Count -eq 0) {
            Write-Host "  ✅ All expected topics exist" -ForegroundColor Green
            $testsPassed++
        }
        else {
            Write-Host "  ⚠️  Missing topics: $($missingTopics -join ', ')" -ForegroundColor Yellow
            Write-Host "     Topics are auto-created on first message" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  ❌ Could not list Kafka topics" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "  ❌ Failed to check Kafka topics: $($_.Exception.Message)" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

$totalTests = $testsPassed + $testsFailed + $testsSkipped
$passRate = if ($totalTests -gt 0) { [math]::Round(($testsPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host "  Total Tests: $totalTests" -ForegroundColor White
Write-Host "  ✅ Passed: $testsPassed" -ForegroundColor Green
Write-Host "  ❌ Failed: $testsFailed" -ForegroundColor Red
Write-Host "  ⚠️  Skipped: $testsSkipped" -ForegroundColor Yellow
Write-Host "  📈 Pass Rate: $passRate%" -ForegroundColor Cyan
Write-Host ""

if ($testsFailed -eq 0 -and $testsPassed -gt 0) {
    Write-Host "  🎉 All tests passed! Messaging is working correctly." -ForegroundColor Green
}
elseif ($testsFailed -gt 0) {
    Write-Host "  ⚠️  Some tests failed. Check the output above for details." -ForegroundColor Yellow
}
else {
    Write-Host "  ℹ️  No tests could be completed. Check service status." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  💡 Quick Actions" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

if ($unhealthyServices.Count -gt 0) {
    Write-Host "Start missing services:" -ForegroundColor Yellow
    foreach ($service in $unhealthyServices) {
        Write-Host "  ./gradlew :services:$($service.Name):quarkusDev" -ForegroundColor White
    }
    Write-Host ""
}

Write-Host "Monitor Kafka messages:" -ForegroundColor Yellow
Write-Host '  docker exec -it chiro-erp-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic shared-events --from-beginning' -ForegroundColor White
Write-Host ""

Write-Host "Manual test:" -ForegroundColor Yellow
Write-Host '  curl -X POST http://localhost:8082/api/test/publish-event -H "Content-Type: application/json" -d ''{"message":"manual test"}''' -ForegroundColor White
Write-Host ""

Write-Host "View logs:" -ForegroundColor Yellow
Write-Host "  docker-compose logs -f kafka" -ForegroundColor White
Write-Host ""

Write-Host "Full documentation:" -ForegroundColor Yellow
Write-Host "  docs/KAFKA-TESTING-GUIDE.md" -ForegroundColor White
Write-Host ""

# Exit with appropriate code
if ($testsFailed -gt 0) {
    exit 1
}
else {
    exit 0
}
