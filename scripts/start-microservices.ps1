#!/usr/bin/env pwsh

# ChiroERP Microservices Startup Script
Write-Host "Starting ChiroERP Microservices..." -ForegroundColor Green

# Create Docker network if it doesn't exist
Write-Host "Creating Docker network..." -ForegroundColor Yellow
docker network create chiro-erp-network 2>$null

# Build all services
Write-Host "Building Gradle projects..." -ForegroundColor Yellow
./gradlew clean build -x test

# Build Docker images
Write-Host "Building Docker images..." -ForegroundColor Yellow
Get-ChildItem -Path "services" -Directory | ForEach-Object {
    $serviceName = $_.Name
    Write-Host "Building $serviceName..." -ForegroundColor Cyan
    docker build -t "chiro-erp/$serviceName" -f "services/$serviceName/src/main/docker/Dockerfile.jvm" "services/$serviceName"
}

# Start infrastructure services first
Write-Host "Starting infrastructure services..." -ForegroundColor Yellow
docker-compose up -d postgresql redis kafka zookeeper minio keycloak

# Wait for infrastructure to be ready
Write-Host "Waiting for infrastructure services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Start core platform service
Write-Host "Starting core platform service..." -ForegroundColor Yellow
docker-compose up -d core-platform

# Wait for core platform to be ready
Write-Host "Waiting for core platform to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Start remaining consolidated microservices
Write-Host "Starting remaining microservices..." -ForegroundColor Yellow
docker-compose up -d administration customer-relationship operations-service commerce financial-management supply-chain-manufacturing

# Start monitoring services
Write-Host "Starting monitoring services..." -ForegroundColor Yellow
docker-compose up -d prometheus grafana

Write-Host "All services started successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Consolidated Service URLs:" -ForegroundColor Cyan
Write-Host "  Core Platform (6 domains):              http://localhost:8081" -ForegroundColor White
Write-Host "  Administration (4 domains):             http://localhost:8082" -ForegroundColor White
Write-Host "  Customer Relationship (5 domains):      http://localhost:8083" -ForegroundColor White
Write-Host "  Operations Service (4 domains):         http://localhost:8084" -ForegroundColor White
Write-Host "  Commerce (4 domains):                   http://localhost:8085" -ForegroundColor White
Write-Host "  Financial Management (6 domains):       http://localhost:8086" -ForegroundColor White
Write-Host "  Supply Chain Manufacturing (5 domains): http://localhost:8087" -ForegroundColor White
Write-Host ""
Write-Host "Infrastructure URLs:" -ForegroundColor Cyan
Write-Host "  Keycloak Admin:        http://localhost:8080/admin (admin/admin)" -ForegroundColor White
Write-Host "  MinIO Console:         http://localhost:9001 (minioadmin/minioadmin)" -ForegroundColor White
Write-Host "  Prometheus:            http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana:               http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host ""
Write-Host "Use 'docker-compose logs -f [service-name]' to view logs" -ForegroundColor Yellow
