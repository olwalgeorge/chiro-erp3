# Health Checks Implementation Guide

## Overview

Health checks have been implemented for all ChiroERP microservices using Quarkus SmallRye Health extension. This ensures proper container orchestration, automated recovery, and reliable service monitoring.

## Health Check Endpoints

Each microservice exposes the following health check endpoints:

| Endpoint            | Purpose                | Usage                       |
| ------------------- | ---------------------- | --------------------------- |
| `/q/health`         | Combined health status | Overall service health      |
| `/q/health/live`    | Liveness probe         | Kubernetes/Docker liveness  |
| `/q/health/ready`   | Readiness probe        | Kubernetes/Docker readiness |
| `/q/health/started` | Startup probe          | Initial startup status      |

## Service Health Check Configuration

### Core Platform (Port 8080)

```bash
curl http://localhost:8080/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (core_db)
-   ✅ Application startup status
-   ✅ Disk space availability

### Analytics Intelligence (Port 8081)

```bash
curl http://localhost:8081/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (analytics_db)
-   ✅ Service liveness

### Commerce (Port 8082)

```bash
curl http://localhost:8082/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (commerce_db)
-   ✅ Service liveness

### Customer Relationship (Port 8083)

```bash
curl http://localhost:8083/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (crm_db)
-   ✅ Service liveness

### Financial Management (Port 8084)

```bash
curl http://localhost:8084/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (finance_db)
-   ✅ Service liveness

### Logistics Transportation (Port 8085)

```bash
curl http://localhost:8085/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (logistics_db)
-   ✅ Service liveness

### Operations Service (Port 8086)

```bash
curl http://localhost:8086/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (operations_db)
-   ✅ Service liveness

### Supply Chain Manufacturing (Port 8087)

```bash
curl http://localhost:8087/q/health/ready
```

**Health Checks:**

-   ✅ Database connectivity (supply_db)
-   ✅ Service liveness

## Docker Compose Health Check Configuration

All services in `docker-compose.yml` are configured with health checks:

```yaml
healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:PORT/q/health/ready"]
    interval: 30s # Check every 30 seconds
    timeout: 10s # Fail if check takes > 10 seconds
    retries: 3 # Retry 3 times before marking unhealthy
    start_period: 60s # Grace period during startup
```

### Health Check Parameters Explained

-   **interval**: Time between running the check
-   **timeout**: Maximum time to allow check to run
-   **retries**: Number of consecutive failures needed to mark unhealthy
-   **start_period**: Grace period before health checks count towards retries

## Testing Health Checks

### Check All Services

```powershell
# PowerShell script to check all services
$services = @(
    @{ Name = "Core Platform"; Port = 8080 },
    @{ Name = "Analytics"; Port = 8081 },
    @{ Name = "Commerce"; Port = 8082 },
    @{ Name = "CRM"; Port = 8083 },
    @{ Name = "Finance"; Port = 8084 },
    @{ Name = "Logistics"; Port = 8085 },
    @{ Name = "Operations"; Port = 8086 },
    @{ Name = "Supply Chain"; Port = 8087 }
)

foreach ($service in $services) {
    Write-Host "Checking $($service.Name)..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$($service.Port)/q/health/ready" -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $($service.Name) is HEALTHY" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ $($service.Name) is UNHEALTHY" -ForegroundColor Red
    }
}
```

### View Docker Health Status

```bash
# Check health status of all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Watch health status in real-time
watch -n 2 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

## Health Check Response Format

### Healthy Response

```json
{
    "status": "UP",
    "checks": [
        {
            "name": "Database connection health check",
            "status": "UP",
            "data": {
                "database": "commerce_db",
                "status": "UP"
            }
        },
        {
            "name": "Commerce service liveness check",
            "status": "UP",
            "data": {
                "service": "commerce",
                "version": "1.0.0-SNAPSHOT"
            }
        }
    ]
}
```

### Unhealthy Response

```json
{
    "status": "DOWN",
    "checks": [
        {
            "name": "Database connection health check",
            "status": "DOWN",
            "data": {
                "database": "commerce_db",
                "status": "DOWN",
                "error": "Connection refused"
            }
        }
    ]
}
```

## Kubernetes Health Probes (Future)

When deploying to Kubernetes, use these probe configurations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
    name: commerce-service
spec:
    template:
        spec:
            containers:
                - name: commerce
                  image: chiro-erp/commerce:1.0.0
                  livenessProbe:
                      httpGet:
                          path: /q/health/live
                          port: 8082
                      initialDelaySeconds: 30
                      periodSeconds: 10
                      timeoutSeconds: 5
                      failureThreshold: 3

                  readinessProbe:
                      httpGet:
                          path: /q/health/ready
                          port: 8082
                      initialDelaySeconds: 10
                      periodSeconds: 5
                      timeoutSeconds: 3
                      failureThreshold: 3

                  startupProbe:
                      httpGet:
                          path: /q/health/started
                          port: 8082
                      initialDelaySeconds: 0
                      periodSeconds: 10
                      timeoutSeconds: 3
                      failureThreshold: 30
```

## Custom Health Checks

### Adding Custom Health Checks

You can add custom health checks for specific dependencies:

```kotlin
package chiro.erp.commerce.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Readiness

@Readiness
@ApplicationScoped
class KafkaHealthCheck : HealthCheck {

    override fun call(): HealthCheckResponse {
        // Check Kafka connectivity
        val isKafkaHealthy = checkKafkaConnection()

        return HealthCheckResponse.builder()
            .name("Kafka connectivity check")
            .status(isKafkaHealthy)
            .withData("broker", "kafka:9092")
            .build()
    }

    private fun checkKafkaConnection(): Boolean {
        // Implementation to check Kafka
        return true
    }
}
```

## Monitoring and Alerting

### Prometheus Integration

Health check metrics are exposed via Prometheus:

```yaml
# prometheus.yml
scrape_configs:
    - job_name: "chiro-erp-health"
      scrape_interval: 30s
      metrics_path: "/q/metrics"
      static_configs:
          - targets:
                - "core-platform:8080"
                - "commerce:8082"
                - "crm:8083"
                - "finance:8084"
```

### Grafana Dashboard

Create a dashboard to visualize health status:

-   Service availability over time
-   Health check failure rate
-   Response time of health endpoints
-   Alert on consecutive failures

## Troubleshooting

### Service Marked as Unhealthy

1. **Check logs:**

    ```bash
    docker logs chiro-erp-commerce-1
    ```

2. **Manual health check:**

    ```bash
    curl -v http://localhost:8082/q/health
    ```

3. **Check dependencies:**

    - Database connectivity
    - Kafka availability
    - Network connectivity

4. **Restart service:**
    ```bash
    docker-compose restart commerce
    ```

### Health Check Timeout

If health checks are timing out:

1. **Increase timeout:**

    ```yaml
    healthcheck:
        timeout: 20s # Increase from 10s
    ```

2. **Check resource constraints:**

    - CPU throttling
    - Memory limits
    - Disk I/O

3. **Optimize health check logic:**
    - Simplify database queries
    - Add caching
    - Reduce external dependencies

### False Positives During Startup

If services are marked unhealthy during startup:

1. **Increase start_period:**

    ```yaml
    healthcheck:
        start_period: 120s # Increase from 60s
    ```

2. **Use startup probe (Kubernetes):**
    - Separate startup checks from liveness
    - Higher failure threshold during startup

## Best Practices

1. ✅ **Keep health checks lightweight** - Should complete in < 1 second
2. ✅ **Check critical dependencies only** - Database, cache, message broker
3. ✅ **Use appropriate probe types** - Liveness vs. Readiness vs. Startup
4. ✅ **Set realistic timeouts** - Balance between responsiveness and false positives
5. ✅ **Monitor health check metrics** - Track failure patterns
6. ✅ **Test health checks** - Verify they work correctly in all scenarios
7. ✅ **Document dependencies** - Clear understanding of what's being checked

## Next Steps

-   [ ] Add Redis connectivity checks
-   [ ] Add Kafka connectivity checks
-   [ ] Implement custom health checks for external APIs
-   [ ] Set up health check monitoring dashboard
-   [ ] Configure alerting for health check failures
-   [ ] Add health check integration tests

## References

-   [Quarkus SmallRye Health Guide](https://quarkus.io/guides/smallrye-health)
-   [Docker Compose Healthcheck Reference](https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck)
-   [Kubernetes Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
-   [MicroProfile Health Specification](https://github.com/eclipse/microprofile-health)
