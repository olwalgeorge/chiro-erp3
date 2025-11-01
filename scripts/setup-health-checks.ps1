# Health Check Setup Script for ChiroERP Microservices
# This script creates health check files for all services

$services = @(
    @{ Name = "analytics-intelligence"; Database = "analytics_db"; Port = "8081" },
    @{ Name = "customer-relationship"; Database = "crm_db"; Port = "8083" },
    @{ Name = "financial-management"; Database = "finance_db"; Port = "8084" },
    @{ Name = "logistics-transportation"; Database = "logistics_db"; Port = "8085" },
    @{ Name = "operations-service"; Database = "operations_db"; Port = "8086" },
    @{ Name = "supply-chain-manufacturing"; Database = "supply_db"; Port = "8087" }
)

foreach ($service in $services) {
    $serviceName = $service.Name
    $database = $service.Database
    $port = $service.Port

    # Create package name (convert hyphens to dots)
    $packagePath = $serviceName -replace '-', '.'
    $className = ($serviceName -split '-' | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ''

    # Create health check directory
    $healthDir = "services/$serviceName/src/main/kotlin/chiro/erp/$($serviceName -replace '-', '/')/health"
    New-Item -ItemType Directory -Path $healthDir -Force | Out-Null

    Write-Host "Creating health checks for $serviceName..." -ForegroundColor Green

    # Database Health Check
    $databaseHealthCheck = @"
package chiro.erp.$($packagePath).health

import jakarta.enterprise.context.ApplicationScoped
import jakarta.inject.Inject
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Readiness
import io.vertx.mutiny.pgclient.PgPool

@Readiness
@ApplicationScoped
class DatabaseHealthCheck : HealthCheck {

    @Inject
    lateinit var pgPool: PgPool

    override fun call(): HealthCheckResponse {
        return try {
            pgPool.query("SELECT 1").execute().await().indefinitely()

            HealthCheckResponse.builder()
                .name("Database connection health check")
                .status(true)
                .withData("database", "$database")
                .withData("status", "UP")
                .build()
        } catch (e: Exception) {
            HealthCheckResponse.builder()
                .name("Database connection health check")
                .status(false)
                .withData("database", "$database")
                .withData("status", "DOWN")
                .withData("error", e.message ?: "Unknown error")
                .build()
        }
    }
}
"@

    # Liveness Health Check
    $livenessHealthCheck = @"
package chiro.erp.$($packagePath).health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {

    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.builder()
            .name("$className service liveness check")
            .status(true)
            .withData("service", "$serviceName")
            .withData("version", "1.0.0-SNAPSHOT")
            .build()
    }
}
"@

    # Write files
    Set-Content -Path "$healthDir/DatabaseHealthCheck.kt" -Value $databaseHealthCheck
    Set-Content -Path "$healthDir/LivenessCheck.kt" -Value $livenessHealthCheck

    Write-Host "✓ Created health checks for $serviceName" -ForegroundColor Cyan
}

Write-Host "`n✅ Health check files created successfully!" -ForegroundColor Green
Write-Host "Next step: Update docker-compose.yml with healthcheck configurations" -ForegroundColor Yellow
