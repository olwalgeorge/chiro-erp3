# ChiroERP Testing & Validation Guide

## Quick Start

### 1. Run Deployment Tests

```powershell
# Basic validation (without starting services)
.\scripts\test-deployment.ps1

# Full test with service startup
.\scripts\test-deployment.ps1 -StartServices

# Complete test cycle (start, test, stop)
.\scripts\test-deployment.ps1 -FullTest -StopServices
```

### 2. Start Services

```powershell
# Start all services in background
docker-compose up -d

# Start with logs visible
docker-compose up

# Start specific services only
docker-compose up -d postgresql redis keycloak
```

### 3. Monitor Resources

```powershell
# Continuous monitoring
.\scripts\monitor-resources.ps1

# Monitor for specific duration (5 minutes)
.\scripts\monitor-resources.ps1 -DurationMinutes 5

# Monitor with custom thresholds
.\scripts\monitor-resources.ps1 -CpuThresholdPercent 70 -MemoryThresholdPercent 80
```

### 4. Check Service Health

```powershell
# Test all health endpoints
1..8 | ForEach-Object {
    $port = 8079 + $_
    try {
        $response = Invoke-WebRequest "http://localhost:$port/q/health/ready" -UseBasicParsing
        Write-Host "Port $port : $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "Port $port : Not available" -ForegroundColor Red
    }
}

# Check specific service
curl http://localhost:8080/q/health/ready

# View health details
curl http://localhost:8080/q/health | ConvertFrom-Json
```

### 5. View Logs

```powershell
# View all logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# View specific service logs
docker-compose logs core-platform

# View last 100 lines
docker-compose logs --tail=100
```

### 6. Stop Services

```powershell
# Stop all services (preserves data)
docker-compose stop

# Stop and remove containers (preserves volumes)
docker-compose down

# Stop and remove everything including volumes
docker-compose down -v
```

---

## Validation Checklist

### Pre-Deployment Validation

-   [ ] Docker Compose configuration is valid
-   [ ] System has adequate resources (8+ CPUs, 8+ GB RAM)
-   [ ] All 16 services have resource limits configured
-   [ ] All 16 services have restart policies
-   [ ] Environment variables configured (copy `.env.example` to `.env`)

### Deployment Validation

-   [ ] All containers started successfully
-   [ ] No containers restarting repeatedly
-   [ ] All services responding to health checks
-   [ ] Resource usage within acceptable limits
-   [ ] No memory leaks or CPU spikes

### Health Check Validation

Each service should respond with HTTP 200:

-   [ ] core-platform (8080) - `/q/health/ready`
-   [ ] analytics-intelligence (8081) - `/q/health/ready`
-   [ ] commerce (8082) - `/q/health/ready`
-   [ ] customer-relationship (8083) - `/q/health/ready`
-   [ ] financial-management (8084) - `/q/health/ready`
-   [ ] logistics-transportation (8085) - `/q/health/ready`
-   [ ] operations-service (8086) - `/q/health/ready`
-   [ ] supply-chain-manufacturing (8087) - `/q/health/ready`

### Resource Usage Validation

-   [ ] PostgreSQL using < 2 GB memory
-   [ ] Each microservice using < 1 GB memory
-   [ ] Total memory usage < available system RAM
-   [ ] CPU usage < 80% during normal operation
-   [ ] No containers being OOM killed

---

## Common Issues & Solutions

### Issue: Services Not Starting

**Symptoms:** Containers exit immediately after starting

**Solutions:**

```powershell
# Check container logs
docker-compose logs <service-name>

# Check exit codes
docker-compose ps -a

# Verify environment variables
docker-compose config
```

### Issue: Health Checks Failing

**Symptoms:** Health endpoints return 503 or timeout

**Solutions:**

```powershell
# Wait longer (services can take 2-3 minutes to start)
Start-Sleep -Seconds 60

# Check if databases are ready
docker-compose logs postgresql

# Verify connectivity
docker-compose exec core-platform curl localhost:8080/q/health
```

### Issue: Out of Memory (OOM)

**Symptoms:** Containers being killed, exit code 137

**Solutions:**

```powershell
# Check for OOM kills
docker ps -a --filter "exited=137"

# View memory usage
docker stats --no-stream

# Reduce service count or increase limits
# Edit docker-compose.yml
```

### Issue: Port Conflicts

**Symptoms:** "port is already allocated" error

**Solutions:**

```powershell
# Find process using the port
netstat -ano | findstr :8080

# Kill the process (replace PID)
Stop-Process -Id <PID> -Force

# Or change ports in docker-compose.yml
```

### Issue: Database Connection Failures

**Symptoms:** Services can't connect to PostgreSQL

**Solutions:**

```powershell
# Check PostgreSQL is running
docker-compose ps postgresql

# Verify database initialization
docker-compose logs postgresql | Select-String "database system is ready"

# Check database credentials in .env
Get-Content .env | Select-String "POSTGRES"
```

### Issue: High CPU Usage

**Symptoms:** CPU consistently above 90%

**Solutions:**

```powershell
# Identify CPU-heavy containers
docker stats --no-stream | Sort-Object CPUPerc -Descending

# Check for infinite loops in logs
docker-compose logs <service-name> --tail=100

# Reduce concurrent services or increase limits
```

---

## Performance Testing

### Load Testing Example (using curl)

```powershell
# Simple load test (100 requests)
1..100 | ForEach-Object {
    Invoke-WebRequest "http://localhost:8080/q/health" -UseBasicParsing
}

# Concurrent load test
$jobs = 1..10 | ForEach-Object {
    Start-Job -ScriptBlock {
        1..100 | ForEach-Object {
            Invoke-WebRequest "http://localhost:8080/q/health" -UseBasicParsing
        }
    }
}
$jobs | Wait-Job | Receive-Job
```

### Monitoring During Load Test

```powershell
# Start monitoring in one terminal
.\scripts\monitor-resources.ps1 -IntervalSeconds 2

# Run load test in another terminal
# (use load test commands above)
```

---

## Docker Commands Reference

### Container Management

```powershell
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Start a stopped container
docker start <container-name>

# Stop a running container
docker stop <container-name>

# Restart a container
docker restart <container-name>

# Remove a container
docker rm <container-name>
```

### Resource Inspection

```powershell
# View real-time stats
docker stats

# Inspect container resource limits
docker inspect <container-name> | Select-String -Pattern "Memory|Cpu"

# View container processes
docker top <container-name>
```

### Log Management

```powershell
# View logs
docker logs <container-name>

# Follow logs
docker logs -f <container-name>

# View last N lines
docker logs --tail=50 <container-name>

# View logs with timestamps
docker logs -t <container-name>
```

### Cleanup

```powershell
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a
```

---

## Monitoring & Alerting Setup

### Prometheus Targets

Edit `monitoring/prometheus.yml`:

```yaml
scrape_configs:
    - job_name: "chiro-erp-services"
      static_configs:
          - targets:
                - "core-platform:8080"
                - "analytics-intelligence:8081"
            # ... add all services
```

### Grafana Dashboards

Access Grafana at http://localhost:3000

-   Default credentials: admin/admin
-   Import dashboard ID: 1860 (Node Exporter)
-   Create custom dashboards for microservices

---

## Backup & Recovery

### Backup Databases

```powershell
# Backup all databases
docker-compose exec postgresql pg_dumpall -U postgres > backup.sql

# Backup specific database
docker-compose exec postgresql pg_dump -U postgres core_db > core_db_backup.sql
```

### Restore Databases

```powershell
# Restore from backup
Get-Content backup.sql | docker-compose exec -T postgresql psql -U postgres
```

### Backup Volumes

```powershell
# Stop services
docker-compose stop

# Create volume backups
docker run --rm -v chiro-erp_postgres_data:/data -v ${PWD}:/backup alpine tar czf /backup/postgres_data.tar.gz -C /data .

# Start services
docker-compose start
```

---

## Security Checklist

### Pre-Production

-   [ ] Change all default passwords in `.env`
-   [ ] Use strong passwords (16+ characters)
-   [ ] Enable SSL/TLS for all external connections
-   [ ] Configure firewall rules
-   [ ] Set up secret rotation policies
-   [ ] Enable audit logging
-   [ ] Scan images for vulnerabilities
-   [ ] Implement network segmentation

### Production

-   [ ] Use Docker Secrets or external vault
-   [ ] Enable MFA for admin accounts
-   [ ] Set up intrusion detection
-   [ ] Configure automated backups
-   [ ] Implement disaster recovery plan
-   [ ] Set up monitoring and alerting
-   [ ] Regular security audits
-   [ ] Compliance checks (GDPR, SOC 2, etc.)

---

## Troubleshooting Decision Tree

```
Service not starting?
├─ Check logs: docker-compose logs <service>
├─ Verify dependencies: Are postgresql/redis/kafka running?
├─ Check environment variables: docker-compose config
└─ Verify resource limits: docker inspect <container>

Health check failing?
├─ Wait 2-3 minutes (services may be starting)
├─ Check database connectivity
├─ Verify application logs
└─ Test health endpoint manually: curl localhost:PORT/q/health

High resource usage?
├─ Identify heavy container: docker stats
├─ Check for memory leaks in logs
├─ Increase resource limits if legitimate load
└─ Scale horizontally if needed

Container keeps restarting?
├─ Check exit code: docker ps -a
├─ View recent logs: docker logs --tail=100 <container>
├─ Check for OOM: exit code 137
└─ Verify application configuration
```

---

## Next Steps After Testing

1. **Monitor for 24-48 hours** to establish baseline
2. **Adjust resource limits** based on actual usage
3. **Proceed to Task 4**: Logging Configuration
4. **Set up alerts** for critical metrics
5. **Document any issues** and resolutions

---

## Support & Resources

-   **Documentation**: `/docs` directory
-   **Scripts**: `/scripts` directory
-   **Logs**: `docker-compose logs`
-   **Monitoring**: http://localhost:9090 (Prometheus)
-   **Dashboards**: http://localhost:3000 (Grafana)

For issues, check:

1. Container logs
2. Resource usage
3. Health check endpoints
4. Documentation in `/docs`
