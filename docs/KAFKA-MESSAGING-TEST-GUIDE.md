# Kafka Messaging Test Guide

## Overview

All 7 microservices now have Kafka messaging capabilities with test endpoints.

## Architecture

### Services and Ports

-   **core-platform**: 8081
-   **administration**: 8082
-   **customer-relationship**: 8083
-   **operations-service**: 8084
-   **commerce**: 8085
-   **financial-management**: 8086
-   **supply-chain-manufacturing**: 8087

### Kafka Topics

Each service has:

1. **Service-specific topic**: `{service-name}-events` (e.g., `core-platform-events`)
2. **Shared topic**: `shared-events` (consumed by all services)

## Testing Kafka Messaging

### 1. Start Infrastructure

```powershell
docker-compose up -d postgres redis kafka zookeeper
```

### 2. Build All Services

```powershell
./gradlew clean build -x test
```

### 3. Start Services

```powershell
# Start each service in separate terminals
./gradlew :services:core-platform:quarkusDev
./gradlew :services:administration:quarkusDev
./gradlew :services:customer-relationship:quarkusDev
./gradlew :services:operations-service:quarkusDev
./gradlew :services:commerce:quarkusDev
./gradlew :services:financial-management:quarkusDev
./gradlew :services:supply-chain-manufacturing:quarkusDev
```

### 4. Test Endpoints

#### Health Checks

```bash
# Core Platform
curl http://localhost:8081/q/health

# Administration
curl http://localhost:8082/q/health

# Customer Relationship
curl http://localhost:8083/q/health

# Operations Service
curl http://localhost:8084/q/health

# Commerce
curl http://localhost:8085/q/health

# Financial Management
curl http://localhost:8086/q/health

# Supply Chain Manufacturing
curl http://localhost:8087/q/health
```

#### Kafka Test Endpoints

**Send Test Message from Core Platform:**

```bash
curl "http://localhost:8081/api/test/kafka/send?message=Hello from Core Platform"
```

**Send Test Message from Administration:**

```bash
curl "http://localhost:8082/api/test/kafka/send?message=Hello from Administration"
```

**Check Service Status:**

```bash
curl http://localhost:8081/api/test/kafka/ping
curl http://localhost:8082/api/test/kafka/ping
```

### 5. Monitor Logs

Watch the service logs to see:

-   Events being published
-   Events being consumed
-   Cross-service communication via `shared-events` topic

Expected log output:

```
Published event: TEST_EVENT with ID: <uuid>
Administration received event: {"eventId":"...","eventType":"TEST_EVENT"...}
Administration received shared event: {"eventId":"..."}
```

## Event Flow

1. **Service publishes event** → Kafka topic (`{service}-events`)
2. **Same service consumes** → Verifies round-trip messaging
3. **All services listen** → `shared-events` topic for cross-service events

## Kafka Channel Configuration

Each service has 3 channels:

### Outgoing (Publisher)

```properties
mp.messaging.outgoing.{service}-events-out.connector=smallrye-kafka
mp.messaging.outgoing.{service}-events-out.topic={service}-events
```

### Incoming (Consumer - Own Events)

```properties
mp.messaging.incoming.{service}-events-in.connector=smallrye-kafka
mp.messaging.incoming.{service}-events-in.topic={service}-events
mp.messaging.incoming.{service}-events-in.group.id={service}-group
```

### Incoming (Consumer - Shared Events)

```properties
mp.messaging.incoming.shared-events.connector=smallrye-kafka
mp.messaging.incoming.shared-events.topic=shared-events
mp.messaging.incoming.shared-events.group.id={service}-shared-group
```

## Event Format

```json
{
    "eventId": "uuid",
    "eventType": "TEST_EVENT",
    "serviceName": "core-platform",
    "timestamp": "2025-11-02T19:30:00Z",
    "payload": "message content"
}
```

## Troubleshooting

### Kafka Not Starting

```bash
docker-compose logs kafka
```

### Service Can't Connect to Kafka

Check `application.properties`:

```properties
kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}
```

### No Events Being Consumed

1. Check Kafka topic exists:

```bash
docker exec -it chiro-erp-kafka-1 kafka-topics --list --bootstrap-server localhost:9092
```

2. Check consumer group:

```bash
docker exec -it chiro-erp-kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --list
```

## Next Steps

1. ✅ Health checks implemented
2. ✅ Kafka messaging configured
3. ✅ Test endpoints created
4. 🚀 Ready for deployment and testing

To test the full system:

```powershell
# Terminal 1: Start infrastructure
docker-compose up -d

# Terminal 2: Build services
./gradlew clean build -x test

# Terminal 3-9: Start each service
./gradlew :services:core-platform:quarkusDev
# ... (repeat for all services)

# Terminal 10: Test health and Kafka
curl http://localhost:8081/q/health
curl "http://localhost:8081/api/test/kafka/send?message=Test"
```

Watch the logs in each service terminal to see Kafka events flowing between services!
