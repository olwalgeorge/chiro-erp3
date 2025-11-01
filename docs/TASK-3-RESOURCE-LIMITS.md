# Task 3: Resource Limits & Constraints

## Overview

Configured CPU and memory limits for all containers to prevent resource exhaustion and ensure stable operation in production environments.

## Implementation Status

✅ **COMPLETED** - All services now have resource limits configured

## Resource Allocation Strategy

### Infrastructure Services

#### PostgreSQL

-   **CPU Limits**: 2.0 cores (reserved: 1.0)
-   **Memory Limits**: 2GB (reserved: 1GB)
-   **Rationale**: Database is shared across all 8 microservices, needs higher resources
-   **Restart Policy**: `unless-stopped`

#### Redis

-   **CPU Limits**: 0.5 cores (reserved: 0.25)
-   **Memory Limits**: 512MB (reserved: 256MB)
-   **Rationale**: In-memory cache, moderate resource needs
-   **Restart Policy**: `unless-stopped`

#### Kafka

-   **CPU Limits**: 1.0 core (reserved: 0.5)
-   **Memory Limits**: 1GB (reserved: 512MB)
-   **Rationale**: Message broker handling events across all services
-   **Restart Policy**: `unless-stopped`

#### Zookeeper

-   **CPU Limits**: 0.5 cores (reserved: 0.25)
-   **Memory Limits**: 512MB (reserved: 256MB)
-   **Rationale**: Coordination service for Kafka
-   **Restart Policy**: `unless-stopped`

#### MinIO

-   **CPU Limits**: 1.0 core (reserved: 0.5)
-   **Memory Limits**: 1GB (reserved: 512MB)
-   **Rationale**: Object storage for files and documents
-   **Restart Policy**: `unless-stopped`

#### Keycloak

-   **CPU Limits**: 1.0 core (reserved: 0.5)
-   **Memory Limits**: 1GB (reserved: 512MB)
-   **Rationale**: Authentication server for all microservices
-   **Restart Policy**: `unless-stopped`

### Microservices (All 8 Services)

Each microservice has identical resource allocation:

-   **CPU Limits**: 1.0 core (reserved: 0.5)
-   **Memory Limits**: 1GB (reserved: 512MB)
-   **Restart Policy**: `unless-stopped`

**Services:**

1. core-platform (8080)
2. analytics-intelligence (8081)
3. commerce (8082)
4. customer-relationship (8083)
5. financial-management (8084)
6. logistics-transportation (8085)
7. operations-service (8086)
8. supply-chain-manufacturing (8087)

### Monitoring Services

#### Prometheus

-   **CPU Limits**: 0.5 cores (reserved: 0.25)
-   **Memory Limits**: 512MB (reserved: 256MB)
-   **Rationale**: Metrics collection and storage
-   **Restart Policy**: `unless-stopped`

#### Grafana

-   **CPU Limits**: 0.5 cores (reserved: 0.25)
-   **Memory Limits**: 512MB (reserved: 256MB)
-   **Rationale**: Visualization dashboard
-   **Restart Policy**: `unless-stopped`

## Total Resource Requirements

### Minimum (Reservations)

-   **CPU**: 12.75 cores
    -   Infrastructure: 4.75 cores
    -   Microservices: 4.0 cores (8 × 0.5)
    -   Monitoring: 0.5 cores
-   **Memory**: 12GB
    -   Infrastructure: 4.75GB
    -   Microservices: 4GB (8 × 512MB)
    -   Monitoring: 512MB

### Maximum (Limits)

-   **CPU**: 17.5 cores
    -   Infrastructure: 7.5 cores
    -   Microservices: 8.0 cores (8 × 1.0)
    -   Monitoring: 1.0 core
-   **Memory**: 17GB
    -   Infrastructure: 7GB
    -   Microservices: 8GB (8 × 1GB)
    -   Monitoring: 1GB

## Restart Policies

All services use `restart: unless-stopped`:

-   **Behavior**: Automatically restart on failure
-   **Exception**: Won't restart if manually stopped
-   **Benefits**:
    -   Resilience against crashes
    -   Survives host reboots
    -   Easy manual control when needed

## Docker Compose Deploy Section

Example configuration:

```yaml
deploy:
    resources:
        limits:
            cpus: "1.0" # Maximum CPU cores
            memory: 1G # Maximum memory
        reservations:
            cpus: "0.5" # Guaranteed CPU cores
            memory: 512M # Guaranteed memory
restart: unless-stopped
```

## Monitoring Resource Usage

### Check Resource Consumption

```powershell
# View real-time stats for all containers
docker stats

# View stats for specific service
docker stats chiro-erp-core-platform-1

# View stats in JSON format
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Inspect Resource Limits

```powershell
# View resource limits for a container
docker inspect chiro-erp-core-platform-1 | Select-String -Pattern "Memory|Cpu"

# Check all running containers
docker ps --format "table {{.Names}}\t{{.Status}}"
```

## Adjusting Resource Limits

### For Production

If you need to adjust limits based on actual usage:

1. **Monitor for 24-48 hours** under typical load
2. **Identify bottlenecks** using `docker stats`
3. **Adjust limits** in `docker-compose.yml`
4. **Redeploy** with `docker-compose up -d`

### Recommended Production Adjustments

#### High-Load Services

If a service consistently hits CPU/memory limits:

```yaml
deploy:
    resources:
        limits:
            cpus: "2.0" # Increase from 1.0
            memory: 2G # Increase from 1GB
        reservations:
            cpus: "1.0" # Increase from 0.5
            memory: 1G # Increase from 512MB
```

#### Low-Load Services

If a service uses minimal resources:

```yaml
deploy:
    resources:
        limits:
            cpus: "0.5" # Decrease from 1.0
            memory: 512M # Decrease from 1GB
        reservations:
            cpus: "0.25" # Decrease from 0.5
            memory: 256M # Decrease from 512MB
```

## OOM (Out of Memory) Protection

Docker will automatically kill containers exceeding memory limits:

-   **Prevention**: Set appropriate limits with headroom
-   **Detection**: Check logs with `docker logs <container>`
-   **Recovery**: Container will auto-restart due to `unless-stopped` policy

### Check for OOM Kills

```powershell
# Check container exit codes (137 = OOM killed)
docker ps -a --filter "exited=137"

# View container logs for OOM messages
docker logs chiro-erp-core-platform-1 | Select-String -Pattern "OutOfMemory"
```

## CPU Throttling

Containers exceeding CPU limits will be throttled:

-   **Impact**: Slower response times
-   **Detection**: High CPU percentage (near 100%) in `docker stats`
-   **Resolution**: Increase CPU limits if legitimate load

## Best Practices

### 1. Leave Headroom

-   Set limits 20-30% above typical usage
-   Allows for traffic spikes and GC pauses

### 2. Monitor Continuously

-   Use Prometheus + Grafana for long-term trends
-   Set alerts for containers approaching limits

### 3. Test Under Load

```powershell
# Example: Load test a service
Invoke-WebRequest -Uri "http://localhost:8080/q/health" -Method GET
```

### 4. Adjust Based on Data

-   Don't over-provision (wastes resources)
-   Don't under-provision (causes instability)

### 5. Balance Reservations and Limits

-   Reservations guarantee minimum resources
-   Limits prevent runaway consumption
-   Gap between them allows bursting

## Scaling Considerations

### Vertical Scaling (Current Approach)

-   Increase limits per container
-   Simple but has upper bounds

### Horizontal Scaling (Future)

-   Run multiple replicas of a service
-   Better fault tolerance
-   Requires load balancer (Docker Swarm or Kubernetes)

Example for horizontal scaling:

```yaml
deploy:
    replicas: 3
    resources:
        limits:
            cpus: "1.0"
            memory: 1G
```

## Troubleshooting

### Container Keeps Restarting

```powershell
# Check why it's restarting
docker logs chiro-erp-core-platform-1 --tail 100

# Check restart count
docker inspect chiro-erp-core-platform-1 | Select-String -Pattern "RestartCount"
```

### High Memory Usage

```powershell
# Check Java heap settings in Dockerfile
# Add JVM options to limit heap:
# ENV JAVA_OPTS="-Xmx512m -Xms256m"
```

### CPU Saturation

```powershell
# Check for CPU-intensive operations
docker stats --no-stream | Sort-Object CPUPerc -Descending
```

## Integration with Task 1 (Health Checks)

Resource limits work together with health checks:

1. **Health check fails** → Container marked unhealthy
2. **Resource limit exceeded** → Container killed
3. **Restart policy** → Container automatically restarts
4. **Health check passes** → Container back in rotation

## Next Steps

After implementing resource limits, proceed with:

-   **Task 4**: Logging Configuration (centralized logging)
-   **Task 5**: Network Security (firewall, SSL/TLS)
-   **Task 6**: Backup Strategy (database, volumes)

## Validation Checklist

-   [x] All 6 infrastructure services have resource limits
-   [x] All 8 microservices have resource limits
-   [x] All 2 monitoring services have resource limits
-   [x] Restart policies configured for all services
-   [x] Documentation created
-   [ ] Test deployment with `docker-compose up -d`
-   [ ] Monitor resource usage for 24 hours
-   [ ] Adjust limits based on real-world usage

## References

-   [Docker Compose Resource Limits](https://docs.docker.com/compose/compose-file/deploy/)
-   [Docker Restart Policies](https://docs.docker.com/config/containers/start-containers-automatically/)
-   [Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/)
