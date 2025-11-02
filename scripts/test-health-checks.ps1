# Test Health Checks for All ChiroERP Microservices
# Run this script after starting docker-compose to verify all health endpoints

Write-Host "`n=== ChiroERP Health Check Validator ===" -ForegroundColor Cyan
Write-Host "Testing health endpoints for all microservices...`n" -ForegroundColor White

$services = @(
    @{ Name = "Core Platform"; Port = 8081; Service = "core-platform"; Domains = "security, organization, audit, configuration, notification, integration" },
    @{ Name = "Administration"; Port = 8082; Service = "administration"; Domains = "hr, logistics-transportation, analytics-intelligence, project-management" },
    @{ Name = "Customer Relationship"; Port = 8083; Service = "customer-relationship"; Domains = "crm, client, provider, subscription, promotion" },
    @{ Name = "Operations Service"; Port = 8084; Service = "operations-service"; Domains = "field-service, scheduling, records, repair-rma" },
    @{ Name = "Commerce"; Port = 8085; Service = "commerce"; Domains = "ecommerce, portal, communication, pos" },
    @{ Name = "Financial Management"; Port = 8086; Service = "financial-management"; Domains = "general-ledger, accounts-payable, accounts-receivable, asset-accounting, tax-engine, expense-management" },
    @{ Name = "Supply Chain Manufacturing"; Port = 8087; Service = "supply-chain-manufacturing"; Domains = "production, quality, inventory, product-costing, procurement" }
)

$results = @{
    Healthy     = 0
    Unhealthy   = 0
    Unreachable = 0
}

foreach ($service in $services) {
    Write-Host "[$($service.Service)]" -NoNewline -ForegroundColor Yellow
    Write-Host " Checking health on port $($service.Port)..." -NoNewline

    try {
        # Test readiness endpoint
        $response = Invoke-WebRequest -Uri "http://localhost:$($service.Port)/q/health/ready" `
            -UseBasicParsing `
            -TimeoutSec 5 `
            -ErrorAction Stop

        if ($response.StatusCode -eq 200) {
            $content = $response.Content | ConvertFrom-Json

            if ($content.status -eq "UP") {
                Write-Host " ✓ HEALTHY" -ForegroundColor Green
                $results.Healthy++

                # Display check details
                foreach ($check in $content.checks) {
                    Write-Host "  └─ $($check.name): $($check.status)" -ForegroundColor Gray
                }
            }
            else {
                Write-Host " ⚠ UNHEALTHY" -ForegroundColor Yellow
                $results.Unhealthy++
                Write-Host "  Response: $($content.status)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host " ✗ UNREACHABLE" -ForegroundColor Red
        $results.Unreachable++
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
}

# Summary
Write-Host "`n=== Health Check Summary ===" -ForegroundColor Cyan
Write-Host "✓ Healthy:     $($results.Healthy)" -ForegroundColor Green
Write-Host "⚠ Unhealthy:   $($results.Unhealthy)" -ForegroundColor Yellow
Write-Host "✗ Unreachable: $($results.Unreachable)" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "Total Services: $($services.Count)" -ForegroundColor White

# Check Docker container status
Write-Host "`n=== Docker Container Status ===" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}" | Select-String "chiro-erp"

# Return exit code based on results
if ($results.Healthy -eq $services.Count) {
    Write-Host "`n✅ All services are healthy!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n⚠️  Some services are not healthy. Check logs for details." -ForegroundColor Yellow
    Write-Host "   Run 'docker-compose logs <service-name>' for more information." -ForegroundColor Gray
    exit 1
}
