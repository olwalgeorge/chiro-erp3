# ChiroERP Deployment Checklist

## Pre-Deployment Checks

### System Requirements

-   [ ] Docker 20.10+ installed
-   [ ] Docker Compose 2.0+ installed
-   [ ] 12+ GB RAM available
-   [ ] 12.75+ CPU cores available
-   [ ] 50+ GB disk space available
-   [ ] PowerShell 5.1+ or PowerShell Core 7+

### Environment Setup

-   [ ] Git repository cloned
-   [ ] Navigate to project root: `cd chiro-erp`
-   [ ] Verify settings.gradle contains all 7 services
-   [ ] Ports 8081-8087 are available
-   [ ] Ports 5432, 6379, 9092, 9000, 8180, 9090, 3000 are available

## Step 1: Create Service Structure

```powershell
# Run the structure creation script
.\scripts\create-complete-structure.ps1
```

### Verification

-   [ ] All 7 service directories created under `services/`
-   [ ] Each service has hexagonal architecture structure
-   [ ] Application main classes generated
-   [ ] build.gradle files created for each service
-   [ ] application.properties files created
-   [ ] Shared utility directories created

### Expected Output

```
✅ Created security domain structure in core-platform service
✅ Created organization domain structure in core-platform service
... (36 domains total)
✅ Created Application class, build.gradle, and application.properties for core-platform
... (7 services total)
🎉 Complete consolidated services structure created!
```

## Step 2: Build Services

```powershell
# Build all services (skip tests for initial deployment)
.\gradlew clean build -x test
```

### Verification

-   [ ] All 7 services build successfully
-   [ ] No compilation errors
-   [ ] Build artifacts created in `build/quarkus-app/`

### Expected Output

```
BUILD SUCCESSFUL in Xs
7 actionable tasks: 7 executed
```

## Step 3: Validate Docker Compose

```powershell
# Validate docker-compose configuration
docker-compose config
```

### Verification

-   [ ] No YAML syntax errors
-   [ ] All 7 services defined
-   [ ] All infrastructure services defined
-   [ ] Network configuration valid
-   [ ] Volume definitions correct

## Step 4: Start Infrastructure Services

```powershell
# Start only infrastructure services first
docker-compose up -d postgresql redis kafka minio keycloak
```

### Verification

-   [ ] PostgreSQL container running
-   [ ] Redis container running
-   [ ] Kafka container running
-   [ ] MinIO container running
-   [ ] Keycloak container running

### Health Checks

```powershell
# Check container status
docker ps

# Check PostgreSQL
docker exec -it chiro-erp-postgresql-1 psql -U postgres -c "SELECT version();"

# Check Redis
docker exec -it chiro-erp-redis-1 redis-cli ping

# Wait 30 seconds for services to initialize
Start-Sleep -Seconds 30
```

## Step 5: Initialize Database

```powershell
# Database should be auto-initialized via init script
# Verify schemas were created
docker exec -it chiro-erp-postgresql-1 psql -U postgres -d chiro_erp -c "\dn"
```

### Verification

-   [ ] chiro_erp database exists
-   [ ] keycloak database exists
-   [ ] 7 schemas created (core_schema, administration_schema, etc.)
-   [ ] 7 users created with proper permissions

### Expected Schemas

```
                List of schemas
            Name             |        Owner
-----------------------------+---------------------
 administration_schema       | administration_user
 commerce_schema             | commerce_user
 core_schema                 | core_user
 customerrelationship_schema | customerrelationship_user
 financialmanagement_schema  | financialmanagement_user
 operationsservice_schema    | operationsservice_user
 supplychainmanufacturing_schema | supplychainmanufacturing_user
```

## Step 6: Start Core Platform

```powershell
# Start core platform first
docker-compose up -d core-platform

# Wait for core platform to be ready
Start-Sleep -Seconds 20
```

### Verification

-   [ ] Container running: `docker ps | Select-String "core-platform"`
-   [ ] Health check passing: `curl http://localhost:8081/q/health/ready`
-   [ ] No errors in logs: `docker-compose logs core-platform`

### Expected Health Response

```json
{
    "status": "UP",
    "checks": [
        {
            "name": "SmallRye Health Check",
            "status": "UP"
        }
    ]
}
```

## Step 7: Start Remaining Services

```powershell
# Start all remaining microservices
docker-compose up -d administration customer-relationship operations-service commerce financial-management supply-chain-manufacturing

# Wait for services to start
Start-Sleep -Seconds 30
```

### Verification

-   [ ] All 7 service containers running
-   [ ] No restart loops: `docker ps`
-   [ ] All services show "Up" status

## Step 8: Start Monitoring

```powershell
# Start monitoring stack
docker-compose up -d prometheus grafana
```

### Verification

-   [ ] Prometheus accessible at http://localhost:9090
-   [ ] Grafana accessible at http://localhost:3000
-   [ ] Prometheus targets show all services

## Step 9: Health Check Validation

```powershell
# Run automated health checks
.\scripts\test-health-checks.ps1
```

### Expected Results

-   [ ] ✓ Core Platform (8081): HEALTHY
-   [ ] ✓ Administration (8082): HEALTHY
-   [ ] ✓ Customer Relationship (8083): HEALTHY
-   [ ] ✓ Operations Service (8084): HEALTHY
-   [ ] ✓ Commerce (8085): HEALTHY
-   [ ] ✓ Financial Management (8086): HEALTHY
-   [ ] ✓ Supply Chain Manufacturing (8087): HEALTHY
-   [ ] **Summary: 7/7 services healthy**

## Step 10: Comprehensive Testing

```powershell
# Run full deployment test suite
.\scripts\test-deployment.ps1 -FullTest
```

### Verification

-   [ ] Config validation: PASS
-   [ ] Docker system check: PASS
-   [ ] Services started: PASS
-   [ ] Health checks: PASS (7/7)
-   [ ] Resource limits configured: PASS

## Step 11: Access Verification

### Microservices

-   [ ] Core Platform: http://localhost:8081/q/health
-   [ ] Administration: http://localhost:8082/q/health
-   [ ] Customer Relationship: http://localhost:8083/q/health
-   [ ] Operations Service: http://localhost:8084/q/health
-   [ ] Commerce: http://localhost:8085/q/health
-   [ ] Financial Management: http://localhost:8086/q/health
-   [ ] Supply Chain Mfg: http://localhost:8087/q/health

### Infrastructure

-   [ ] Keycloak Admin: http://localhost:8180/admin (admin/admin)
-   [ ] MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
-   [ ] Grafana: http://localhost:3000 (admin/admin)
-   [ ] Prometheus: http://localhost:9090

### Dev Tools (each service)

-   [ ] Swagger UI: http://localhost:{port}/q/swagger-ui
-   [ ] Dev UI: http://localhost:{port}/q/dev
-   [ ] Health UI: http://localhost:{port}/q/health-ui

## Step 12: Log Verification

```powershell
# Check for errors in logs
docker-compose logs --tail=100 core-platform
docker-compose logs --tail=100 administration
docker-compose logs --tail=100 customer-relationship
docker-compose logs --tail=100 operations-service
docker-compose logs --tail=100 commerce
docker-compose logs --tail=100 financial-management
docker-compose logs --tail=100 supply-chain-manufacturing
```

### Look For

-   [ ] No stack traces or exceptions
-   [ ] Successful database connections
-   [ ] Successful Kafka connections
-   [ ] Successful Redis connections
-   [ ] Application startup completed

## Step 13: Resource Monitoring

```powershell
# Check resource usage
docker stats --no-stream
```

### Verification

-   [ ] No services exceeding memory limits
-   [ ] CPU usage stable
-   [ ] No restart counts

## Troubleshooting

### Service Won't Start

```powershell
# Check logs
docker-compose logs [service-name]

# Restart service
docker-compose restart [service-name]

# Rebuild if needed
docker-compose build [service-name]
docker-compose up -d [service-name]
```

### Database Connection Issues

```powershell
# Check PostgreSQL logs
docker-compose logs postgresql

# Connect to database
docker exec -it chiro-erp-postgresql-1 psql -U postgres -d chiro_erp

# Check schemas
\dn

# Check permissions
\du
```

### Port Conflicts

```powershell
# Find what's using a port (Windows)
netstat -ano | findstr :{port}

# Kill process
taskkill /PID {pid} /F
```

### Out of Memory

```powershell
# Increase Docker memory limit in Docker Desktop settings
# Or reduce service memory limits in docker-compose.yml
```

## Post-Deployment Tasks

### Optional: Configure Keycloak

-   [ ] Access Keycloak admin console
-   [ ] Create chiro-erp realm (if not exists)
-   [ ] Configure clients for each service
-   [ ] Set up users and roles

### Optional: Configure Grafana

-   [ ] Login to Grafana
-   [ ] Add Prometheus data source
-   [ ] Import dashboards for microservices
-   [ ] Set up alerts

### Optional: Load Test Data

-   [ ] Create sample organizations
-   [ ] Create sample users
-   [ ] Create sample products
-   [ ] Create sample transactions

## Automated Deployment (All Steps)

```powershell
# Complete automated deployment
.\scripts\create-complete-structure.ps1
.\gradlew clean build -x test
.\scripts\start-microservices.ps1
Start-Sleep -Seconds 60
.\scripts\test-health-checks.ps1
```

## Shutdown Procedures

### Graceful Shutdown

```powershell
# Stop services gracefully
docker-compose down
```

### Complete Cleanup (Including Data)

```powershell
# Stop and remove volumes
docker-compose down -v

# Remove networks
docker network rm chiro-erp-network
```

### Rebuild from Scratch

```powershell
# Complete teardown
docker-compose down -v
docker system prune -f

# Rebuild
.\gradlew clean build -x test
.\scripts\start-microservices.ps1
```

## Success Criteria

✅ All infrastructure services running
✅ All 7 microservices running
✅ All health checks passing
✅ No errors in logs
✅ Services accessible on assigned ports
✅ Database schemas created
✅ Monitoring stack operational
✅ Resource usage within limits

## Deployment Time Estimate

-   **Initial Setup:** 5 minutes
-   **Structure Creation:** 2 minutes
-   **Build Services:** 5-10 minutes
-   **Start Infrastructure:** 2-3 minutes
-   **Start Services:** 3-5 minutes
-   **Validation:** 2-3 minutes

**Total Estimated Time:** 20-30 minutes for first deployment

## Notes

-   Wait times are important for service initialization
-   Core Platform must start before other services
-   Infrastructure must be healthy before starting services
-   Health checks may take 30-60 seconds to pass
-   First build takes longer due to dependency downloads
-   Subsequent deployments are much faster

## Support

If issues persist:

1. Check logs: `docker-compose logs [service-name]`
2. Review documentation: `docs/CONSOLIDATED-DEPLOYMENT-GUIDE.md`
3. See quick reference: `docs/QUICK-REFERENCE.md`
4. Check troubleshooting: `docs/QUICK-REFERENCE.md#troubleshooting`

## Deployment Complete! 🎉

Your ChiroERP consolidated services are now running!

Next steps:

-   Explore Swagger UIs for each service
-   Configure Keycloak realms and clients
-   Set up Grafana dashboards
-   Begin domain model migration
-   Start implementing use cases
