# Kafka Port Configuration

## Issue Summary

**Problem**: Services running outside Docker (dev mode) couldn't connect to Kafka
**Root Cause**: Incorrect port configuration for host-to-Docker communication

## Docker Kafka Port Configuration

Kafka in Docker Compose is configured with **two listener ports**:

### Port 9092 (Internal - Container Network)

-   **Purpose**: Container-to-container communication
-   **Listener**: `PLAINTEXT://kafka:9092`
-   **Used by**: Services running inside Docker containers
-   **Hostname**: `kafka` (Docker internal DNS)

### Port 9093 (External - Host Access)

-   **Purpose**: Host-to-container communication
-   **Listener**: `PLAINTEXT_HOST://localhost:9093`
-   **Used by**: Services running on the host machine (dev mode, IDE, local testing)
-   **Hostname**: `localhost`

## Configuration Updates

### 1. Application Properties

**File**: `services/*/src/main/resources/application.properties`

```properties
# Default uses 9093 for local development
kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS:localhost:9093}
```

**Explanation**:

-   Default value is `localhost:9093` (for dev mode)
-   Can be overridden with `KAFKA_BOOTSTRAP_SERVERS` environment variable
-   Docker Compose sets it to `kafka:9092` for containerized services

### 2. Test Scripts

**File**: `scripts/test-kafka-endpoints.ps1`

```powershell
# Set Kafka to use localhost:9093 for dev mode (host access port)
$env:KAFKA_BOOTSTRAP_SERVERS = "localhost:9093"
```

## Environment-Specific Configuration

### Local Development (dev mode)

```bash
export KAFKA_BOOTSTRAP_SERVERS=localhost:9093
./gradlew :services:administration:quarkusDev
```

### Docker Compose (containerized)

```yaml
# Docker Compose automatically sets:
environment:
    KAFKA_BOOTSTRAP_SERVERS: kafka:9092
```

### Production Deployment

```bash
# Set to your production Kafka cluster
export KAFKA_BOOTSTRAP_SERVERS=kafka-cluster.example.com:9092
```

## Verification

### Check Kafka Connectivity

```bash
# From host machine (should use 9093)
kafka-console-consumer --bootstrap-server localhost:9093 --topic test-topic

# From inside a Docker container (should use 9092)
docker exec -it kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic test-topic
```

### Test Endpoints

Once service is running in dev mode:

```bash
# Health check
curl http://localhost:8082/q/health

# Kafka ping
curl http://localhost:8082/api/test/kafka/ping

# Send test message
curl "http://localhost:8082/api/test/kafka/send?message=test"
```

## Common Errors

### Error: `UnknownHostException: kafka`

**Cause**: Trying to use Docker internal hostname from host machine
**Solution**: Use `localhost:9093` instead of `kafka:9092`

### Error: Connection refused on port 9092

**Cause**: Trying to connect to internal port from host machine
**Solution**: Use port `9093` for host-to-Docker communication

### Error: Connection refused on port 9093

**Cause**: Kafka Docker container not running or not exposing port 9093
**Solution**:

```bash
# Check if Kafka is running
docker ps | grep kafka

# Check port mappings
docker port kafka

# Restart Docker Compose
docker-compose restart kafka
```

## Docker Compose Listener Configuration

```yaml
kafka:
    environment:
        KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT"
        KAFKA_ADVERTISED_LISTENERS: "PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9093"
        KAFKA_LISTENERS: "PLAINTEXT://kafka:9092,CONTROLLER://kafka:9094,PLAINTEXT_HOST://0.0.0.0:9093"
    ports:
        - "9092:9092" # Internal (not really needed for host access)
        - "9093:9093" # External (host access)
```

**Key Points**:

-   `PLAINTEXT://kafka:9092`: Internal listener for container network
-   `PLAINTEXT_HOST://0.0.0.0:9093`: External listener bound to all interfaces
-   Port mapping `9093:9093`: Exposes port 9093 to host machine

## Best Practices

1. **Always use environment variables** for Kafka configuration
2. **Use localhost:9093** when running services in dev mode
3. **Use kafka:9092** when running services in Docker containers
4. **Document the port difference** in team documentation
5. **Test both scenarios** (dev mode and Docker) after configuration changes

## References

-   [Confluent Kafka Docker Documentation](https://docs.confluent.io/platform/current/installation/docker/config-reference.html)
-   [Kafka Listeners Explained](https://www.confluent.io/blog/kafka-listeners-explained/)
-   [SmallRye Reactive Messaging - Kafka](https://smallrye.io/smallrye-reactive-messaging/4.0.0/kafka/kafka/)
